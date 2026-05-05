//
//  ManifestStore.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-02-02.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation

/// Manifest 存储管理
public class ManifestStore: ManifestCacheManaging {

    public static let shared = ManifestStore()

    /// 缓存条目（带时间戳）
    private struct CacheEntry {
        let html: String
        let timestamp: Date

        var isExpired: Bool {
            // 默认 7 天过期
            let expirationDays = 7
            let expirationInterval = TimeInterval(expirationDays * 24 * 60 * 60)
            return Date().timeIntervalSince(timestamp) > expirationInterval
        }
    }

    /// Manifest 缓存条目（带时间戳）
    private struct ManifestCacheEntry {
        let manifest: Manifest
        let timestamp: Date

        var isExpired: Bool {
            // 默认 7 天过期
            let expirationDays = 7
            let expirationInterval = TimeInterval(expirationDays * 24 * 60 * 60)
            return Date().timeIntervalSince(timestamp) > expirationInterval
        }
    }

    private var htmlCache: [String: CacheEntry] = [:]
    private var manifestCache: [String: ManifestCacheEntry] = [:]
    private var currentManifests: [String: Manifest] = [:]

    /// ✅ FIX: Serial queue for thread-safe access to shared state
    /// Replaced NSLock with serial queue to prevent deadlock risks
    private let serialQueue = DispatchQueue(label: "com.webbridgekit.manifest-store", qos: .userInitiated)
    private let htmlFilePath: URL
    private let manifestFilePath: URL

    // Async save mechanism
    private var savePending = false

    public init() {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let cacheDir = paths[0].appendingPathComponent("ManifestCache")

        // 创建缓存目录
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        self.htmlFilePath = cacheDir.appendingPathComponent("html_cache.plist")
        self.manifestFilePath = cacheDir.appendingPathComponent("manifest_cache.plist")

        // 异步加载已保存的数据，减少主线程压力
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.loadFromDisk()
            Log.info("Disk data loaded in background", category: .manifest)
        }

