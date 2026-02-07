//
//  ManifestStore.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-02-02.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation

/// Manifest 存储管理
public class ManifestStore {

    public static let shared = ManifestStore()

    private var htmlCache: [String: String] = [:]
    private var manifestCache: [String: Manifest] = [:]
    private var currentManifests: [String: Manifest] = [:]

    private let lock = NSLock()
    private let htmlFilePath: URL
    private let manifestFilePath: URL

    // Async save mechanism to avoid lock-I/O deadlock
    private var savePending = false
    private let saveQueue = DispatchQueue(label: "com.webbridgekit.manifest-save", qos: .utility)

    public init() {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let cacheDir = paths[0].appendingPathComponent("ManifestCache")

        // 创建缓存目录
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        self.htmlFilePath = cacheDir.appendingPathComponent("html_cache.plist")
        self.manifestFilePath = cacheDir.appendingPathComponent("manifest_cache.plist")

        // 加载已保存的数据
        loadFromDisk()
    }

    // MARK: - HTML Storage
    
    public func getHTML(for key: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return htmlCache[key]
    }

    public func saveHTML(_ html: String, for key: String) {
        lock.lock()
        defer { lock.unlock() }

        htmlCache[key] = html
        scheduleAsyncSave()
        
        // 发送更新通知
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("ManifestCacheDidUpdate"), object: nil)
        }
    }

    public func removeHTML(for key: String) {
        lock.lock()
        defer { lock.unlock() }

        htmlCache.removeValue(forKey: key)
        scheduleAsyncSave()
    }

    // MARK: - Manifest Storage

    public func getManifest(for key: String) -> Manifest? {
        lock.lock()
        defer { lock.unlock() }
        return manifestCache[key]
    }

    public func saveManifest(_ manifest: Manifest, for key: String) {
        lock.lock()
        defer { lock.unlock() }

        var updatedManifest = manifest
        updatedManifest.version = updatedManifest.version ?? UUID().uuidString
        updatedManifest.lastUpdated = Date()
        manifestCache[key] = updatedManifest
        scheduleAsyncSave()
        
        // 发送更新通知
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("ManifestCacheDidUpdate"), object: nil)
        }
    }

    public func removeManifest(for key: String) {
        lock.lock()
        defer { lock.unlock() }

        manifestCache.removeValue(forKey: key)
        scheduleAsyncSave()
    }

    /// 清空所有缓存
    public func clearAll() {
        lock.lock()
        htmlCache.removeAll()
        manifestCache.removeAll()
        currentManifests.removeAll()
        lock.unlock()

        saveQueue.async { [weak self] in
            guard let self = self else { return }
            try? FileManager.default.removeItem(at: self.htmlFilePath)
            try? FileManager.default.removeItem(at: self.manifestFilePath)
            print("🗑️ [ManifestStore] Cleared all data from disk")
        }

        // 发送更新通知
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("ManifestCacheDidUpdate"), object: nil)
        }
    }

    // MARK: - Current Manifest

    public func getCurrentManifest(for key: String) -> Manifest? {
        lock.lock()
        defer { lock.unlock() }
        return currentManifests[key]
    }

    public func setCurrentManifest(_ manifest: Manifest, for key: String) {
        lock.lock()
        defer { lock.unlock() }
        currentManifests[key] = manifest
        scheduleAsyncSave()
    }

    /// 获取所有已缓存的页面 key
    /// - Returns: 所有页面标识符（HTML 或 Manifest）
    public func getAllPageKeys() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        // ✅ FIX: 返回 manifest 的 keys（HTML 可能为空）
        return Array(manifestCache.keys)
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        // 加载 HTML 缓存
        if let htmlData = try? Data(contentsOf: htmlFilePath),
           let htmlDict = try? PropertyListSerialization.propertyList(from: htmlData, options: [], format: nil) as? [String: String] {
            htmlCache = htmlDict
        }

        // 加载 Manifest 缓存
        if let manifestData = try? Data(contentsOf: manifestFilePath),
           let manifestDict = try? PropertyListSerialization.propertyList(from: manifestData, options: [], format: nil) as? [String: [String: Any]] {
            var loaded: [String: Manifest] = [:]

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

                    loaded[key] = manifest
                }
            }

            manifestCache = loaded
        }

        print("✅ [ManifestStore] Loaded from disk: \(htmlCache.count) HTMLs, \(manifestCache.count) manifests")
    }

    /// Schedule async save to avoid holding lock during I/O operations
    private func scheduleAsyncSave() {
        saveQueue.async { [weak self] in
            guard let self = self else { return }

            // Check if save is already pending
            self.lock.lock()
            if self.savePending {
                self.lock.unlock()
                return
            }
            self.savePending = true

            // Copy data under lock (fast operation)
            var htmlCopy: [String: String]?
            var manifestDictCopy: [String: [String: Any]]?

            htmlCopy = self.htmlCache

            manifestDictCopy = [:]
            for (key, manifest) in self.manifestCache {
                var dict: [String: Any] = [
                    "resources": manifest.resources,
                    "appid": manifest.appid ?? "",
                    "name": manifest.name ?? "",
                    "icon": manifest.icon ?? "",
                    "isPinned": manifest.isPinned ?? false,
                    "isFavorite": manifest.isFavorite ?? false,
                    "accessCount": manifest.accessCount ?? 0
                ]
                if let version = manifest.version {
                    dict["version"] = version
                }
                if let lastUpdated = manifest.lastUpdated {
                    dict["lastUpdated"] = lastUpdated.timeIntervalSince1970
                }
                if let lastAccessed = manifest.lastAccessed {
                    dict["lastAccessed"] = lastAccessed.timeIntervalSince1970
                }
                manifestDictCopy?[key] = dict
            }
            self.lock.unlock()

            // Perform I/O without holding lock (slow operation)
            if let htmlData = try? PropertyListSerialization.data(fromPropertyList: htmlCopy ?? [:], format: .xml, options: 0) {
                try? htmlData.write(to: self.htmlFilePath)
            }

            if let manifestData = try? PropertyListSerialization.data(fromPropertyList: manifestDictCopy ?? [:], format: .xml, options: 0) {
                try? manifestData.write(to: self.manifestFilePath)
            }

            // Reset pending flag
            self.lock.lock()
            self.savePending = false
            self.lock.unlock()
        }
    }

    private func saveToDisk() {
        // 保存 HTML 缓存
        if let htmlData = try? PropertyListSerialization.data(fromPropertyList: htmlCache, format: .xml, options: 0) {
            try? htmlData.write(to: htmlFilePath)
        }

        // 保存 Manifest 缓存
        var manifestDict: [String: [String: Any]] = [:]

        for (key, manifest) in manifestCache {
            var dict: [String: Any] = [
                "resources": manifest.resources,
                "appid": manifest.appid ?? "",
                "name": manifest.name ?? "",
                "icon": manifest.icon ?? "",
                "isPinned": manifest.isPinned ?? false,
                "isFavorite": manifest.isFavorite ?? false,
                "accessCount": manifest.accessCount ?? 0
            ]

            if let version = manifest.version {
                dict["version"] = version
            }

            if let lastUpdated = manifest.lastUpdated {
                dict["lastUpdated"] = lastUpdated.timeIntervalSince1970
            }

            if let lastAccessed = manifest.lastAccessed {
                dict["lastAccessed"] = lastAccessed.timeIntervalSince1970
            }

            manifestDict[key] = dict
        }

        if let manifestData = try? PropertyListSerialization.data(fromPropertyList: manifestDict, format: .xml, options: 0) {
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
    private let lock = NSLock()

    private let queue = DispatchQueue(label: "com.webbridgekit.resource-cache", qos: .userInitiated)

    public init() {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        self.diskCacheDirectory = paths[0].appendingPathComponent("ManifestCache/Resources")

        // 创建资源缓存目录
        try? FileManager.default.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)

        print("✅ [ResourceCache] Initialized with disk cache: \(diskCacheDirectory.path)")
    }

    // MARK: - Cache Operations

    public func get(_ relativePath: String, for pageKey: String) -> ResourceData? {
        lock.lock()
        defer { lock.unlock() }

        let key = cacheKey(relativePath, pageKey: pageKey)

        // 先查内存
        if let resource = memoryCache[key] {
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
        queue.async { [weak self] in
            guard let self = self else { return }

            let key = self.cacheKey(resource.relativePath, pageKey: pageKey)
            let diskPath = self.diskCacheDirectory.appendingPathComponent(key)

            do {
                // ✅ FIX: 确保父目录存在（解决 "The file doesn't exist" 错误）
                let parentDirectory = diskPath.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: parentDirectory, withIntermediateDirectories: true, attributes: nil)

                // 1. Write to disk first (no lock needed)
                try resource.data.write(to: diskPath)

                // Save metadata
                let meta: [String: Any] = [
                    "mimeType": resource.mimeType,
                    "cachedAt": Date().timeIntervalSince1970
                ]

                if let metaData = try? JSONSerialization.data(withJSONObject: meta, options: []) {
                    try metaData.write(to: diskPath.appendingPathExtension("meta"))
                }

                // 2. Update memory cache (single lock acquisition)
                self.lock.lock()
                defer { self.lock.unlock() }

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
                    NotificationCenter.default.post(name: NSNotification.Name("ManifestCacheDidUpdate"), object: nil)
                }
            } catch {
                print("❌ [ResourceCache] Failed to cache: \(error.localizedDescription)")
            }
        }
    }

    func removeResources(for pageKey: String) {
        lock.lock()
        defer { lock.unlock() }

        // 移除内存缓存
        var keysToRemove: [String] = []
        for key in memoryCache.keys {
            if key.contains("/\(pageKey)/") {
                keysToRemove.append(key)
            }
        }

        for key in keysToRemove {
            if let resource = memoryCache.removeValue(forKey: key) {
                currentMemorySize -= Int64(resource.data.count)
            }
        }

        // 移除磁盘缓存
        if let enumerator = FileManager.default.enumerator(at: diskCacheDirectory, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                let filename = fileURL.lastPathComponent
                if filename.contains("/\(pageKey)/") {
                    try? FileManager.default.removeItem(at: fileURL)
                }
            }
        }
    }

    func removeAll() {
        lock.lock()
        defer { lock.unlock() }

        memoryCache.removeAll()
        currentMemorySize = 0

        // 清空磁盘目录
        if let enumerator = FileManager.default.enumerator(at: diskCacheDirectory, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }

    /// 移除指定 pageKey 的所有缓存
    /// - Parameter pageKey: 页面标识符
    func removeAll(for pageKey: String) {
        lock.lock()
        defer { lock.unlock() }

        let pageKeyPrefix = "\(pageKey)/"

        // 从内存缓存中删除
        var keysToRemove: [String] = []
        for key in memoryCache.keys {
            if key.hasPrefix(pageKeyPrefix) {
                keysToRemove.append(key)
            }
        }
        for key in keysToRemove {
            if let resource = memoryCache.removeValue(forKey: key) {
                currentMemorySize -= Int64(resource.data.count)
            }
        }

        // 从磁盘缓存中删除
        if let enumerator = FileManager.default.enumerator(at: diskCacheDirectory, includingPropertiesForKeys: nil) {
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
