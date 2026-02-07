//
//  WebResourceCacheManager.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-02-02.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation

/// Web资源缓存管理器
/// 实现按 URL 隔立的缓存空间管理
/// 为每个 URL 分配唯一的 cache-id（UUID），创建独立的缓存目录
public class WebResourceCacheManager {

    // MARK: - Singleton

    public static let shared = WebResourceCacheManager()

    // MARK: - Types

    /// 缓存空间统计信息
    public struct CacheSpaceStats {
        public let cacheID: String
        public let url: URL
        public let totalSize: Int64
        public let fileCount: Int
        public let createdAt: Date
        public let lastAccessedAt: Date
        public let manifest: WebResourceManifest?

        public var formattedSize: String {
            ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        }

        public var age: TimeInterval {
            Date().timeIntervalSince(createdAt)
        }
    }

    /// Web资源清单
    public struct WebResourceManifest: Codable {
        /// 原始 URL
        public let url: String

        /// HTML 内容
        public let htmlContent: String

        /// 资源列表
        public var resources: [String: ResourceInfo]

        /// 版本
        public var version: String

        /// 创建时间
        public let createdAt: Date

        /// 最后访问时间
        public var lastAccessedAt: Date

        public init(
            url: String,
            htmlContent: String,
            resources: [String: ResourceInfo] = [:],
            version: String = UUID().uuidString,
            createdAt: Date = Date(),
            lastAccessedAt: Date = Date()
        ) {
            self.url = url
            self.htmlContent = htmlContent
            self.resources = resources
            self.version = version
            self.createdAt = createdAt
            self.lastAccessedAt = lastAccessedAt
        }
    }

    /// 资源信息
    public struct ResourceInfo: Codable {
        /// 相对路径
        public let relativePath: String

        /// 原始 URL
        public let originalURL: String

        /// MIME 类型
        public let mimeType: String

        /// 文件大小
        public let fileSize: Int

        /// 缓存时间
        public let cachedAt: Date

        public init(relativePath: String, originalURL: String, mimeType: String, fileSize: Int, cachedAt: Date = Date()) {
            self.relativePath = relativePath
            self.originalURL = originalURL
            self.mimeType = mimeType
            self.fileSize = fileSize
            self.cachedAt = cachedAt
        }
    }

    /// LRU 清理策略
    public enum LRUEvictionPolicy {
        case leastRecentlyUsed
        case leastFrequentlyUsed
        case oldest
        case largest
    }

    /// 缓存管理错误
    public enum CacheError: Error, LocalizedError {
        case cacheSpaceNotFound(String)
        case invalidCacheID(String)
        case resourceNotFound(String)
        case diskError(Error)
        case manifestCorrupted(String)

        public var errorDescription: String? {
            switch self {
            case .cacheSpaceNotFound(let id):
                return "Cache space not found: \(id)"
            case .invalidCacheID(let id):
                return "Invalid cache ID: \(id)"
            case .resourceNotFound(let path):
                return "Resource not found: \(path)"
            case .diskError(let error):
                return "Disk error: \(error.localizedDescription)"
            case .manifestCorrupted(let id):
                return "Manifest corrupted for cache: \(id)"
            }
        }
    }

    // MARK: - Properties

    private let cacheBaseDirectory: URL
    private let cacheIndexFile: URL
    private let fileManager = FileManager.default

    private var urlToCacheIDMap: [String: String] = [:]
    private var cacheAccessTimes: [String: Date] = [:]

    private let mapLock = NSLock()
    private let accessLock = NSLock()
    private let queue = DispatchQueue(label: "com.webbridgekit.resource-cache-manager", qos: .userInitiated)

    // 缓存统计
    private var totalCacheSize: Int64 = 0
    private let sizeLock = NSLock()

    // MARK: - Initialization

    private init() {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        self.cacheBaseDirectory = paths[0].appendingPathComponent("WebResourceCache", isDirectory: true)
        self.cacheIndexFile = cacheBaseDirectory.appendingPathComponent("cache-index.plist")

        setupCacheDirectory()
        loadCacheIndex()
        updateTotalCacheSize()

        print("✅ [WebResourceCacheManager] Initialized")
        print("   - Base directory: \(cacheBaseDirectory.path)")
    }

    // MARK: - Public API - Cache Space Management