        Log.info("Initialized (background loading started)", category: .manifest)
    }

    // MARK: - HTML Storage

    public func getHTML(for key: String) -> String? {
        return serialQueue.sync {
            return htmlCache[key]?.html
        }
    }

    public func saveHTML(_ html: String, for key: String) {
        serialQueue.async { [weak self] in
            guard let self = self else { return }

            self.htmlCache[key] = CacheEntry(html: html, timestamp: Date())
            self.scheduleAsyncSave()

            // 发送更新通知
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .manifestCacheDidUpdate, object: nil)
            }
        }
    }

    public func removeHTML(for key: String) {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            self.htmlCache.removeValue(forKey: key)
            self.scheduleAsyncSave()
        }
    }

    // MARK: - Manifest Storage

    public func getManifest(for key: String) -> Manifest? {
        return serialQueue.sync {
            return manifestCache[key]?.manifest
        }
    }

    public func saveManifest(_ manifest: Manifest, for key: String) {
        serialQueue.async { [weak self] in
            guard let self = self else { return }

            var updatedManifest = manifest
            updatedManifest.version = updatedManifest.version ?? UUID().uuidString
            updatedManifest.lastUpdated = Date()
            self.manifestCache[key] = ManifestCacheEntry(manifest: updatedManifest, timestamp: Date())
            self.scheduleAsyncSave()

            // 发送更新通知
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .manifestCacheDidUpdate, object: nil)
            }
        }
    }

    public func removeManifest(for key: String) {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            self.manifestCache.removeValue(forKey: key)
            self.scheduleAsyncSave()
        }
    }

    /// 清空所有缓存
    public func clearAll() {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            self.htmlCache.removeAll()
            self.manifestCache.removeAll()
            self.currentManifests.removeAll()

            DispatchQueue.global(qos: .utility).async { [weak self] in
                guard let self = self else { return }
                try? FileManager.default.removeItem(at: self.htmlFilePath)
                try? FileManager.default.removeItem(at: self.manifestFilePath)
                Log.info("Cleared all data from disk", category: .manifest)
            }

            // 发送更新通知
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .manifestCacheDidUpdate, object: nil)
            }
        }
    }

    // MARK: - Current Manifest

    public func getCurrentManifest(for key: String) -> Manifest? {
        return serialQueue.sync {
            return currentManifests[key]
        }
    }

    public func setCurrentManifest(_ manifest: Manifest, for key: String) {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            self.currentManifests[key] = manifest
            self.scheduleAsyncSave()
        }
    }

    /// 获取所有已缓存的页面 key
    /// - Returns: 所有页面标识符（HTML 或 Manifest）
    public func getAllPageKeys() -> [String] {
        return serialQueue.sync {
            return Array(manifestCache.keys)
        }
    }

    /// 根据 appId 获取 Manifest 和对应的 key
    public func getManifestByAppId(_ appId: String) -> (key: String, manifest: Manifest)? {
        return serialQueue.sync {
            for (key, entry) in manifestCache where entry.manifest.appid == appId {
                return (key, entry.manifest)
            }
            return nil
        }
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        // 加载 HTML 缓存
        if let htmlData = try? Data(contentsOf: htmlFilePath),
           let htmlDict = try? PropertyListSerialization.propertyList(from: htmlData, options: [], format: nil) as? [String: String] {
            // 转换为新的 CacheEntry 结构，使用当前时间作为时间戳
            let newHtmlCache = htmlDict.mapValues { html in
                CacheEntry(html: html, timestamp: Date())
            }
            serialQueue.async { [weak self] in
                guard let self = self else { return }
                self.htmlCache = newHtmlCache
            }
        }

        // 加载 Manifest 缓存
        if let manifestData = try? Data(contentsOf: manifestFilePath),
           let manifestDict = try? PropertyListSerialization.propertyList(from: manifestData, options: [], format: nil) as? [String: [String: Any]] {
            var loaded: [String: ManifestCacheEntry] = [:]

            for (key, value) in manifestDict {
                if let resources = value["resources"] as? [String: String] {
                    var manifest = Manifest(resources: resources)

                    // Load optional fields
                    if let version = value["version"] as? String {
                        manifest.version = version
                    }
                    if let timestamp = value["lastUpdated"] as? TimeInterval {
                        manifest.lastUpdated = Date(timeIntervalSince1970: timestamp)
                    }
                    if let appid = value["appid"] as? String, !appid.isEmpty {
                        manifest.appid = appid
                    }
                    if let name = value["name"] as? String, !name.isEmpty {
                        manifest.name = name
                    }
                    if let icon = value["icon"] as? String, !icon.isEmpty {
                        manifest.icon = icon
                    }
                    if let isPinned = value["isPinned"] as? Bool {
                        manifest.isPinned = isPinned
                    }
                    if let isFavorite = value["isFavorite"] as? Bool {
                        manifest.isFavorite = isFavorite
                    }
                    if let lastAccessedTimestamp = value["lastAccessed"] as? TimeInterval {
                        manifest.lastAccessed = Date(timeIntervalSince1970: lastAccessedTimestamp)
                    }
                    if let accessCount = value["accessCount"] as? Int {
                        manifest.accessCount = accessCount
                    }

                    // 使用 lastUpdated 作为缓存时间戳，如果没有则使用当前时间
                    let cacheTimestamp = manifest.lastUpdated ?? Date()
                    loaded[key] = ManifestCacheEntry(manifest: manifest, timestamp: cacheTimestamp)
                }
            }

            serialQueue.async { [weak self] in
                guard let self = self else { return }
                self.manifestCache = loaded
            }
        }

        let htmlCount = serialQueue.sync { htmlCache.count }
        let manifestCount = serialQueue.sync { manifestCache.count }
        Log.info("Loaded from disk: \(htmlCount) HTMLs, \(manifestCount) manifests", category: .manifest)
    }

    /// ✅ FIX: Simplified async save with serialQueue - no complex locking needed
    private func scheduleAsyncSave() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            // Get copies of data from serialQueue
            let htmlCopy: [String: String]
            let manifestDictCopy: [String: [String: Any]]

            htmlCopy = self.serialQueue.sync {
                return self.htmlCache.mapValues { $0.html }
            }

            manifestDictCopy = self.serialQueue.sync {
                var dict: [String: [String: Any]] = [:]
                for (key, entry) in self.manifestCache {
                    let manifest = entry.manifest
                    var manifestDict: [String: Any] = [
                        "resources": manifest.resources,
                        "appid": manifest.appid ?? "",
                        "name": manifest.name ?? "",
                        "icon": manifest.icon ?? "",
                        "isPinned": manifest.isPinned ?? false,
                        "isFavorite": manifest.isFavorite ?? false,
                        "accessCount": manifest.accessCount ?? 0
                    ]
                    if let version = manifest.version {
                        manifestDict["version"] = version
                    }
                    if let lastUpdated = manifest.lastUpdated {
                        manifestDict["lastUpdated"] = lastUpdated.timeIntervalSince1970
                    }
                    if let lastAccessed = manifest.lastAccessed {
                        manifestDict["lastAccessed"] = lastAccessed.timeIntervalSince1970
                    }
                    dict[key] = manifestDict
                }
                return dict
            }

            // Perform I/O without holding any lock
            if let htmlData = try? PropertyListSerialization.data(fromPropertyList: htmlCopy, format: .xml, options: 0) {
                try? htmlData.write(to: self.htmlFilePath)
            }

            if let manifestData = try? PropertyListSerialization.data(fromPropertyList: manifestDictCopy, format: .xml, options: 0) {
                try? manifestData.write(to: self.manifestFilePath)
            }
        }
    }

    private func saveToDisk() {
        // 保存 HTML 缓存
        let htmlCopy = serialQueue.sync {
            return htmlCache.mapValues { $0.html }
        }

        if let htmlData = try? PropertyListSerialization.data(fromPropertyList: htmlCopy, format: .xml, options: 0) {
            try? htmlData.write(to: htmlFilePath)
        }

        // 保存 Manifest 缓存
        let manifestCopy = serialQueue.sync {
            var dict: [String: [String: Any]] = [:]
            for (key, entry) in manifestCache {
                let manifest = entry.manifest
                var manifestDict: [String: Any] = [
                    "resources": manifest.resources,
                    "appid": manifest.appid ?? "",
                    "name": manifest.name ?? "",
                    "icon": manifest.icon ?? "",
                    "isPinned": manifest.isPinned ?? false,
                    "isFavorite": manifest.isFavorite ?? false,
                    "accessCount": manifest.accessCount ?? 0
                ]

                if let version = manifest.version {
                    manifestDict["version"] = version
                }

                if let lastUpdated = manifest.lastUpdated {
                    manifestDict["lastUpdated"] = lastUpdated.timeIntervalSince1970
                }

                if let lastAccessed = manifest.lastAccessed {
                    manifestDict["lastAccessed"] = lastAccessed.timeIntervalSince1970
                }

                dict[key] = manifestDict
            }
            return dict
        }

        if let manifestData = try? PropertyListSerialization.data(fromPropertyList: manifestCopy, format: .xml, options: 0) {
            try? manifestData.write(to: manifestFilePath)
        }
    }
}

