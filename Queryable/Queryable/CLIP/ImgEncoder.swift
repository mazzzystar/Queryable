//
//  ImgEncoder.swift
//  Queryable
//
//  Created by Ke Fang on 2022/12/08.
//

import Foundation
import CoreML
import CoreImage
import UIKit

public struct ImgEncoder {
    var model: MLModel

    /// Shared CIContext for GPU-accelerated image processing
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    /// Shared pixel buffer pool to recycle IOSurface-backed buffers (prevents hitting the 16384 limit)
    private static var bufferPool: CVPixelBufferPool? = {
        let poolAttrs: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: 4
        ]
        let bufferAttrs: [String: Any] = [
            kCVPixelBufferWidthKey as String: 256,
            kCVPixelBufferHeightKey as String: 256,
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        var pool: CVPixelBufferPool?
        CVPixelBufferPoolCreate(kCFAllocatorDefault, poolAttrs as CFDictionary, bufferAttrs as CFDictionary, &pool)
        return pool
    }()

    /// Flush idle buffers from the pool so the OS can reclaim their IOSurfaces.
    static func flushBufferPool() {
        if let pool = bufferPool {
            CVPixelBufferPoolFlush(pool, CVPixelBufferPoolFlushFlags(rawValue: 0))
        }
    }

    /// Deep-copy an MLShapedArray's scalar data into a fresh, heap-backed MLMultiArray.
    /// CoreML prediction outputs are backed by IOSurface memory; MLShapedArray(converting:)
    /// and MLMultiArray(shapedArray) may share that IOSurface storage rather than copying.
    /// Storing those wrappers in savedEmbedding means each embedding retains an IOSurface,
    /// hitting the per-process 16384 IOSurface limit at ~15800 embeddings.
    /// This method breaks that chain by memcpy-ing the floats into plain heap memory.
    static func detachFromIOSurface(_ shapedArray: MLShapedArray<Float32>) -> MLMultiArray {
        let count = shapedArray.scalarCount
        let heapArray = try! MLMultiArray(shape: [1, NSNumber(value: count)], dataType: .float32)
        let dst = heapArray.dataPointer.assumingMemoryBound(to: Float32.self)
        shapedArray.withUnsafeShapedBufferPointer { ptr, _, _ in
            dst.update(from: ptr.baseAddress!, count: count)
        }
        return heapArray
    }

    init(resourcesAt baseURL: URL,
         configuration config: MLModelConfiguration = .init()
    ) throws {
        let imgEncoderURL = baseURL.appending(path: "ImageEncoder_mobileCLIP_s2.mlmodelc")
        let imgEncoderModel = try MLModel(contentsOf: imgEncoderURL, configuration: config)
        self.model = imgEncoderModel
    }

    public func computeImgEmbedding(img: UIImage) async throws -> MLShapedArray<Float32> {
        let imgEmbedding = try await self.encode(image: img)
        return imgEmbedding
    }

    /// Prediction queue
    let queue = DispatchQueue(label: "imgencoder.predict")

    public func encode(image: UIImage) async throws -> MLShapedArray<Float32> {
        do {
            guard let buffer = Self.resizeAndConvertToBuffer(image: image, size: CGSize(width: 256, height: 256)) else {
                throw ImageEncodingError.bufferConversionError
            }

            guard let inputFeatures = try? MLDictionaryFeatureProvider(dictionary: ["colorImage": buffer]) else {
                throw ImageEncodingError.featureProviderError
            }

            let result = try queue.sync { try model.prediction(from: inputFeatures) }
            guard let embeddingFeature = result.featureValue(for: "embOutput"),
                  let multiArray = embeddingFeature.multiArrayValue else {
                throw ImageEncodingError.predictionError
            }

            return MLShapedArray<Float32>(converting: multiArray)
        } catch {
            print("Error in encoding: \(error)")
            throw error
        }
    }

    /// Batch prediction: encode multiple images in one CoreML call.
    /// Uses MLArrayBatchProvider for efficient Neural Engine pipelining.
    /// All CoreML intermediates are scoped inside autoreleasepool to release
    /// Neural Engine IOSurface allocations promptly between batches.
    public func encodeBatch(images: [UIImage]) throws -> [MLShapedArray<Float32>] {
        let targetSize = CGSize(width: 256, height: 256)

        var embeddings = [MLShapedArray<Float32>]()
        embeddings.reserveCapacity(images.count)

        // autoreleasepool ensures CoreML's IOSurface-backed MLMultiArrays
        // and Espresso intermediates are released before the next batch
        try autoreleasepool {
            var featureProviders = [MLFeatureProvider]()
            featureProviders.reserveCapacity(images.count)

            for image in images {
                guard let buffer = Self.resizeAndConvertToBuffer(image: image, size: targetSize) else {
                    throw ImageEncodingError.bufferConversionError
                }
                let features = try MLDictionaryFeatureProvider(dictionary: ["colorImage": buffer])
                featureProviders.append(features)
            }

            let batchProvider = MLArrayBatchProvider(array: featureProviders)

            // Single batch prediction call — Neural Engine handles pipelining
            let batchResults = try queue.sync { try model.predictions(fromBatch: batchProvider) }

            for i in 0..<batchResults.count {
                let result = batchResults.features(at: i)
                guard let embeddingFeature = result.featureValue(for: "embOutput"),
                      let multiArray = embeddingFeature.multiArrayValue else {
                    throw ImageEncodingError.predictionError
                }
                embeddings.append(MLShapedArray<Float32>(converting: multiArray))
            }
        }

        return embeddings
    }

    /// GPU-accelerated image resize using CoreImage CILanczosScaleTransform,
    /// then render directly to a pooled CVPixelBuffer.
    private static func resizeAndConvertToBuffer(image: UIImage, size: CGSize) -> CVPixelBuffer? {
        guard let cgImage = image.cgImage else { return nil }

        let ciImage = CIImage(cgImage: cgImage)
        let scaleX = size.width / ciImage.extent.width
        let scaleY = size.height / ciImage.extent.height

        guard let filter = CIFilter(name: "CILanczosScaleTransform") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(scaleY, forKey: kCIInputScaleKey)
        filter.setValue(scaleX / scaleY, forKey: kCIInputAspectRatioKey)

        guard let outputImage = filter.outputImage else { return nil }

        // Get a recycled buffer from the pool (avoids IOSurface exhaustion during batch indexing)
        var pixelBuffer: CVPixelBuffer?
        if let pool = bufferPool {
            let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
            guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }
            ciContext.render(outputImage, to: buffer)
            return buffer
        }

        // Fallback: create standalone buffer if pool init failed
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width), Int(size.height),
            kCVPixelFormatType_32ARGB,
            attrs as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }
        ciContext.render(outputImage, to: buffer)
        return buffer
    }
}

// Define the custom errors
enum ImageEncodingError: Error {
    case resizeError
    case bufferConversionError
    case featureProviderError
    case predictionError
}
