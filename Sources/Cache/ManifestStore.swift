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
    struct CacheEntry {
        let html: String
        let timestamp: Date

        var isExpired: Bool {
            let expirationDays = 7
            let expirationInterval = TimeInterval(expirationDays * 24 * 60 * 60)
            return Date().timeIntervalSince(timestamp) > expirationInterval
        }
    }

    /// Manifest 缓存条目（带时间戳）
    struct ManifestCacheEntry {
        let manifest: Manifest
        let timestamp: Date

        var isExpired: Bool {
            let expirationDays = 7
            let expirationInterval = TimeInterval(expirationDays * 24 * 60 * 60)
            return Date().timeIntervalSince(timestamp) > expirationInterval
        }
    }

    var htmlCache: [String: CacheEntry] = [:]
    var manifestCache: [String: ManifestCacheEntry] = [:]
    var currentManifests: [String: Manifest] = [:]

    /// Serial queue for thread-safe access to shared state
    let serialQueue = DispatchQueue(label: "com.webbridgekit.manifest-store", qos: .userInitiated)
    let htmlFilePath: URL
    let manifestFilePath: URL

    // Async save mechanism
    var savePending = false

    public init() {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let cacheDir = paths[0].appendingPathComponent("ManifestCache")

        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        self.htmlFilePath = cacheDir.appendingPathComponent("html_cache.plist")
        self.manifestFilePath = cacheDir.appendingPathComponent("manifest_cache.plist")

        loadFromDiskSync()

        Log.info("Initialized with \(manifestCache.count) manifests, \(htmlCache.count) htmls", category: .manifest)
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

            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .manifestCacheDidUpdate, object: nil)
            }
        }
    }

    public func saveManifestSync(_ manifest: Manifest, for key: String) {
        var updatedManifest = manifest
        updatedManifest.version = updatedManifest.version ?? UUID().uuidString
        updatedManifest.lastUpdated = Date()
        manifestCache[key] = ManifestCacheEntry(manifest: updatedManifest, timestamp: Date())
    }

    public func saveHTMLSync(_ html: String, for key: String) {
        htmlCache[key] = CacheEntry(html: html, timestamp: Date())
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
}

// MARK: - ResourceCache

/// 资源缓存（内存 + 磁盘）
public class ResourceCache {

    public static let shared = ResourceCache()

    private var memoryCache: [String: ResourceData] = [:]
    private let memoryCapacity = 100 * 1024 * 1024  // 100 MB
    private var currentMemorySize: Int64 = 0

    private let diskCacheDirectory: URL

    /// Using serialQueue for thread-safe operations
    private let serialQueue = DispatchQueue(label: "com.webbridgekit.resource-cache", qos: .userInitiated)

    public init() {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        self.diskCacheDirectory = paths[0].appendingPathComponent("ManifestCache/Resources")

        try? FileManager.default.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)

        print("✅ [ResourceCache] Initialized with disk cache: \(diskCacheDirectory.path)")
    }

    // MARK: - Cache Operations

    public func get(_ relativePath: String, for pageKey: String) -> ResourceData? {
        let key = cacheKey(relativePath, pageKey: pageKey)

        let cachedResource = serialQueue.sync {
            return memoryCache[key]
        }

        if let resource = cachedResource {
            return resource
        }

        let diskPath = diskCacheDirectory.appendingPathComponent(key)
        guard let data = try? Data(contentsOf: diskPath) else {
            return nil
        }

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
                let parentDirectory = diskPath.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: parentDirectory, withIntermediateDirectories: true, attributes: nil)

                try resource.data.write(to: diskPath)

                let meta: [String: Any] = [
                    "mimeType": resource.mimeType,
                    "cachedAt": Date().timeIntervalSince1970
                ]

                if let metaData = try? JSONSerialization.data(withJSONObject: meta, options: []) {
                    try metaData.write(to: diskPath.appendingPathExtension("meta"))
                }

                let resourceSize = Int64(resource.data.count)

                while self.currentMemorySize + resourceSize > self.memoryCapacity && !self.memoryCache.isEmpty {
                    if let firstKey = self.memoryCache.keys.first,
                       let firstResource = self.memoryCache.removeValue(forKey: firstKey) {
                        self.currentMemorySize -= Int64(firstResource.data.count)
                    }
                }

                self.memoryCache[key] = resource
                self.currentMemorySize += resourceSize

                print("✅ [ResourceCache] Cached: \(resource.relativePath) (\(resource.data.count) bytes)")

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

            var keysToRemove: [String] = []
            for key in self.memoryCache.keys where key.contains("/\(pageKey)/") {
                keysToRemove.append(key)
            }

            for key in keysToRemove {
                if let resource = self.memoryCache.removeValue(forKey: key) {
                    self.currentMemorySize -= Int64(resource.data.count)
                }
            }

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

            if let enumerator = FileManager.default.enumerator(at: self.diskCacheDirectory, includingPropertiesForKeys: nil) {
                for case let fileURL as URL in enumerator {
                    try? FileManager.default.removeItem(at: fileURL)
                }
            }
        }
    }

    func removeAll(for pageKey: String) {
        serialQueue.async { [weak self] in
            guard let self = self else { return }

            let pageKeyPrefix = "\(pageKey)/"

            var keysToRemove: [String] = []
            for key in self.memoryCache.keys where key.hasPrefix(pageKeyPrefix) {
                keysToRemove.append(key)
            }
            for key in keysToRemove {
                if let resource = self.memoryCache.removeValue(forKey: key) {
                    self.currentMemorySize -= Int64(resource.data.count)
                }
            }

            if let enumerator = FileManager.default.enumerator(at: self.diskCacheDirectory, includingPropertiesForKeys: nil) {
                for case let fileURL as URL in enumerator {
                    let fileName = fileURL.lastPathComponent
                    if fileName.hasPrefix(pageKeyPrefix) {
                        try? FileManager.default.removeItem(at: fileURL)
                    }
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
        return "\(pageKey)/\(relativePath)"
    }
}
