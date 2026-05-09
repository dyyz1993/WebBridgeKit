//
//  WebCompressedCacheStore.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-23.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import RealmSwift
import ZIPFoundation
import Compression

// Framework imports

/// 压缩缓存配置
public struct WebCacheConfig {
    /// 是否启用压缩（默认 true）
    public var enableCompression: Bool = true

    /// 压缩阈值（字节），小于此值不压缩（默认 10KB）
    public var compressionThreshold: Int = 10_240

    /// 压缩级别（0-9，默认 6，平衡速度和压缩比）
    public var compressionLevel: Int = 6

    /// 最大缓存大小（字节），超出后执行 LRU 清理（默认 500MB）
    public var maxCacheSize: Int64 = 500 * 1024 * 1024

    /// 单个文件最大大小（字节），超过此值不缓存（默认 50MB）
    public var maxFileSize: Int = 50 * 1024 * 1024

    public init() {}
}

/// 压缩缓存存储
/// 负责资源的压缩、存储、检索和删除
public class WebCompressedCacheStore {

    // MARK: - Singleton

    public static let shared = WebCompressedCacheStore()

    // MARK: - Properties

    /// 缓存配置
    public var config: WebCacheConfig {
        didSet {
            WebBridgeLogger.shared.info("Cache config updated: compression=\(config.enableCompression), threshold=\(config.compressionThreshold)")
        }
    }

    /// 缓存根目录
    private let cacheDirectory: URL

    /// Realm 配置
    public let realmConfiguration: Realm.Configuration

    /// 文件管理器
    private let fileManager: FileManager

    /// 序列队列（确保线程安全）
    private let queue: DispatchQueue

    // MARK: - Initialization

    private init() {
        self.config = WebCacheConfig()
        self.fileManager = FileManager.default
        self.queue = DispatchQueue(label: "com.webbridgekit.cache", qos: .utility)

        // 设置缓存目录
        let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectory = cachesURL.appendingPathComponent("WebCompressedCache")

        // 创建缓存目录
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // 配置 Realm
        self.realmConfiguration = Realm.Configuration(
            schemaVersion: 1,
            migrationBlock: { _, _ in
            },
            objectTypes: [CacheEntryRealm.self]
        )

        WebBridgeLogger.shared.info("WebCompressedCacheStore initialized at: \(cacheDirectory.path)")
    }

    // MARK: - Public Methods - Storage

    /// 存储数据（可选择压缩）
    /// - Parameters:
    ///   - data: 原始数据
    ///   - key: 缓存键（通常是 URL 的 hash）
    ///   - url: 原始 URL
    ///   - mimeType: MIME 类型
    ///   - etag: ETag（可选）
    ///   - lastModified: 最后修改时间（可选）
    ///   - responseHeaders: 响应头（可选）
    /// - Throws: 存储错误
    public func save(
        data: Data,
        forKey key: String,
        url: String,
        mimeType: String,
        etag: String? = nil,
        lastModified: Date? = nil,
        responseHeaders: [String: String]? = nil
    ) throws {
        try queue.sync {
            // 检查文件大小限制
            guard data.count <= config.maxFileSize else {
                throw CacheError.fileTooLarge
            }

            // 生成文件路径
            let fileName = "\(key).data"
            let filePath = cacheDirectory.appendingPathComponent(fileName)

            // 决定是否压缩
            let shouldCompress = config.enableCompression && data.count >= config.compressionThreshold

            var finalData: Data
            var isCompressed = false

            if shouldCompress {
                // 压缩数据
                do {
                    finalData = try compressData(data)
                    isCompressed = true

                    let ratio = Double(finalData.count) / Double(data.count)
                    WebBridgeLogger.shared.debug("Compressed \(key): \(data.count) -> \(finalData.count) bytes (\(String(format: "%.1f%%", ratio * 100)))")
                } catch {
                    // 压缩失败，使用原始数据
                    WebBridgeLogger.shared.warning("Compression failed for \(key), using original data: \(error.localizedDescription)")
                    finalData = data
                    isCompressed = false
                }
            } else {
                finalData = data
                isCompressed = false
            }

            // 写入文件
            try finalData.write(to: filePath)

            // 更新元数据
            let realm = try Realm(configuration: realmConfiguration)
            try realm.write {
                let compressedData = isCompressed ? finalData : nil
                let entry = CacheEntryRealm.createOrUpdate(
                    options: CacheEntryRealm.CreationOptions(
                        key: key,
                        url: url,
                        data: data,
                        compressedData: compressedData,
                        mimeType: mimeType,
                        filePath: filePath.path,
                        etag: etag,
                        lastModified: lastModified,
                        responseHeaders: responseHeaders
                    )
                )
                realm.add(entry, update: .all)
            }

            // 检查缓存大小，可能需要清理
            try checkAndCleanupIfNeeded()
        }
    }

