//
//  ManifestCacheManager.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-02-02.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import WebKit

/// Manifest 缓存管理器
/// 使用 loadHTMLString + baseURL + 自定义 URL Scheme 实现
/// 核心思想：
/// 1. HTML 使用相对路径 (src="logo.png")
/// 2. baseURL = "custom://" 使相对路径补全为 "custom://logo.png"
/// 3. WKURLSchemeHandler 拦截 custom:// 请求
/// 4. 从 manifest.json 查找相对路径对应的真实 URL
public class ManifestCacheManager: @unchecked Sendable {

    public static let shared = ManifestCacheManager()

    /// 缓存命中通知
    public static let cacheHitNotification = Notification.Name("com.webbridgekit.manifest-cache.hit")

    // MARK: - Properties

    private let scheme = "custom"
    let manifestStore: ManifestStore
    let resourceCache: ResourceCache
    let queue = DispatchQueue(label: "com.webbridgekit.manifest-cache", qos: .userInitiated)

    var cacheHits: Int64 = 0
    var cacheMisses: Int64 = 0
    let statsLock = NSLock()

    // MARK: - Initialization

    private init() {
        self.manifestStore = ManifestStore.shared
        self.resourceCache = ResourceCache.shared
        NSLog("✅ [ManifestCache] Initialized with URL scheme: \(scheme)://")
    }

    /// 计算当前总缓存大小（字节）
    public func calculateTotalCacheSize() -> Int64 {
        return resourceCache.totalSize()
    }

    /// 获取资源缓存单例
    public func getResourceCache() -> ResourceCache {
        return resourceCache
    }

    /// 加载带有相对路径的 HTML
    /// - Parameters:
    ///   - htmlString: HTML 字符串（包含相对路径的资源引用）
    ///   - webView: 目标 WebView
    public func loadHTML(_ htmlString: String, into webView: WKWebView) {
        queue.async { [weak self] in
            guard let self = self else { return }

            // 构建 baseURL：相对路径会基于此补全为 custom://
            let baseURL = URL(string: "\(self.scheme)://")

            // ⚠️ WebView 操作必须在主线程执行
            DispatchQueue.main.async {
                webView.loadHTMLString(htmlString, baseURL: baseURL)
            }

            NSLog("✅ [ManifestCache] Loaded HTML with baseURL: \(self.scheme)://")
            NSLog("   - 相对路径会自动补全为: \(self.scheme)://[相对路径]")
        }
    }

    /// 加载缓存的页面（带错误处理）
    /// - Parameters:
    ///   - pageKey: 页面标识符
    ///   - webView: 目标 WebView
    ///   - completion: 完成回调，返回 Result
    public func loadPage(pageKey: String, into webView: WKWebView, completion: ((Result<Void, Error>) -> Void)? = nil) {
        queue.async { [weak self] in
            guard let self = self else { return }

            do {
                // 从缓存获取 HTML
                guard let html = self.manifestStore.getHTML(for: pageKey) else {
                    let error = WebBridgeError.cacheLoadFailed(reason: "Page not found: \(pageKey)")
                    NSLog("❌ [ManifestCache] \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        completion?(.failure(error))
                    }
                    return
                }

                // 获取或创建 manifest
                let manifest = self.manifestStore.getManifest(for: pageKey) ?? Manifest()

                // 设置当前页面的 manifest
                self.manifestStore.setCurrentManifest(manifest, for: pageKey)

                // ⚠️ WebView 操作必须在主线程执行
                DispatchQueue.main.async {
                    webView.loadHTMLString(html, baseURL: URL(string: "\(self.scheme)://"))

                    // 发送通知，用于 UI 显示
                    NotificationCenter.default.post(
                        name: .manifestCacheHit,
                        object: nil,
                        userInfo: ["pageKey": pageKey, "source": "HTML"]
                    )

                    completion?(.success(()))
                }

                NSLog("✅ [ManifestCache] Loaded page: \(pageKey)")
                NSLog("   - Manifest entries: \(manifest.resources.count)")
            } catch {
                let bridgeError = WebBridgeError.cacheLoadFailed(reason: error.localizedDescription)
                NSLog("❌ [ManifestCache] Failed to load page: \(bridgeError.localizedDescription)")
                DispatchQueue.main.async {
                    completion?(.failure(bridgeError))
                }
            }
        }
    }

