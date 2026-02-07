//
//  InterceptiveCacheManager.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-02-01.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation

/// 拦截式缓存管理器
/// 通过 WKNavigationDelegate 拦截请求，实现透明的缓存回退机制
public class InterceptiveCacheManager {

    public static let shared = InterceptiveCacheManager()

    /// 缓存命中通知
    public static let cacheHitNotification = Notification.Name("com.webbridgekit.interceptive-cache.hit")

    // MARK: - Properties

    private let cacheDirectory: URL
    private let metadataStore: CacheMetadataStore
    private let queue = DispatchQueue(label: "com.webbridgekit.interceptive-cache", qos: .userInitiated)

    // MARK: - Initialization

    private init() {
        // 设置缓存目录
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        self.cacheDirectory = paths[0].appendingPathComponent("InterceptivePageCache")

        // 创建缓存目录
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // 初始化元数据存储
        self.metadataStore = CacheMetadataStore()

        print("✅ [InterceptiveCacheManager] Initialized with cache directory: \(cacheDirectory.path)")
    }

    // MARK: - Public API

    /// 检查资源是否有缓存
    /// - Parameter url: 资源URL
    /// - Returns: 是否有缓存
    public func hasCachedResource(for url: URL) -> Bool {
        return queue.sync {
            guard let metadata = metadataStore.metadata(for: url) else {
                return false
            }

            // 检查文件是否存在
            let localPath = cacheDirectory.appendingPathComponent(metadata.localPath)
            return FileManager.default.fileExists(atPath: localPath.path)
        }
    }

    /// 加载缓存的资源
    /// - Parameter url: 资源URL
    /// - Returns: 缓存的资源数据，如果不存在或已过期则返回 nil
    public func loadCachedResource(for url: URL) -> CachedResource? {
        return queue.sync {
            guard let metadata = metadataStore.metadata(for: url) else {
                print("⚠️ [InterceptiveCache] No metadata for: \(url.absoluteString)")
                return nil
            }

            // 检查缓存是否过期
            if !isCacheValid(metadata: metadata) {
                print("⚠️ [InterceptiveCache] Cache expired for: \(url.absoluteString)")
                // 删除过期缓存
                try? removeCache(for: url)
                return nil
            }

            // 读取缓存文件
            let localPath = cacheDirectory.appendingPathComponent(metadata.localPath)
            guard let data = try? Data(contentsOf: localPath) else {
                print("❌ [InterceptiveCache] Failed to read cache file: \(localPath.path)")
                return nil
            }

            print("✅ [InterceptiveCache] Cache HIT: \(url.absoluteString)")

            // 发送通知，用于 UI 显示
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: InterceptiveCacheManager.cacheHitNotification,
                    object: nil,
                    userInfo: ["url": url, "source": "INTERCEPT"]
                )
            }