    /// 创建缓存空间
    /// - Parameter url: 要缓存的 URL
    /// - Returns: 分配的 cache ID (UUID)
    public func createCacheSpace(for url: URL) -> String {
        mapLock.lock()
        defer { mapLock.unlock() }

        // 检查是否已存在
        let urlString = url.absoluteString
        if let existingID = urlToCacheIDMap[urlString] {
            updateAccessTime(for: existingID)
            print("♻️ [WebResourceCacheManager] Reusing existing cache space: \(existingID)")
            return existingID
        }

        // 生成新的 cache ID
        let cacheID = UUID().uuidString

        // 创建缓存目录结构
        let cacheDirectory = cacheBaseDirectory.appendingPathComponent("cache-\(cacheID)", isDirectory: true)
        let resourcesDirectory = cacheDirectory.appendingPathComponent("resources", isDirectory: true)

        do {
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
            try fileManager.createDirectory(at: resourcesDirectory, withIntermediateDirectories: true, attributes: nil)

            // 保存映射关系
            urlToCacheIDMap[urlString] = cacheID
            cacheAccessTimes[cacheID] = Date()
            saveCacheIndex()

            print("✅ [WebResourceCacheManager] Created cache space")
            print("   - Cache ID: \(cacheID)")
            print("   - URL: \(urlString)")
            print("   - Directory: \(cacheDirectory.path)")

            return cacheID
        } catch {
            print("❌ [WebResourceCacheManager] Failed to create cache space: \(error.localizedDescription)")
            return cacheID
        }
    }

    /// 获取缓存 ID
    /// - Parameter url: URL
    /// - Returns: 缓存 ID，如果不存在则返回 nil
    public func getCacheID(for url: URL) -> String? {
        mapLock.lock()
        defer { mapLock.unlock() }

        let urlString = url.absoluteString
        let cacheID = urlToCacheIDMap[urlString]

        if let cacheID = cacheID {
            updateAccessTime(for: cacheID)
        }

        return cacheID
    }

    /// 获取 URL
    /// - Parameter cacheID: 缓存 ID
    /// - Returns: URL，如果不存在则返回 nil
    public func getURL(for cacheID: String) -> URL? {
        mapLock.lock()
        defer { mapLock.unlock() }

        if let urlString = urlToCacheIDMap.first(where: { $1 == cacheID })?.key {
            return URL(string: urlString)
        }
        return nil
    }

    /// 删除缓存空间
    /// - Parameter cacheID: 缓存 ID
    public func removeCacheSpace(cacheID: String) {
        queue.async { [weak self] in
            guard let self = self else { return }

            self.mapLock.lock()
            defer { self.mapLock.unlock() }

            // 查找并删除映射
            if let urlString = self.urlToCacheIDMap.first(where: { $1 == cacheID })?.key {
                self.urlToCacheIDMap.removeValue(forKey: urlString)
            }

            self.cacheAccessTimes.removeValue(forKey: cacheID)

            // 删除目录
            let cacheDirectory = self.cacheBaseDirectory.appendingPathComponent("cache-\(cacheID)")

            do {
                try self.fileManager.removeItem(at: cacheDirectory)
                self.saveCacheIndex()
                self.updateTotalCacheSize()

                print("🗑️ [WebResourceCacheManager] Removed cache space: \(cacheID)")
            } catch {
                print("❌ [WebResourceCacheManager] Failed to remove cache space: \(error.localizedDescription)")
            }
        }
    }

    /// 检查缓存空间是否存在
    /// - Parameter cacheID: 缓存 ID
    /// - Returns: 是否存在
    public func cacheSpaceExists(cacheID: String) -> Bool {
        mapLock.lock()
        defer { mapLock.unlock() }

        let cacheDirectory = cacheBaseDirectory.appendingPathComponent("cache-\(cacheID)")
        return fileManager.fileExists(atPath: cacheDirectory.path)
    }

    // MARK: - Public API - Resource Management

    /// 存储资源
    /// - Parameters:
    ///   - cacheID: 缓存 ID
    ///   - relativePath: 相对路径（如 "resources/logo.png"）
    ///   - data: 资源数据
    ///   - mimeType: MIME 类型
    /// - Throws: 存储错误
    public func storeResource(
        cacheID: String,
        relativePath: String,
        data: Data,
        mimeType: String
    ) throws {
        let cacheDirectory = cacheBaseDirectory.appendingPathComponent("cache-\(cacheID)")

        guard fileManager.fileExists(atPath: cacheDirectory.path) else {
            throw CacheError.cacheSpaceNotFound(cacheID)
        }

        // 构建文件路径
        let resourcePath = cacheDirectory.appendingPathComponent(relativePath)

        // 创建父目录
        let parentDirectory = resourcePath.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parentDirectory.path) {
            try fileManager.createDirectory(at: parentDirectory, withIntermediateDirectories: true)
        }

        // 写入文件
        try data.write(to: resourcePath)