    /// 保存页面及其 manifest（带错误处理和重试）
    /// - Parameters:
    ///   - pageKey: 页面标识符
    ///   - html: HTML 内容
    ///   - manifest: 资源映射清单
    ///   - completion: 完成回调，返回 Result
    public func savePage(pageKey: String, html: String, manifest: Manifest, completion: ((Result<Void, Error>) -> Void)? = nil) {
        queue.async { [weak self] in
            guard let self = self else { return }

            // 使用重试机制保存数据
            Task {
                do {
                    try await RetryHelper.execute(maxRetries: 3, delay: 0.5) {
                        // 保存 HTML
                        self.manifestStore.saveHTML(html, for: pageKey)

                        // 保存 manifest
                        self.manifestStore.saveManifest(manifest, for: pageKey)

                        NSLog("✅ [ManifestCache] Saved page: \(pageKey)")
                        NSLog("   - HTML length: \(html.count) chars")
                        NSLog("   - Manifest entries: \(manifest.resources.count)")
                    }

                    // 发送缓存更新通知（在主线程）
                    await MainActor.run {
                        NotificationCenter.default.post(
                            name: .manifestCacheDidUpdate,
                            object: nil
                        )
                        completion?(.success(()))
                    }
                } catch {
                    NSLog("❌ [ManifestCache] Failed to save page after retries: \(error.localizedDescription)")
                    await MainActor.run {
                        completion?(.failure(WebBridgeError.cacheSaveFailed(underlying: error)))
                    }
                }
            }
        }
    }

    /// 获取缓存的 HTML
    /// - Parameter pageKey: 页面标识符
    /// - Returns: 缓存的 HTML 内容，如果不存在则返回 nil
    public func getCachedHTML(for pageKey: String) -> String? {
        return manifestStore.getHTML(for: pageKey)
    }

    /// 获取缓存的 Manifest
    /// - Parameter pageKey: 页面标识符
    /// - Returns: 缓存的 Manifest，如果不存在则返回 nil
    public func getCachedManifest(for pageKey: String) -> Manifest? {
        return manifestStore.getManifest(for: pageKey)
    }

    /// 移除指定页面的缓存
    /// - Parameter pageKey: 页面标识符
    public func removeCache(for pageKey: String) {
        queue.async { [weak self] in
            guard let self = self else { return }

            self.manifestStore.removeHTML(for: pageKey)
            self.resourceCache.removeAll(for: pageKey)

            NSLog("🗑️ [ManifestCache] Removed cache for: \(pageKey)")
        }
    }

    /// 按 AppID 清除缓存
    /// - Parameters:
    ///   - appid: 应用标识符
    ///   - completion: 完成回调（在主线程执行）
    /// - Discussion: 清除指定 AppID 的所有缓存（包括所有使用该 AppID 的页面）
    public func removeCacheByAppID(_ appid: String, completion: (() -> Void)? = nil) {
        queue.async { [weak self] in
            guard let self = self else { return }

            // 1. 获取所有已缓存的页面 key
            let allPageKeys = self.manifestStore.getAllPageKeys()

            // 2. 筛选出属于该 AppID 的页面（通过读取 manifest 的 appid 字段）
            let sanitizedAppID = AppIDResolver.validateAndSanitizeAppID(appid)
            let matchingKeys = allPageKeys.filter { pageKey in
                if let manifest = self.manifestStore.getManifest(for: pageKey),
                   let manifestAppID = manifest.appid {
                    let sanitizedManifestAppID = AppIDResolver.validateAndSanitizeAppID(manifestAppID)
                    return sanitizedManifestAppID == sanitizedAppID
                }
                return false
            }

            // 3. 清除匹配的缓存
            for pageKey in matchingKeys {
                self.manifestStore.removeHTML(for: pageKey)
                self.manifestStore.removeManifest(for: pageKey)
                self.resourceCache.removeAll(for: pageKey)

                // ✅ 同时清理 PersistentManifestLoader 的物理缓存
                let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                let persistentDir = cachesDir.appendingPathComponent("WebBridgeKit/PersistentCache").appendingPathComponent(pageKey)
                if FileManager.default.fileExists(atPath: persistentDir.path) {
                    do {
                        try FileManager.default.removeItem(at: persistentDir)
                        NSLog("🗑️ [ManifestCache] Removed persistent cache directory for: \(pageKey)")
                    } catch {
                        Log.error("Failed to remove persistent cache directory for \(pageKey): \(error.localizedDescription)", category: .cache)
                        NSLog("❌ [ManifestCache] Failed to remove persistent cache directory for: \(pageKey) - \(error.localizedDescription)")
                    }
                }
            }

            NSLog("🗑️ [ManifestCache] Removed \(matchingKeys.count) caches for AppID: \(appid)")

            // 完成后在主线程回调和发送通知
            DispatchQueue.main.async {
                if let completion = completion {
                    completion()
                }
                // 发送缓存更新通知
                NotificationCenter.default.post(
                    name: .manifestCacheDidUpdate,
                    object: nil
                )
            }
        }
    }

    /// 批量清除缓存（按 AppID 列表）
    /// - Parameter appids: 应用标识符列表
    public func removeCacheByAppIDs(_ appids: [String]) {
        for appid in appids {
            removeCacheByAppID(appid)
        }
    }

    /// 更新 manifest 的资源映射
    /// - Parameters:
    ///   - pageKey: 页面标识符
    ///   - relativePath: 相对路径
    ///   - url: 真实的网络 URL
    public func updateMapping(for pageKey: String, relativePath: String, url: String) {
        queue.async { [weak self] in
            guard let self = self else { return }

            var manifest = self.manifestStore.getManifest(for: pageKey) ?? Manifest()
            manifest.resources[relativePath] = url
            self.manifestStore.saveManifest(manifest, for: pageKey)

            NSLog("✅ [ManifestCache] Updated mapping: \(relativePath) -> \(url)")
        }
    }

