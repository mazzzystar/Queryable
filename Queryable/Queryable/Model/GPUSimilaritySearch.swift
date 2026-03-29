//
//  GPUSimilaritySearch.swift
//  Queryable
//
//  GPU-accelerated similarity search using MPSGraph matrix multiplication.
//  Replaces per-embedding CPU cosine similarity with a single [N,512]×[512,1] GPU matmul.
//
//  Performance strategy:
//  - Pre-allocate MTLBuffer for the embedding matrix (avoids ~27MB copy per search)
//  - Cache compiled MPSGraphExecutable (avoids graph recompilation per search)
//  - Only allocate a tiny buffer for the query vector on each search
//

import Foundation
import CoreML
import Metal
import MetalPerformanceShaders
import MetalPerformanceShadersGraph
import Accelerate

class GPUSimilaritySearch {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue

    /// Photo IDs in the same order as rows in the embedding matrix
    private(set) var ids: [String] = []

    /// Contiguous Float16 embedding data (CPU-side, used for add/remove)
    private var embeddingData: [Float16] = []

    /// Pre-allocated GPU buffer for the embedding matrix
    private var matrixBuffer: MTLBuffer?

    /// Cached compiled graph + placeholders (invalidated when index changes)
    private var cachedGraph: CachedGraph?

    private let embeddingDim: Int = 512

    var count: Int { ids.count }

    private struct CachedGraph {
        let graph: MPSGraph
        let matrixPlaceholder: MPSGraphTensor
        let queryPlaceholder: MPSGraphTensor
        let resultTensor: MPSGraphTensor
        let n: Int
    }