            return CachedResource(
                url: url,
                data: data,
                mimeType: metadata.mimeType,
                cachedAt: metadata.cachedAt
            )
        }
    }

    /// 保存资源到缓存
    /// - Parameters:
    ///   - data: 资源数据
    ///   - url: 资源URL
    ///   - mimeType: MIME类型
    public func cacheResource(_ data: Data, for url: URL, mimeType: String) {
        queue.async { [weak self] in
            guard let self = self else { return }

            // 生成文件名
            let filename = self.generateFilename(for: url)
            let localPath = self.cacheDirectory.appendingPathComponent(filename)

            do {
                // 写入文件
                try data.write(to: localPath)

                // 保存元数据
                let metadata = CacheMetadata(
                    url: url,
                    localPath: filename,
                    mimeType: mimeType,
                    cachedAt: Date()
                )
                self.metadataStore.saveMetadata(metadata)

                print("✅ [InterceptiveCache] Cached: \(url.absoluteString) -> \(filename)")
            } catch {
                print("❌ [InterceptiveCache] Failed to cache resource: \(error.localizedDescription)")
            }
        }
    }

    /// 删除缓存
    /// - Parameter url: 资源URL
    public func removeCache(for url: URL) throws {
        try queue.sync {
            guard let metadata = metadataStore.metadata(for: url) else {
                throw NSError(domain: "InterceptiveCacheManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Cache not found"])
            }

            let localPath = cacheDirectory.appendingPathComponent(metadata.localPath)
            try FileManager.default.removeItem(at: localPath)
            metadataStore.deleteMetadata(for: url)

            print("🗑️ [InterceptiveCache] Removed cache for: \(url.absoluteString)")
        }
    }

    /// 清除所有缓存
    public func clearAllCache() {
        queue.sync {
            do {
                // 删除所有缓存文件
                let contents = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
                for file in contents {
                    try FileManager.default.removeItem(at: file)
                }

                // 清除元数据
                metadataStore.clearAll()

                print("🗑️ [InterceptiveCache] All cache cleared")
            } catch {
                print("❌ [InterceptiveCache] Failed to clear cache: \(error.localizedDescription)")
            }
        }
    }

    /// 获取缓存大小
    /// - Returns: 缓存总大小（字节）
    public func getCacheSize() -> Int64 {
        return queue.sync {
            var totalSize: Int64 = 0

            if let enumerator = FileManager.default.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
                for case let fileURL as URL in enumerator {
                    if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                       let fileSize = resourceValues.fileSize {
                        totalSize += Int64(fileSize)
                    }
                }
            }

            return totalSize
        }
    }

    /// 清理过期缓存
    public func cleanupExpiredCache() {
        queue.async { [weak self] in
            guard let self = self else { return }

            let now = Date()
            let allMetadata = self.metadataStore.allMetadata()

            for metadata in allMetadata {
                let age = now.timeIntervalSince(metadata.cachedAt)
                let maxAge: TimeInterval

                // 根据文件类型设置不同的过期时间
                switch metadata.mimeType {
                case "application/javascript", "text/css":
                    maxAge = 7 * 24 * 3600  // 7天
                case "image/png", "image/jpeg", "image/gif", "image/webp":
                    maxAge = 30 * 24 * 3600 // 30天
                default:
                    maxAge = 1 * 24 * 3600  // 1天
                }

                if age > maxAge {
                    try? self.removeCache(for: metadata.url)
                }
            }
        }
    }

    // MARK: - Private Helpers

    /// 检查缓存是否有效
    private func isCacheValid(metadata: CacheMetadata) -> Bool {
        let now = Date()
        let age = now.timeIntervalSince(metadata.cachedAt)

        // 根据文件类型设置不同的过期时间
        let maxAge: TimeInterval
        switch metadata.mimeType {
        case "application/javascript", "text/css":
            maxAge = 7 * 24 * 3600  // 7天
        case "image/png", "image/jpeg", "image/gif", "image/webp":
            maxAge = 30 * 24 * 3600 // 30天
        default:
            maxAge = 1 * 24 * 3600  // 1天
        }

        return age < maxAge
    }

    /// 生成缓存文件名
    private func generateFilename(for url: URL) -> String {
        // 使用URL的hash作为文件名
        let hash = url.absoluteString.hashValue
        let ext = (url.pathExtension.isEmpty) ? "dat" : url.pathExtension
        return "cache_\(abs(hash)).\(ext)"
    }
}

// MARK: - CacheMetadataStore

/// 缓存元数据存储
private class CacheMetadataStore {

    private var metadata: [String: CacheMetadata] = [:]
    private let lock = NSLock()
    private let metadataFilePath: URL

    init() {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let metadataDir = paths[0].appendingPathComponent("InterceptivePageCache")
        self.metadataFilePath = metadataDir.appendingPathComponent("metadata.plist")

        // 加载已保存的元数据
        loadMetadata()
    }

    /// 获取元数据
    func metadata(for url: URL) -> CacheMetadata? {
        lock.lock()
        defer { lock.unlock() }
        return metadata[url.absoluteString]
    }

    /// 保存元数据
    func saveMetadata(_ item: CacheMetadata) {
        lock.lock()
        defer { lock.unlock() }

        metadata[item.url.absoluteString] = item
        saveMetadataToFile()
    }

    /// 删除元数据
    func deleteMetadata(for url: URL) {
        lock.lock()
        defer { lock.unlock() }

        metadata.removeValue(forKey: url.absoluteString)
        saveMetadataToFile()
    }

    /// 获取所有元数据
    func allMetadata() -> [CacheMetadata] {
        lock.lock()
        defer { lock.unlock() }
        return Array(metadata.values)
    }

    /// 清除所有元数据
    func clearAll() {
        lock.lock()
        defer { lock.unlock() }

        metadata.removeAll()
        saveMetadataToFile()
    }

    // MARK: - File I/O

    private func loadMetadata() {
        guard FileManager.default.fileExists(atPath: metadataFilePath.path) else {
            return
        }

        guard let data = try? Data(contentsOf: metadataFilePath),
              let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: [String: Any]] else {
            return
        }

        var loaded: [String: CacheMetadata] = [:]

        for (key, value) in dict {
            guard let urlString = value["url"] as? String,
                  let url = URL(string: urlString),
                  let localPath = value["localPath"] as? String,
                  let mimeType = value["mimeType"] as? String,
                  let timestamp = value["cachedAt"] as? TimeInterval else {
                continue  // Skip invalid entries
            }
            loaded[key] = CacheMetadata(
                url: url,
                localPath: localPath,
                mimeType: mimeType,
                cachedAt: Date(timeIntervalSince1970: timestamp)
            )
        }

        lock.lock()
        metadata = loaded
        lock.unlock()
    }

    private func saveMetadataToFile() {
        var dict: [String: [String: Any]] = [:]

        for (key, value) in metadata {
            dict[key] = [
                "url": value.url.absoluteString,
                "localPath": value.localPath,
                "mimeType": value.mimeType,
                "cachedAt": value.cachedAt.timeIntervalSince1970
            ]
        }

        if let data = try? PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0) {
            try? data.write(to: metadataFilePath)
        }
    }
}

