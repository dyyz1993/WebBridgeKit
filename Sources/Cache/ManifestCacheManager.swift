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
public class ManifestCacheManager {

    public static let shared = ManifestCacheManager()

    /// 缓存命中通知
    public static let cacheHitNotification = Notification.Name("com.webbridgekit.manifest-cache.hit")

    // MARK: - Properties

    private let scheme = "custom"
    private let manifestStore: ManifestStore
    private let resourceCache: ResourceCache
    private let queue = DispatchQueue(label: "com.webbridgekit.manifest-cache", qos: .userInitiated)

    // 缓存统计
    private var cacheHits: Int64 = 0
    private var cacheMisses: Int64 = 0
    private let statsLock = NSLock()

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

    /// 处理资源请求（由 URLSchemeHandler 调用，带错误处理和重试）
    /// - Parameters:
    ///   - relativePath: 相对路径（如 "logo.png"）
    ///   - pageKey: 当前页面标识符
    ///   - completion: 完成回调，返回资源数据
    public func fetchResource(relativePath: String, for pageKey: String, completion: @escaping (Result<ResourceData, Error>) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                completion(.failure(ManifestCacheError.managerDeallocated))
                return
            }

            // 提取文件名用于日志显示
            let fileName = (relativePath as NSString).lastPathComponent

            // 1. 检查资源缓存
            NSLog("⬇️ [\(fileName)] 检查缓存...")

            if let cached = self.resourceCache.get(relativePath, for: pageKey) {
                self.recordCacheHit()
                NSLog("✅ [\(fileName)] 缓存命中 (大小: \(cached.data.count) bytes)")

                // 发送通知，用于 UI 显示
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: ManifestCacheManager.cacheHitNotification,
                        object: nil,
                        userInfo: ["relativePath": relativePath, "source": "INTERCEPT"]
                    )
                }

                completion(.success(cached))
                return
            }

            self.recordCacheMiss()
            NSLog("❌ [\(fileName)] 缓存未命中，开始下载...")

            // 2. 从 manifest 查找真实 URL
            guard let manifest = self.manifestStore.getCurrentManifest(for: pageKey),
                  let urlString = manifest.resources[relativePath],
                  let url = URL(string: urlString) else {
                NSLog("❌ [\(fileName)] Manifest 中未找到该资源")
                completion(.failure(ManifestCacheError.resourceNotFound(relativePath)))
                return
            }

            // 3. 下载资源（带重试机制）
            NSLog("📥 [\(fileName)] 正在下载...")

            Task {
                do {
                    let resource = try await RetryHelper.executeAsync(maxRetries: 3, delay: 1.0) {
                        try await self.downloadResource(from: url, relativePath: relativePath)
                    }

                    // 4. 缓存资源
                    self.resourceCache.set(resource, for: pageKey)

                    NSLog("✅ [\(fileName)] 下载成功 (大小: \(resource.data.count) bytes)")
                    NSLog("💾 [\(fileName)] 已缓存")
                    completion(.success(resource))
                } catch {
                    NSLog("❌ [\(fileName)] 下载失败: \(error.localizedDescription)")
                    completion(.failure(WebBridgeError.networkRequestFailed(reason: error.localizedDescription)))
                }
            }
        }
    }

    /// 下载单个资源（异步）
    private func downloadResource(from url: URL, relativePath: String) async throws -> ResourceData {
        return try await PerformanceMonitor.shared.measure(
            "ManifestCache.downloadResource",
            metadata: ["relativePath": relativePath, "url": url.absoluteString]
        ) {
            // 使用 RequestDeduplicator 防止重复下载
            let result: Any = try await RequestDeduplicator.shared.executeResourceDownload(
                urlString: url.absoluteString,
                relativePath: relativePath
            ) {
                // 检查网络状态（快速失败，避免10秒超时等待）
                try NetworkMonitor.shared.ensureNetworkAvailable()

                // 检查是否为蜂窝网络并发出警告
                if NetworkMonitor.shared.warnIfCellular() {
                    let fileName = (relativePath as NSString).lastPathComponent
                    WebBridgeLogger.shared.log(.warning, "⚠️ [ManifestCache] Downloading '\(fileName)' over cellular network - data charges may apply")
                }

                return try await self.performDownload(from: url, relativePath: relativePath)
            }

            guard let resource = result as? ResourceData else {
                throw WebBridgeError.cacheLoadFailed(
                    reason: "Type mismatch in resource download result for: \(relativePath)"
                )
            }

            return resource
        }
    }

    /// 执行实际的下载操作（不包含去重逻辑）
    private func performDownload(from url: URL, relativePath: String) async throws -> ResourceData {
        return try await PerformanceMonitor.shared.measure(
            "ManifestCache.performDownload",
            metadata: ["relativePath": relativePath, "url": url.absoluteString]
        ) {
            try await withCheckedThrowingContinuation { continuation in
                let task = URLSession.shared.dataTask(with: url) { data, _, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let data = data, !data.isEmpty else {
                        Log.error("Downloaded empty data for resource: \(relativePath)", category: .network)
                        continuation.resume(throwing: ManifestCacheError.emptyData)
                        return
                    }

                    let mimeType = self.getMimeType(forPath: relativePath)
                    let resource = ResourceData(
                        relativePath: relativePath,
                        data: data,
                        mimeType: mimeType
                    )

                    continuation.resume(returning: resource)
                }

                task.resume()
            }
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

    // MARK: - Private Helpers

    private func recordCacheHit() {
        statsLock.lock()
        defer { statsLock.unlock() }
        cacheHits += 1
    }

    private func recordCacheMiss() {
        statsLock.lock()
        defer { statsLock.unlock() }
        cacheMisses += 1
    }

    private func resetStats() {
        statsLock.lock()
        defer { statsLock.unlock() }
        cacheHits = 0
        cacheMisses = 0
    }

    private func getMimeType(forPath path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()

        switch ext {
        case "html", "htm":
            return "text/html; charset=utf-8"
        case "css":
            return "text/css; charset=utf-8"
        case "js":
            return "application/javascript; charset=utf-8"
        case "json":
            return "application/json; charset=utf-8"
        case "png":
            return "image/png"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "gif":
            return "image/gif"
        case "svg":
            return "image/svg+xml"
        case "webp":
            return "image/webp"
        case "ico":
            return "image/x-icon"
        case "woff", "woff2":
            return "font/woff2"
        case "ttf":
            return "font/ttf"
        case "mp4":
            return "video/mp4"
        case "webm":
            return "video/webm"
        case "mp3":
            return "audio/mpeg"
        default:
            return "application/octet-stream"
        }
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