    init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        self.device = device
        self.commandQueue = commandQueue
    }

    /// Build the GPU index from the in-memory embedding dictionary.
    /// Embeddings are L2-normalized and converted to Float16.
    func buildIndex(from embeddings: [String: MLMultiArray]) {
        let startTime = Date()
        let n = embeddings.count

        ids.removeAll()
        ids.reserveCapacity(n)
        embeddingData = [Float16](repeating: 0, count: n * embeddingDim)

        // Reusable buffer for normalized Float32 values (one embedding at a time)
        var normalizedBuf = [Float32](repeating: 0, count: embeddingDim)

        var i = 0
        for (id, mlArray) in embeddings {
            ids.append(id)
            let offset = i * embeddingDim

            // Zero-copy pointer into MLMultiArray's backing store
            let srcPtr = mlArray.dataPointer.assumingMemoryBound(to: Float32.self)

            // Vectorized L2 norm
            var sumSq: Float32 = 0
            vDSP_svesq(srcPtr, 1, &sumSq, vDSP_Length(embeddingDim))
            let norm = sqrt(sumSq)

            if norm > 1e-8 {
                var invNorm = 1.0 / norm
                vDSP_vsmul(srcPtr, 1, &invNorm, &normalizedBuf, 1, vDSP_Length(embeddingDim))

                // Bulk Float32 → Float16 conversion via Accelerate
                normalizedBuf.withUnsafeBufferPointer { srcBuf in
                    embeddingData.withUnsafeMutableBufferPointer { dstBuf in
                        var srcBuffer = vImage_Buffer(
                            data: UnsafeMutableRawPointer(mutating: srcBuf.baseAddress!),
                            height: 1,
                            width: vImagePixelCount(embeddingDim),
                            rowBytes: embeddingDim * MemoryLayout<Float32>.size
                        )
                        var dstBuffer = vImage_Buffer(
                            data: UnsafeMutableRawPointer(dstBuf.baseAddress! + offset),
                            height: 1,
                            width: vImagePixelCount(embeddingDim),
                            rowBytes: embeddingDim * MemoryLayout<Float16>.size
                        )
                        vImageConvert_PlanarFtoPlanar16F(&srcBuffer, &dstBuffer, 0)
                    }
                }
            }

            i += 1
        }

        // Pre-allocate GPU buffer and build cached graph
        uploadToGPU()

        print("[GPUSearch] Built index: \(n) embeddings in \(String(format: "%.3f", Date().timeIntervalSince(startTime)))s")
    }

    /// Add new embeddings to the existing index.
    func addEmbeddings(_ newEmbeddings: [String: MLMultiArray]) {
        var normalizedBuf = [Float32](repeating: 0, count: embeddingDim)

        for (id, mlArray) in newEmbeddings {
            let srcPtr = mlArray.dataPointer.assumingMemoryBound(to: Float32.self)

            var sumSq: Float32 = 0
            vDSP_svesq(srcPtr, 1, &sumSq, vDSP_Length(embeddingDim))
            let norm = sqrt(sumSq)

            var normalized = [Float16](repeating: 0, count: embeddingDim)
            if norm > 1e-8 {
                var invNorm = 1.0 / norm
                vDSP_vsmul(srcPtr, 1, &invNorm, &normalizedBuf, 1, vDSP_Length(embeddingDim))

                normalizedBuf.withUnsafeBufferPointer { srcBuf in
                    normalized.withUnsafeMutableBufferPointer { dstBuf in
                        var srcBuffer = vImage_Buffer(
                            data: UnsafeMutableRawPointer(mutating: srcBuf.baseAddress!),
                            height: 1,
                            width: vImagePixelCount(embeddingDim),
                            rowBytes: embeddingDim * MemoryLayout<Float32>.size
                        )
                        var dstBuffer = vImage_Buffer(
                            data: UnsafeMutableRawPointer(dstBuf.baseAddress!),
                            height: 1,
                            width: vImagePixelCount(embeddingDim),
                            rowBytes: embeddingDim * MemoryLayout<Float16>.size
                        )
                        vImageConvert_PlanarFtoPlanar16F(&srcBuffer, &dstBuffer, 0)
                    }
                }
            }

            ids.append(id)
            embeddingData.append(contentsOf: normalized)
        }

        uploadToGPU()
    }

    /// Remove embeddings by their IDs. Rebuilds the contiguous array.
    func removeEmbeddings(_ idsToRemove: Set<String>) {
        guard !idsToRemove.isEmpty else { return }

        var newIds = [String]()
        newIds.reserveCapacity(ids.count - idsToRemove.count)
        var newData = [Float16]()
        newData.reserveCapacity((ids.count - idsToRemove.count) * embeddingDim)

        for (i, id) in ids.enumerated() {
            if !idsToRemove.contains(id) {
                newIds.append(id)
                let offset = i * embeddingDim
                newData.append(contentsOf: embeddingData[offset..<(offset + embeddingDim)])
            }
        }

        self.ids = newIds
        self.embeddingData = newData

        uploadToGPU()
    }

    // MARK: - GPU Buffer Management

    /// Upload embedding data to a persistent MTLBuffer and build the cached graph.
    private func uploadToGPU() {
        let n = ids.count
        guard n > 0 else {
            matrixBuffer = nil
            cachedGraph = nil
            return
        }

        let byteCount = n * embeddingDim * MemoryLayout<Float16>.size

        matrixBuffer = embeddingData.withUnsafeBufferPointer { ptr in
            device.makeBuffer(bytes: ptr.baseAddress!, length: byteCount, options: .storageModeShared)
        }

        // Build and cache the MPSGraph for this matrix size
        let graph = MPSGraph()
        let matrixShape: [NSNumber] = [NSNumber(value: n), NSNumber(value: embeddingDim)]
        let queryShape: [NSNumber] = [NSNumber(value: embeddingDim), NSNumber(value: 1)]

        let matrixPlaceholder = graph.placeholder(shape: matrixShape, dataType: .float16, name: "embeddings")
        let queryPlaceholder = graph.placeholder(shape: queryShape, dataType: .float16, name: "query")
        let resultTensor = graph.matrixMultiplication(
            primary: matrixPlaceholder,
            secondary: queryPlaceholder,
            name: "similarity"
        )

        cachedGraph = CachedGraph(
            graph: graph,
            matrixPlaceholder: matrixPlaceholder,
            queryPlaceholder: queryPlaceholder,
            resultTensor: resultTensor,
            n: n
        )
    }

    // MARK: - Search

    /// Compute similarity scores for a query embedding against all stored embeddings.
    /// Returns [photoID: similarity_score].
    func search(queryEmbedding: MLShapedArray<Float32>) -> [String: Float] {
        let n = ids.count
        guard n > 0,
              let cached = cachedGraph,
              let matBuf = matrixBuffer,
              cached.n == n else {
            return [:]
        }

        // L2-normalize query and convert to Float16
        let queryScalars = queryEmbedding.scalars
        let queryNorm = sqrt(vDSP.sumOfSquares(queryScalars))
        var queryFloat16 = [Float16](repeating: 0, count: embeddingDim)
        if queryNorm > 1e-8 {
            for j in 0..<min(queryScalars.count, embeddingDim) {
                queryFloat16[j] = Float16(queryScalars[j] / queryNorm)
            }
        }

        // Create tensor data from pre-allocated matrix buffer (no copy)
        let matrixShape: [NSNumber] = [NSNumber(value: n), NSNumber(value: embeddingDim)]
        let matrixTensorData = MPSGraphTensorData(
            matBuf,
            shape: matrixShape,
            dataType: .float16
        )

        // Only the query vector needs a fresh buffer (~1KB)
        let queryShape: [NSNumber] = [NSNumber(value: embeddingDim), NSNumber(value: 1)]
        let queryTensorData = queryFloat16.withUnsafeBufferPointer { ptr in
            MPSGraphTensorData(
                device: MPSGraphDevice(mtlDevice: device),
                data: Data(buffer: ptr),
                shape: queryShape,
                dataType: .float16
            )
        }

        // Execute on GPU using cached graph
        let results = cached.graph.run(
            with: commandQueue,
            feeds: [cached.matrixPlaceholder: matrixTensorData,
                    cached.queryPlaceholder: queryTensorData],
            targetTensors: [cached.resultTensor],
            targetOperations: nil
        )

        guard let resultTensorData = results[cached.resultTensor] else { return [:] }

        // Read results back as Float16
        var resultFloat16 = [Float16](repeating: 0, count: n)
        resultTensorData.mpsndarray().readBytes(&resultFloat16, strideBytes: nil)

        // Build result dictionary
        var simDict = [String: Float](minimumCapacity: n)
        for i in 0..<n {
            simDict[ids[i]] = Float(resultFloat16[i])
        }

        return simDict
    }
}
