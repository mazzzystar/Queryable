//
//  EmbeddingStore.swift
//  Queryable
//
//  Efficient binary embedding storage with incremental saves.
//  Replaces NSKeyedArchiver full-file rewrites with append-only journal + tombstones.
//
//  File format (v1):
//    Header:  "QEMB" (4 bytes) + version UInt32 + count UInt32
//    Record:  idLength UInt16 + id UTF-8 bytes + embedding Float32[512]
//
//  Journal file: same record format, no header (append-only for new embeddings)
//  Tombstone file: newline-separated IDs of deleted embeddings
//

import Foundation
import CoreML

/// @unchecked Sendable: all stored properties are immutable after init (let).
/// loadAll() is a pure reader that returns a fresh dictionary with no shared mutable state,
/// so it is safe to call from a detached Task. Write methods (appendNew, markDeleted, etc.)
/// are only called from the @MainActor-isolated PhotoSearcher, so no concurrent writes occur.
class EmbeddingStore: @unchecked Sendable {
    private let embeddingDim = 512
    private let headerMagic: [UInt8] = [0x51, 0x45, 0x4D, 0x42] // "QEMB"
    private let formatVersion: UInt32 = 1
    private let recordEmbeddingSize: Int // 512 * 4 = 2048

    private let mainFileName: String
    private let journalFileName: String
    private let tombstoneFileName: String
    private let legacyFileName: String
    private let baseDir: URL