// MARK: - ResourceCache

/// 资源缓存（内存 + 磁盘）
public class ResourceCache {

    public static let shared = ResourceCache()

    private var memoryCache: [String: ResourceData] = [:]
    private let memoryCapacity = 100 * 1024 * 1024  // 100 MB
    private var currentMemorySize: Int64 = 0

    private let diskCacheDirectory: URL

    /// ✅ FIX: Using serialQueue for thread-safe operations
    private let serialQueue = DispatchQueue(label: "com.webbridgekit.resource-cache", qos: .userInitiated)

    public init() {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        self.diskCacheDirectory = paths[0].appendingPathComponent("ManifestCache/Resources")

        // 创建资源缓存目录
        try? FileManager.default.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)

        print("✅ [ResourceCache] Initialized with disk cache: \(diskCacheDirectory.path)")
    }

    // MARK: - Cache Operations

    public func get(_ relativePath: String, for pageKey: String) -> ResourceData? {
        let key = cacheKey(relativePath, pageKey: pageKey)

        // 先查内存
        let cachedResource = serialQueue.sync {
            return memoryCache[key]
        }

        if let resource = cachedResource {
            return resource
        }

        // 再查磁盘
        let diskPath = diskCacheDirectory.appendingPathComponent(key)
        guard let data = try? Data(contentsOf: diskPath) else {
            return nil
        }

        // 读取元数据
        let metaPath = diskPath.appendingPathExtension("meta")
        var mimeType = "application/octet-stream"

        if let metaData = try? Data(contentsOf: metaPath),
           let meta = try? JSONSerialization.jsonObject(with: metaData, options: []) as? [String: Any],
           let mt = meta["mimeType"] as? String {
            mimeType = mt
        }

        return ResourceData(relativePath: relativePath, data: data, mimeType: mimeType)
    }

    func set(_ resource: ResourceData, for pageKey: String) {
        serialQueue.async { [weak self] in
            guard let self = self else { return }

            let key = self.cacheKey(resource.relativePath, pageKey: pageKey)
            let diskPath = self.diskCacheDirectory.appendingPathComponent(key)

            do {
                // ✅ FIX: 确保父目录存在（解决 "The file doesn't exist" 错误）
                let parentDirectory = diskPath.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: parentDirectory, withIntermediateDirectories: true, attributes: nil)

                // Write to disk first
                try resource.data.write(to: diskPath)

                // Save metadata
                let meta: [String: Any] = [
                    "mimeType": resource.mimeType,
                    "cachedAt": Date().timeIntervalSince1970
                ]

                if let metaData = try? JSONSerialization.data(withJSONObject: meta, options: []) {
                    try metaData.write(to: diskPath.appendingPathExtension("meta"))
                }

                // Update memory cache
                let resourceSize = Int64(resource.data.count)

                // Evict old resources if needed
                while self.currentMemorySize + resourceSize > self.memoryCapacity && !self.memoryCache.isEmpty {
                    if let firstKey = self.memoryCache.keys.first,
                       let firstResource = self.memoryCache.removeValue(forKey: firstKey) {
                        self.currentMemorySize -= Int64(firstResource.data.count)
                    }
                }

                self.memoryCache[key] = resource
                self.currentMemorySize += resourceSize

                print("✅ [ResourceCache] Cached: \(resource.relativePath) (\(resource.data.count) bytes)")

                // 发送更新通知
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .manifestCacheDidUpdate, object: nil)
                }
            } catch {
                print("❌ [ResourceCache] Failed to cache: \(error.localizedDescription)")
            }
        }
    }

    func removeResources(for pageKey: String) {
        serialQueue.async { [weak self] in
            guard let self = self else { return }

            // 移除内存缓存
            var keysToRemove: [String] = []
            for key in self.memoryCache.keys where key.contains("/\(pageKey)/") {
                keysToRemove.append(key)
            }

            for key in keysToRemove {
                if let resource = self.memoryCache.removeValue(forKey: key) {
                    self.currentMemorySize -= Int64(resource.data.count)
                }
            }

            // 移除磁盘缓存
            if let enumerator = FileManager.default.enumerator(at: self.diskCacheDirectory, includingPropertiesForKeys: nil) {
                for case let fileURL as URL in enumerator {
                    let filename = fileURL.lastPathComponent
                    if filename.contains("/\(pageKey)/") {
                        try? FileManager.default.removeItem(at: fileURL)
                    }
                }
            }
        }
    }

    func removeAll() {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            self.memoryCache.removeAll()
            self.currentMemorySize = 0

            // 清空磁盘目录
            if let enumerator = FileManager.default.enumerator(at: self.diskCacheDirectory, includingPropertiesForKeys: nil) {
                for case let fileURL as URL in enumerator {
                    try? FileManager.default.removeItem(at: fileURL)
                }
            }
        }
    }

    /// 移除指定 pageKey 的所有缓存
    /// - Parameter pageKey: 页面标识符
    func removeAll(for pageKey: String) {
        serialQueue.async { [weak self] in
            guard let self = self else { return }

            let pageKeyPrefix = "\(pageKey)/"

            // 从内存缓存中删除
            var keysToRemove: [String] = []
            for key in self.memoryCache.keys where key.hasPrefix(pageKeyPrefix) {
                keysToRemove.append(key)
            }
            for key in keysToRemove {
                if let resource = self.memoryCache.removeValue(forKey: key) {
                    self.currentMemorySize -= Int64(resource.data.count)
                }
            }

            // 从磁盘缓存中删除
            if let enumerator = FileManager.default.enumerator(at: self.diskCacheDirectory, includingPropertiesForKeys: nil) {
                for case let fileURL as URL in enumerator {
                    let fileName = fileURL.lastPathComponent
                    if fileName.hasPrefix(pageKeyPrefix) {
                        try? FileManager.default.removeItem(at: fileURL)
                    }
                    // 也删除元数据文件
                    let metaFileName = fileName + ".meta"
                    if let metaFileURL = URL(string: fileURL.deletingLastPathComponent().appendingPathComponent(metaFileName).absoluteString) {
                        if metaFileURL.lastPathComponent.hasPrefix(pageKeyPrefix) {
                            try? FileManager.default.removeItem(at: metaFileURL)
                        }
                    }
                }
            }

            print("🗑️ [ResourceCache] Removed all resources for pageKey: \(pageKey)")
        }
    }

    public func totalSize() -> Int64 {
        // 计算磁盘缓存大小
        var totalSize: Int64 = 0

        if let enumerator = FileManager.default.enumerator(at: diskCacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = resourceValues.fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        }

        return totalSize
    }

    // MARK: - Private Helpers

    private func cacheKey(_ relativePath: String, pageKey: String) -> String {
        // 使用 pageKey 作为子目录，避免不同页面的同名文件冲突
        return "\(pageKey)/\(relativePath)"
    }
}