    /// 读取数据（自动解压）
    /// - Parameter key: 缓存键
    /// - Returns: (数据, MIME 类型) 元组，如果不存在返回 nil
    public func load(key: String) -> (data: Data, mimeType: String)? {
        return queue.sync {
            // 查询元数据
            guard let entry = getEntry(key: key) else {
                return nil
            }

            // 读取文件
            guard let fileData = try? Data(contentsOf: URL(fileURLWithPath: entry.filePath)) else {
                WebBridgeLogger.shared.error("Failed to read cache file: \(entry.filePath)")
                return nil
            }

            // 解压（如果需要）
            let finalData: Data
            if entry.isCompressed {
                do {
                    finalData = try decompressData(fileData)
                } catch {
                    WebBridgeLogger.shared.error("Failed to decompress \(key): \(error.localizedDescription)")
                    return nil
                }
            } else {
                finalData = fileData
            }

            // 更新访问统计
            updateAccess(for: key)

            return (finalData, entry.mimeType)
        }
    }

    // MARK: - Public Methods - Deletion

    /// 删除指定键的缓存
    /// - Parameter key: 缓存键
    /// - Returns: 是否删除成功
    @discardableResult
    public func delete(key: String) -> Bool {
        return queue.sync {
            guard let entry = getEntry(key: key) else {
                return false
            }

            // 删除文件
            try? fileManager.removeItem(atPath: entry.filePath)

            // 删除元数据
            let realm = try? Realm(configuration: realmConfiguration)
            try? realm?.write {
                realm?.delete(entry)
            }

            WebBridgeLogger.shared.debug("Deleted cache entry: \(key)")
            return true
        }
    }

    /// 使用 Glob 模式删除缓存
    /// - Parameter pattern: Glob 模式（如 `https://example.com/*.js`）
    /// - Returns: 删除的条目数量
    @discardableResult
    public func deleteByGlob(pattern: String) throws -> Int {
        return try queue.sync {
            let realm = try Realm(configuration: realmConfiguration)

            // 查询所有条目
            let allEntries = realm.objects(CacheEntryRealm.self)

            // 过滤匹配的条目
            let matchedEntries = allEntries.filter { entry in
                GlobPattern.matches(pattern, against: entry.url)
            }

            // 删除匹配的条目
            let deletedCount = matchedEntries.count

            if deletedCount > 0 {
                try realm.write {
                    // 删除文件
                    for entry in matchedEntries {
                        try? fileManager.removeItem(atPath: entry.filePath)
                    }
                    // 删除数据库记录
                    realm.delete(matchedEntries)
                }

                WebBridgeLogger.shared.info("Deleted \(deletedCount) cache entries matching pattern: \(pattern)")
            }

            return deletedCount
        }
    }

    /// 清空所有缓存
    public func clearAll() {
        queue.sync {
            let realm = try? Realm(configuration: realmConfiguration)

            // 删除所有文件
            if let entries = realm?.objects(CacheEntryRealm.self) {
                for entry in entries {
                    try? fileManager.removeItem(atPath: entry.filePath)
                }
            }

            // 删除所有记录
            try? realm?.write {
                realm?.deleteAll()
            }

            WebBridgeLogger.shared.info("Cleared all cache")
        }
    }

    // MARK: - Public Methods - Query

    /// 检查指定键是否存在
    /// - Parameter key: 缓存键
    /// - Returns: 是否存在
    public func exists(key: String) -> Bool {
        return queue.sync {
            return getEntry(key: key) != nil
        }
    }

    /// 获取指定键的缓存条目信息
    /// - Parameter key: 缓存键
    /// - Returns: 缓存条目信息
    public func getEntryInfo(key: String) -> CacheEntryInfo? {
        return queue.sync {
            guard let entry = getEntry(key: key) else {
                return nil
            }
            return CacheEntryInfo(from: entry)
        }
    }

    /// 获取所有缓存条目
    /// - Returns: 缓存条目信息数组
    public func getAllEntries() -> [CacheEntryInfo] {
        return queue.sync {
            let realm = try? Realm(configuration: realmConfiguration)
            guard let entries = realm?.objects(CacheEntryRealm.self) else {
                return []
            }
            return entries.map { CacheEntryInfo(from: $0) }
        }
    }

    /// 按域名分组获取缓存条目
    /// - Returns: [域名: 缓存条目数组]
    public func getEntriesGroupedByDomain() -> [String: [CacheEntryInfo]] {
        let allEntries = getAllEntries()
        return Dictionary(grouping: allEntries) { $0.domain }
    }

    /// 获取内存使用信息
    /// - Returns: 缓存内存信息
    public func getMemoryInfo() -> CacheMemoryInfo {
        return queue.sync {
            let realm = try? Realm(configuration: realmConfiguration)
            guard let entries = realm?.objects(CacheEntryRealm.self) else {
                return CacheMemoryInfo(
                    totalEntries: 0,
                    totalOriginalSize: 0,
                    totalCompressedSize: 0,
                    compressionRatio: 1.0,
                    savedSpace: 0
                )
            }
            return CacheMemoryInfo.from(entries: Array(entries))
        }
    }

    /// 获取缓存目录路径
    /// - Returns: 缓存目录 URL
    public func getCacheDirectory() -> URL {
        return queue.sync {
            return cacheDirectory
        }
    }