    init(baseName: String = "imageEmbedding") {
        self.recordEmbeddingSize = embeddingDim * MemoryLayout<Float32>.size
        self.mainFileName = "\(baseName).qemb"
        self.journalFileName = "\(baseName)_journal.qemb"
        self.tombstoneFileName = "\(baseName)_tombstones.txt"
        self.legacyFileName = baseName
        self.baseDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: - Load

    /// Load all embeddings. Tries new binary format first, falls back to legacy NSKeyedArchiver.
    /// Returns nil if no data exists.
    func loadAll() -> [String: MLMultiArray]? {
        let mainPath = baseDir.appendingPathComponent(mainFileName)
        let journalPath = baseDir.appendingPathComponent(journalFileName)
        let legacyPath = baseDir.appendingPathComponent(legacyFileName)

        if FileManager.default.fileExists(atPath: mainPath.path) ||
           FileManager.default.fileExists(atPath: journalPath.path) {
            return loadFromBinaryFormat()
        } else if FileManager.default.fileExists(atPath: legacyPath.path) {
            // Migrate from legacy format
            print("[EmbeddingStore] Migrating from legacy NSKeyedArchiver format...")
            if let embeddings = loadFromLegacy() {
                // Save in new format
                if saveAll(embeddings) {
                    // Remove legacy file after successful migration
                    try? FileManager.default.removeItem(at: legacyPath)
                    print("[EmbeddingStore] Migration complete. Legacy file removed.")
                }
                return embeddings
            }
        }

        return nil
    }

    /// Load from the new binary format (main file + journal - tombstones).
    private func loadFromBinaryFormat() -> [String: MLMultiArray]? {
        let startTime = Date()
        var embeddings = [String: MLMultiArray]()

        // Load main file
        let mainPath = baseDir.appendingPathComponent(mainFileName)
        if let mainData = try? Data(contentsOf: mainPath) {
            readRecordsFromBinary(mainData, hasHeader: true, into: &embeddings)
        }

        // Load journal (incremental additions)
        let journalPath = baseDir.appendingPathComponent(journalFileName)
        if let journalData = try? Data(contentsOf: journalPath) {
            readRecordsFromBinary(journalData, hasHeader: false, into: &embeddings)
        }

        // Apply tombstones (deletions)
        let tombstones = loadTombstones()
        for id in tombstones {
            embeddings.removeValue(forKey: id)
        }

        print("[EmbeddingStore] Loaded \(embeddings.count) embeddings in \(String(format: "%.3f", Date().timeIntervalSince(startTime)))s")
        return embeddings.isEmpty ? nil : embeddings
    }

    /// Load from legacy NSKeyedArchiver format.
    private func loadFromLegacy() -> [String: MLMultiArray]? {
        let filePath = baseDir.appendingPathComponent(legacyFileName)
        do {
            let startTime = Date()
            let data = try Data(contentsOf: filePath)
            let decoded = try NSKeyedUnarchiver.unarchivedArrayOfObjects(
                ofClasses: [Embedding.self, MLMultiArray.self, NSString.self],
                from: data
            ) as? [Embedding]

            var embeddings = [String: MLMultiArray]()
            for emb in decoded ?? [] {
                if let id = emb.id, let embedding = emb.embedding {
                    embeddings[id] = embedding
                }
            }

            print("[EmbeddingStore] Loaded \(embeddings.count) legacy embeddings in \(String(format: "%.3f", Date().timeIntervalSince(startTime)))s")
            return embeddings.isEmpty ? nil : embeddings
        } catch {
            print("[EmbeddingStore] Failed to load legacy format: \(error)")
            return nil
        }
    }

    // MARK: - Save

    /// Full save: write all embeddings to the main file, clear journal and tombstones.
    @discardableResult
    func saveAll(_ embeddings: [String: MLMultiArray]) -> Bool {
        let startTime = Date()
        let mainPath = baseDir.appendingPathComponent(mainFileName)

        var data = Data()
        // Header
        data.append(contentsOf: headerMagic)
        var version = formatVersion
        data.append(Data(bytes: &version, count: 4))
        var count = UInt32(embeddings.count)
        data.append(Data(bytes: &count, count: 4))

        // Records
        for (id, mlArray) in embeddings {
            appendRecord(id: id, mlArray: mlArray, to: &data)
        }

        do {
            try data.write(to: mainPath, options: .atomic)
            // Clear journal and tombstones after full save
            clearJournal()
            clearTombstones()
            print("[EmbeddingStore] Saved \(embeddings.count) embeddings in \(String(format: "%.3f", Date().timeIntervalSince(startTime)))s")
            return true
        } catch {
            print("[EmbeddingStore] Failed to save: \(error)")
            return false
        }
    }

    /// Incremental save: append new embeddings to the journal file.
    /// Also removes these IDs from tombstones so re-indexed photos survive restart.
    @discardableResult
    func appendNew(_ newEmbeddings: [String: MLMultiArray]) -> Bool {
        guard !newEmbeddings.isEmpty else { return true }

        // Scrub re-indexed IDs from tombstones to prevent stale deletions on restart
        removeTombstones(for: Set(newEmbeddings.keys))

        let journalPath = baseDir.appendingPathComponent(journalFileName)

        var data = Data()
        for (id, mlArray) in newEmbeddings {
            appendRecord(id: id, mlArray: mlArray, to: &data)
        }

        do {
            if FileManager.default.fileExists(atPath: journalPath.path) {
                let handle = try FileHandle(forWritingTo: journalPath)
                defer { handle.closeFile() }
                handle.seekToEndOfFile()
                handle.write(data)
            } else {
                try data.write(to: journalPath, options: .atomic)
            }
            print("[EmbeddingStore] Appended \(newEmbeddings.count) embeddings to journal")
            return true
        } catch {
            print("[EmbeddingStore] Failed to append: \(error)")
            return false
        }
    }

    /// Mark embeddings as deleted by adding to tombstone file.
    @discardableResult
    func markDeleted(_ deletedIds: [String]) -> Bool {
        guard !deletedIds.isEmpty else { return true }

        let tombstonePath = baseDir.appendingPathComponent(tombstoneFileName)
        let content = deletedIds.joined(separator: "\n") + "\n"

        do {
            guard let contentData = content.data(using: .utf8) else { return false }
            if FileManager.default.fileExists(atPath: tombstonePath.path) {
                let handle = try FileHandle(forWritingTo: tombstonePath)
                defer { handle.closeFile() }
                handle.seekToEndOfFile()
                handle.write(contentData)
            } else {
                try content.write(to: tombstonePath, atomically: true, encoding: .utf8)
            }
            return true
        } catch {
            print("[EmbeddingStore] Failed to write tombstones: \(error)")
            return false
        }
    }

    /// Compact: rewrite the main file from in-memory dict, clearing journal and tombstones.
    @discardableResult
    func compact(_ embeddings: [String: MLMultiArray]) -> Bool {
        return saveAll(embeddings)
    }

    /// Check if journal + tombstones warrant compaction.
    func needsCompaction() -> Bool {
        let journalPath = baseDir.appendingPathComponent(journalFileName)
        let tombstonePath = baseDir.appendingPathComponent(tombstoneFileName)

        let journalSize = (try? FileManager.default.attributesOfItem(atPath: journalPath.path)[.size] as? Int) ?? 0
        let hasTombstones = FileManager.default.fileExists(atPath: tombstonePath.path)

        return journalSize > 5_000_000 || hasTombstones
    }

    // MARK: - Binary Format Helpers

    private func appendRecord(id: String, mlArray: MLMultiArray, to data: inout Data) {
        let idBytes = Array(id.utf8)
        var idLen = UInt16(idBytes.count)
        data.append(Data(bytes: &idLen, count: 2))
        data.append(contentsOf: idBytes)

        // Write embedding as raw Float32 bytes
        let shaped = MLShapedArray<Float32>(converting: mlArray)
        let scalars = shaped.scalars
        scalars.withUnsafeBufferPointer { ptr in
            data.append(UnsafeBufferPointer(start: ptr.baseAddress, count: min(ptr.count, embeddingDim)))
        }

        // Pad if embedding is shorter than expected
        if scalars.count < embeddingDim {
            let padding = [Float32](repeating: 0, count: embeddingDim - scalars.count)
            padding.withUnsafeBufferPointer { ptr in
                data.append(UnsafeBufferPointer(start: ptr.baseAddress, count: ptr.count))
            }
        }
    }

    private func readRecordsFromBinary(_ data: Data, hasHeader: Bool, into embeddings: inout [String: MLMultiArray]) {
        var offset = 0

        if hasHeader {
            // Validate and skip header: 4 (magic) + 4 (version) + 4 (count) = 12 bytes
            guard data.count >= 12 else { return }
            let magic = [UInt8](data[0..<4])
            guard magic == headerMagic else {
                print("[EmbeddingStore] Invalid file magic: \(magic)")
                return
            }
            offset = 12
        }

        while offset + 2 < data.count {
            // Read ID length (unaligned-safe via copyBytes)
            var idLen: UInt16 = 0
            _ = withUnsafeMutableBytes(of: &idLen) { dest in
                data.copyBytes(to: dest, from: offset..<(offset + 2))
            }
            offset += 2

            // Read ID
            guard offset + Int(idLen) + recordEmbeddingSize <= data.count else { break }
            let idData = data[offset..<(offset + Int(idLen))]
            guard let id = String(data: idData, encoding: .utf8) else {
                offset += Int(idLen) + recordEmbeddingSize
                continue
            }
            offset += Int(idLen)

            // Read embedding floats (unaligned-safe via copyBytes)
            var floats = [Float32](repeating: 0, count: embeddingDim)
            floats.withUnsafeMutableBufferPointer { dest in
                _ = data.copyBytes(to: UnsafeMutableRawBufferPointer(dest), from: offset..<(offset + recordEmbeddingSize))
            }
            offset += recordEmbeddingSize

            // Bulk copy via MLShapedArray → MLMultiArray (avoids 512 NSNumber allocs per embedding)
            let shaped = MLShapedArray<Float32>(scalars: floats, shape: [1, embeddingDim])
            embeddings[id] = MLMultiArray(shaped)
        }
    }

    private func loadTombstones() -> Set<String> {
        let tombstonePath = baseDir.appendingPathComponent(tombstoneFileName)
        guard let content = try? String(contentsOf: tombstonePath, encoding: .utf8) else {
            return []
        }
        return Set(content.components(separatedBy: .newlines).filter { !$0.isEmpty })
    }

    private func clearJournal() {
        let journalPath = baseDir.appendingPathComponent(journalFileName)
        try? FileManager.default.removeItem(at: journalPath)
    }

    private func clearTombstones() {
        let tombstonePath = baseDir.appendingPathComponent(tombstoneFileName)
        try? FileManager.default.removeItem(at: tombstonePath)
    }

    /// Remove specific IDs from the tombstone file (e.g. when re-indexing a previously deleted photo).
    private func removeTombstones(for idsToRemove: Set<String>) {
        guard !idsToRemove.isEmpty else { return }
        let tombstonePath = baseDir.appendingPathComponent(tombstoneFileName)
        guard let content = try? String(contentsOf: tombstonePath, encoding: .utf8) else { return }

        let remaining = content.components(separatedBy: .newlines)
            .filter { !$0.isEmpty && !idsToRemove.contains($0) }

        if remaining.isEmpty {
            try? FileManager.default.removeItem(at: tombstonePath)
        } else {
            let updated = remaining.joined(separator: "\n") + "\n"
            try? updated.write(to: tombstonePath, atomically: true, encoding: .utf8)
        }
    }
}