    /// 批量更新 manifest
    /// - Parameters:
    ///   - pageKey: 页面标识符
    ///   - mappings: 相对路径到 URL 的映射字典
    public func updateMappings(for pageKey: String, mappings: [String: String]) {
        queue.async { [weak self] in
            guard let self = self else { return }

            var manifest = self.manifestStore.getManifest(for: pageKey) ?? Manifest()

            for (relativePath, url) in mappings {
                manifest.resources[relativePath] = url
            }

            self.manifestStore.saveManifest(manifest, for: pageKey)

            NSLog("✅ [ManifestCache] Updated \(mappings.count) mappings for: \(pageKey)")
        }
    }

    /// 清除页面缓存
    /// - Parameter pageKey: 页面标识符
    public func clearPage(pageKey: String) {
        queue.async { [weak self] in
            guard let self = self else { return }

            self.manifestStore.removeHTML(for: pageKey)
            self.manifestStore.removeManifest(for: pageKey)
            self.resourceCache.removeResources(for: pageKey)

            NSLog("🗑️ [ManifestCache] Cleared page: \(pageKey)")
        }
    }

    /// 清除所有缓存
    /// - Parameter completion: 完成回调（在主线程执行）
    public func clearAll(completion: (() -> Void)? = nil) {
        queue.async { [weak self] in
            guard let self = self else { return }

            self.manifestStore.clearAll()
            self.resourceCache.removeAll()
            self.resetStats()

            // ✅ 清理所有持久化物理缓存
            let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            let persistentRootDir = cachesDir.appendingPathComponent("WebBridgeKit/PersistentCache")
            if FileManager.default.fileExists(atPath: persistentRootDir.path) {
                do {
                    try FileManager.default.removeItem(at: persistentRootDir)
                    NSLog("🗑️ [ManifestCache] Cleared all persistent cache directories")
                } catch {
                    Log.error("Failed to clear persistent cache directory: \(error.localizedDescription)", category: .cache)
                    NSLog("❌ [ManifestCache] Failed to clear persistent cache directory: \(error.localizedDescription)")
                }

                // Recreate the directory for future use
                do {
                    try FileManager.default.createDirectory(at: persistentRootDir, withIntermediateDirectories: true)
                } catch {
                    Log.error("Failed to recreate persistent cache directory: \(error.localizedDescription)", category: .cache)
                    NSLog("❌ [ManifestCache] Failed to recreate persistent cache directory: \(error.localizedDescription)")
                }
            }

            NSLog("🗑️ [ManifestCache] Cleared all cache")

            // 完成后在主线程回调和发送通知
            DispatchQueue.main.async {
                if let completion = completion {
                    completion()
                }
                // 发送缓存更新通知
                NotificationCenter.default.post(
                    name: .manifestCacheDidUpdate,
                    object: nil
                )
            }
        }
    }

    /// 获取缓存统计
    /// - Returns: 统计信息
    public func getStats() -> CacheStats {
        statsLock.lock()
        defer { statsLock.unlock() }

        let total = cacheHits + cacheMisses
        _ = total > 0 ? Double(cacheHits) / Double(total) : 0.0

        return CacheStats(
            totalRequests: Int(total),
            cacheHits: Int(cacheHits),
            cacheMisses: Int(cacheMisses),
            totalCacheSize: resourceCache.totalSize()
        )
    }

    // MARK: - Manifest Registration (for ManifestURLSchemeHandler)

    /// 注册 Manifest（由 ManifestURLSchemeHandler 调用）
    /// - Parameters:
    ///   - manifest: Manifest 对象
    ///   - pageName: 页面名称
    public func registerManifest(_ manifest: Manifest, forPage pageName: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.manifestStore.saveManifest(manifest, for: pageName)
            NSLog("✅ [ManifestCache] Registered manifest for page: \(pageName)")
        }
    }

    /// 注销 Manifest
    /// - Parameter pageName: 页面名称
    public func unregisterManifest(forPage pageName: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.manifestStore.removeManifest(for: pageName)
            NSLog("🗑️ [ManifestCache] Unregistered manifest for page: \(pageName)")
        }
    }

    /// 缓存资源（供 LazyManifestLoader 使用）
    /// - Parameters:
    ///   - resource: 资源数据
    ///   - pageKey: 页面标识符
    public func cacheResource(_ resource: ResourceData, for pageKey: String) {
        resourceCache.set(resource, for: pageKey)
    }

    /// 检查资源是否已缓存（供 LazyManifestLoader 使用）
    /// - Parameters:
    ///   - relativePath: 相对路径
    ///   - pageKey: 页面标识符
    /// - Returns: 资源数据（如果已缓存），否则返回 nil
    public func getCachedResource(relativePath: String, for pageKey: String) -> ResourceData? {
        return resourceCache.get(relativePath, for: pageKey)
    }
}

// Note: Manifest, ResourceData, CacheStats, and ManifestCacheError
// are now defined in ManifestModels.swift to avoid duplication