        // 更新缓存大小
        sizeLock.lock()
        totalCacheSize += Int64(data.count)
        sizeLock.unlock()

        // 更新 manifest
        updateManifestForResource(cacheID: cacheID, relativePath: relativePath, data: data, mimeType: mimeType)

        print("💾 [WebResourceCacheManager] Stored resource")
        print("   - Cache ID: \(cacheID)")
        print("   - Path: \(relativePath)")
        print("   - Size: \(data.count) bytes")
    }

    /// 获取资源
    /// - Parameters:
    ///   - cacheID: 缓存 ID
    ///   - relativePath: 相对路径
    /// - Returns: 资源数据和 MIME 类型，如果不存在则返回 nil
    public func getResource(cacheID: String, relativePath: String) -> (data: Data, mimeType: String)? {
        let cacheDirectory = cacheBaseDirectory.appendingPathComponent("cache-\(cacheID)")

        guard fileManager.fileExists(atPath: cacheDirectory.path) else {
            return nil
        }

        let resourcePath = cacheDirectory.appendingPathComponent(relativePath)

        guard fileManager.fileExists(atPath: resourcePath.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: resourcePath)

            // 从 manifest 获取 MIME 类型
            var mimeType = "application/octet-stream"
            if let manifest = loadManifest(for: cacheID),
               let resourceInfo = manifest.resources[relativePath] {
                mimeType = resourceInfo.mimeType
            }

            updateAccessTime(for: cacheID)

            return (data, mimeType)
        } catch {
            print("❌ [WebResourceCacheManager] Failed to read resource: \(error.localizedDescription)")
            return nil
        }
    }

    /// 删除资源
    /// - Parameters:
    ///   - cacheID: 缓存 ID
    ///   - relativePath: 相对路径
    public func removeResource(cacheID: String, relativePath: String) {
        queue.async { [weak self] in
            guard let self = self else { return }

            let cacheDirectory = self.cacheBaseDirectory.appendingPathComponent("cache-\(cacheID)")
            let resourcePath = cacheDirectory.appendingPathComponent(relativePath)

            do {
                if self.fileManager.fileExists(atPath: resourcePath.path) {
                    let attributes = try self.fileManager.attributesOfItem(atPath: resourcePath.path)
                    if let fileSize = attributes[.size] as? Int64 {
                        self.sizeLock.lock()
                        self.totalCacheSize -= fileSize
                        self.sizeLock.unlock()
                    }

                    try self.fileManager.removeItem(at: resourcePath)
                    print("🗑️ [WebResourceCacheManager] Removed resource: \(relativePath)")
                }
            } catch {
                print("❌ [WebResourceCacheManager] Failed to remove resource: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Public API - Manifest Management

    /// 保存 manifest
    /// - Parameters:
    ///   - cacheID: 缓存 ID
    ///   - manifest: manifest 对象
    public func saveManifest(cacheID: String, manifest: WebResourceManifest) {
        let cacheDirectory = cacheBaseDirectory.appendingPathComponent("cache-\(cacheID)")
        let manifestPath = cacheDirectory.appendingPathComponent("manifest.json")

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(manifest)
            try data.write(to: manifestPath)

            print("💾 [WebResourceCacheManager] Saved manifest for: \(cacheID)")
        } catch {
            print("❌ [WebResourceCacheManager] Failed to save manifest: \(error.localizedDescription)")
        }
    }

    /// 加载 manifest
    /// - Parameter cacheID: 缓存 ID
    /// - Returns: manifest 对象，如果不存在或损坏则返回 nil
    public func loadManifest(for cacheID: String) -> WebResourceManifest? {
        let cacheDirectory = cacheBaseDirectory.appendingPathComponent("cache-\(cacheID)")
        let manifestPath = cacheDirectory.appendingPathComponent("manifest.json")

        guard fileManager.fileExists(atPath: manifestPath.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: manifestPath)
            let decoder = JSONDecoder()
            let manifest = try decoder.decode(WebResourceManifest.self, from: data)
            return manifest
        } catch {
            print("❌ [WebResourceCacheManager] Failed to load manifest: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Public API - Cache Statistics

    /// 获取缓存空间统计
    /// - Parameter cacheID: 缓存 ID
    /// - Returns: 统计信息，如果不存在则返回 nil
    public func getCacheStats(cacheID: String) -> CacheSpaceStats? {
        let cacheDirectory = cacheBaseDirectory.appendingPathComponent("cache-\(cacheID)")

        guard fileManager.fileExists(atPath: cacheDirectory.path) else {
            return nil
        }

        guard let url = getURL(for: cacheID) else {
            return nil
        }

        let manifest = loadManifest(for: cacheID)

        // 计算总大小和文件数
        var totalSize: Int64 = 0
        var fileCount = 0

        if let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = resourceValues.fileSize {
                    totalSize += Int64(fileSize)
                    fileCount += 1
                }
            }
        }

        let createdAt = (manifest?.createdAt) ?? (try? fileManager.attributesOfItem(atPath: cacheDirectory.path)[.creationDate] as? Date) ?? Date()
        let lastAccessedAt = cacheAccessTimes[cacheID] ?? Date()

        return CacheSpaceStats(
            cacheID: cacheID,
            url: url,
            totalSize: totalSize,
            fileCount: fileCount,
            createdAt: createdAt,
            lastAccessedAt: lastAccessedAt,
            manifest: manifest
        )
    }

    /// 获取所有缓存空间统计
    /// - Returns: 统计信息数组
    public func getAllCacheStats() -> [CacheSpaceStats] {
        mapLock.lock()
        let cacheIDs = Set(urlToCacheIDMap.values)
        mapLock.unlock()

        return cacheIDs.compactMap { getCacheStats(cacheID: $0) }
    }

    /// 获取全局缓存统计
    /// - Returns: 总缓存大小和总文件数
    public func getGlobalStats() -> (totalSize: Int64, totalFiles: Int) {
        var totalSize: Int64 = 0
        var totalFiles = 0

        if let enumerator = fileManager.enumerator(at: cacheBaseDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = resourceValues.fileSize {
                    totalSize += Int64(fileSize)
                    totalFiles += 1
                }
            }
        }

        return (totalSize, totalFiles)
    }

    // MARK: - Public API - LRU Eviction

    /// 清理最少使用的缓存空间
    /// - Parameters:
    ///   - count: 要清理的数量
    ///   - policy: 清理策略
    /// - Returns: 已清理的缓存 ID 数组
    public func evictLeastRecentlyUsed(count: Int, policy: LRUEvictionPolicy = .leastRecentlyUsed) -> [String] {
        mapLock.lock()
        defer { mapLock.unlock() }

        let sortedCacheIDs = getSortedCacheIDs(by: policy)
        let toRemove = Array(sortedCacheIDs.prefix(count))

        for cacheID in toRemove {
            removeCacheSpace(cacheID: cacheID)
        }

        print("🧹 [WebResourceCacheManager] Evicted \(toRemove.count) cache spaces using policy: \(policy)")

        return toRemove
    }

    /// 清理所有超过指定大小的缓存
    /// - Parameter maxSizeInBytes: 最大缓存大小（字节）
    /// - Returns: 已清理的缓存 ID 数组
    public func evictExceedingSize(maxSizeInBytes: Int64) -> [String] {
        var currentSize: Int64 = 0
        var cacheSizes: [(String, Int64)] = []

        // 计算每个缓存的大小
        for cacheID in urlToCacheIDMap.values {
            if let stats = getCacheStats(cacheID: cacheID) {
                cacheSizes.append((cacheID, stats.totalSize))
                currentSize += stats.totalSize
            }
        }

        // 按大小排序（从大到小）
        cacheSizes.sort { $0.1 > $1.1 }

        var removed: [String] = []

        for (cacheID, size) in cacheSizes {
            if currentSize <= maxSizeInBytes {
                break
            }

            removeCacheSpace(cacheID: cacheID)
            removed.append(cacheID)
            currentSize -= size
        }

        print("🧹 [WebResourceCacheManager] Evicted \(removed.count) cache spaces to fit size limit")

        return removed
    }

    /// 清理所有超过指定年龄的缓存
    /// - Parameter maxAge: 最大年龄（秒）
    /// - Returns: 已清理的缓存 ID 数组
    public func evictOlderThan(maxAge: TimeInterval) -> [String] {
        let allStats = getAllCacheStats()
        let now = Date()

        let toRemove = allStats.filter { stats in
            now.timeIntervalSince(stats.createdAt) > maxAge
        }.map { $0.cacheID }

        for cacheID in toRemove {
            removeCacheSpace(cacheID: cacheID)
        }

        print("🧹 [WebResourceCacheManager] Evicted \(toRemove.count) old cache spaces (older than \(maxAge)s)")

        return toRemove
    }

    /// 清理所有缓存
    public func clearAll() {
        mapLock.lock()
        let cacheIDs = Array(urlToCacheIDMap.values)
        urlToCacheIDMap.removeAll()
        cacheAccessTimes.removeAll()
        mapLock.unlock()

        for cacheID in cacheIDs {
            let cacheDirectory = cacheBaseDirectory.appendingPathComponent("cache-\(cacheID)")
            try? fileManager.removeItem(at: cacheDirectory)
        }

        sizeLock.lock()
        totalCacheSize = 0
        sizeLock.unlock()

        saveCacheIndex()
        updateTotalCacheSize()

        print("🗑️ [WebResourceCacheManager] Cleared all cache spaces")
    }

    /// 清理未使用的资源
    /// - Parameter interval: 过期时间间隔（秒）
    public func cleanupUnusedResources(olderThan interval: TimeInterval) {
        queue.async {
            self.mapLock.lock()
            let now = Date()
            let expiredIDs = self.cacheAccessTimes.filter { now.timeIntervalSince($1) > interval }.map { $0.key }
            self.mapLock.unlock()
            
            for cacheID in expiredIDs {
                self.removeCacheSpace(cacheID: cacheID)
            }
            
            if !expiredIDs.isEmpty {
                print("🧹 [WebResourceCacheManager] Cleaned up \(expiredIDs.count) expired cache spaces")
            }
        }
    }

    // MARK: - Private Helpers

    private func setupCacheDirectory() {
        if !fileManager.fileExists(atPath: cacheBaseDirectory.path) {
            do {
                try fileManager.createDirectory(at: cacheBaseDirectory, withIntermediateDirectories: true, attributes: nil)
                print("✅ [WebResourceCacheManager] Created cache directory")
            } catch {
                print("❌ [WebResourceCacheManager] Failed to create cache directory: \(error.localizedDescription)")
            }
        }
    }

    private func loadCacheIndex() {
        guard fileManager.fileExists(atPath: cacheIndexFile.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: cacheIndexFile)
            if let dict = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: String] {
                urlToCacheIDMap = dict
                print("✅ [WebResourceCacheManager] Loaded cache index: \(dict.count) entries")
            }
        } catch {
            print("❌ [WebResourceCacheManager] Failed to load cache index: \(error.localizedDescription)")
        }
    }

    private func saveCacheIndex() {
        queue.async { [weak self] in
            guard let self = self else { return }

            do {
                let data = try PropertyListSerialization.data(fromPropertyList: self.urlToCacheIDMap, format: .xml, options: 0)
                try data.write(to: self.cacheIndexFile)
            } catch {
                print("❌ [WebResourceCacheManager] Failed to save cache index: \(error.localizedDescription)")
            }
        }
    }

    private func updateAccessTime(for cacheID: String) {
        accessLock.lock()
        defer { accessLock.unlock() }
        cacheAccessTimes[cacheID] = Date()
    }

    private func updateTotalCacheSize() {
        queue.async { [weak self] in
            guard let self = self else { return }

            var total: Int64 = 0

            if let enumerator = self.fileManager.enumerator(at: self.cacheBaseDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
                for case let fileURL as URL in enumerator {
                    if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                       let fileSize = resourceValues.fileSize {
                        total += Int64(fileSize)
                    }
                }
            }

            self.sizeLock.lock()
            self.totalCacheSize = total
            self.sizeLock.unlock()

            print("📊 [WebResourceCacheManager] Total cache size: \(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))")
        }
    }

    private func updateManifestForResource(cacheID: String, relativePath: String, data: Data, mimeType: String) {
        var manifest = loadManifest(for: cacheID)

        if manifest == nil {
            // 创建新 manifest
            if let url = getURL(for: cacheID) {
                manifest = WebResourceManifest(
                    url: url.absoluteString,
                    htmlContent: "",
                    resources: [:]
                )
            }
        }

        guard var manifest = manifest else { return }

        // 更新资源信息
        let resourceInfo = ResourceInfo(
            relativePath: relativePath,
            originalURL: relativePath,
            mimeType: mimeType,
            fileSize: data.count
        )

        manifest.resources[relativePath] = resourceInfo
        manifest.lastAccessedAt = Date()

        saveManifest(cacheID: cacheID, manifest: manifest)
    }

    private func getSortedCacheIDs(by policy: LRUEvictionPolicy) -> [String] {
        let allStats = getAllCacheStats()

        switch policy {
        case .leastRecentlyUsed:
            return allStats.sorted { $0.lastAccessedAt < $1.lastAccessedAt }.map { $0.cacheID }
        case .oldest:
            return allStats.sorted { $0.createdAt < $1.createdAt }.map { $0.cacheID }
        case .largest:
            return allStats.sorted { $0.totalSize > $1.totalSize }.map { $0.cacheID }
        case .leastFrequentlyUsed:
            // 基于访问频率排序（这里简化为基于最后访问时间）
            return allStats.sorted { $0.lastAccessedAt < $1.lastAccessedAt }.map { $0.cacheID }
        }
    }
}