    // MARK: - Private Methods

    /// 获取数据库中的条目（内部方法）
    private func getEntry(key: String) -> CacheEntryRealm? {
        let realm = try? Realm(configuration: realmConfiguration)
        return realm?.object(ofType: CacheEntryRealm.self, forPrimaryKey: key)
    }

    /// 更新访问统计
    private func updateAccess(for key: String) {
        let realm = try? Realm(configuration: realmConfiguration)
        try? realm?.write {
            if let entry = realm?.object(ofType: CacheEntryRealm.self, forPrimaryKey: key) {
                entry.updateAccess()
            }
        }
    }

    /// 压缩数据
    private func compressData(_ data: Data) throws -> Data {
        // 使用系统 Compression 框架进行 zlib 压缩
        return try data.withUnsafeBytes { rawBufferPointer in
            guard let baseAddress = rawBufferPointer.baseAddress else {
                throw CacheError.compressionFailed
            }
            let bufferPointer = baseAddress.assumingMemoryBound(to: UInt8.self)
            let count = data.count

            // 预分配足够空间（压缩后通常不超过原始大小的 1.1 倍 + 12 字节）
            let dstSize = count + count / 10 + 12
            var dstBuffer = Data(count: dstSize)

            return try dstBuffer.withUnsafeMutableBytes { dstBytes in
                guard let dstBaseAddress = dstBytes.baseAddress else {
                    throw CacheError.compressionFailed
                }
                let dstPointer = dstBaseAddress.assumingMemoryBound(to: UInt8.self)

                let compressedSize = compression_encode_buffer(
                    dstPointer, dstSize,
                    bufferPointer, count,
                    nil, COMPRESSION_ZLIB
                )

                if compressedSize == 0 {
                    throw CacheError.compressionFailed
                }

                var result = Data(bytes: dstPointer, count: Int(compressedSize))
                return result
            }
        }
    }

    /// 解压数据
    private func decompressData(_ data: Data) throws -> Data {
        // 使用系统 Compression 框架进行 zlib 解压
        let bufferSize = data.count * 4 // 预分配足够空间
        var dstBuffer = Data(count: bufferSize)

        return try dstBuffer.withUnsafeMutableBytes { dstBytes in
            guard let dstBaseAddress = dstBytes.baseAddress else {
                throw CacheError.decompressionFailed
            }
            let dstPointer = dstBaseAddress.assumingMemoryBound(to: UInt8.self)

            return try data.withUnsafeBytes { rawBufferPointer in
                guard let srcBaseAddress = rawBufferPointer.baseAddress else {
                    throw CacheError.decompressionFailed
                }
                let srcPointer = srcBaseAddress.assumingMemoryBound(to: UInt8.self)

                let size = compression_decode_buffer(
                    dstPointer, bufferSize,
                    srcPointer, data.count,
                    nil, COMPRESSION_ZLIB
                )

                if size == 0 {
                    throw CacheError.decompressionFailed
                }

                return Data(bytes: dstPointer, count: Int(size))
            }
        }
    }

    /// 检查并清理缓存（如果超出限制）
    private func checkAndCleanupIfNeeded() throws {
        let memoryInfo = getMemoryInfo()

        // 如果超出最大缓存大小，执行 LRU 清理
        if memoryInfo.totalCompressedSize > config.maxCacheSize {
            WebBridgeLogger.shared.info("Cache size exceeds limit, performing LRU cleanup")
            try performLRUCleanup(targetSize: Int64(Double(config.maxCacheSize) * 0.8)) // 清理到 80%
        }
    }

    /// 执行 LRU 清理
    private func performLRUCleanup(targetSize: Int64) throws {
        let realm = try Realm(configuration: realmConfiguration)

        // 按最后访问时间排序（最旧的在前）
        let entries = realm.objects(CacheEntryRealm.self)
            .sorted(byKeyPath: "lastAccessedAt", ascending: true)

        var currentSize = getMemoryInfo().totalCompressedSize
        var deletedCount = 0

        try realm.write {
            for entry in entries {
                if currentSize <= targetSize {
                    break
                }

                // 删除文件
                try? fileManager.removeItem(atPath: entry.filePath)

                // 记录删除的大小
                currentSize -= entry.compressedSize

                // 删除数据库记录
                realm.delete(entry)
                deletedCount += 1
            }
        }

        WebBridgeLogger.shared.info("LRU cleanup: deleted \(deletedCount) entries, freed \(getMemoryInfo().totalCompressedSize) bytes")
    }
}

// MARK: - Cache Error

public enum CacheError: Error, LocalizedError {
    case fileTooLarge
    case compressionFailed
    case decompressionFailed
    case notFound

    public var errorDescription: String? {
        switch self {
        case .fileTooLarge:
            return "File size exceeds maximum limit"
        case .compressionFailed:
            return "Failed to compress data"
        case .decompressionFailed:
            return "Failed to decompress data"
        case .notFound:
            return "Cache entry not found"
        }
    }
}
