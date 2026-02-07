//
//  WebPageCacheHandler.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-31.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import UIKit
import WebKit

// Framework imports

/// 页面缓存管理器
/// 负责预加载和缓存 HTML 页面内容
public class PageCacheManager {

    // MARK: - Singleton

    public static let shared = PageCacheManager()

    private init() {}

    // MARK: - Cached Page

    /// 缓存的页面信息
    /// 注意：仅缓存 HTML 内容，不保留 WebView 实例
    /// 这样可以避免 JS 在后台继续运行，节省性能
    public struct CachedPage {
        public let pageName: String
        public let html: String
        public let baseURL: URL?
        public let cachedAt: Date
        public var hitCount: Int

        /// ⚠️ 重要：我们不保存 WebView 实例
        /// 当页面不可见时，WebView 会被销毁，JS 停止运行
        /// 只有当页面再次显示时，才会用缓存的 HTML 重新创建

        public init(pageName: String, html: String, baseURL: URL?) {
            self.pageName = pageName
            self.html = html
            self.baseURL = baseURL
            self.cachedAt = Date()
            self.hitCount = 0
        }

        /// 预估的内存占用（KB）
        public var estimatedSizeKB: Int {
            return html.utf8.count / 1024
        }
    }

    // MARK: - Properties

    /// 页面缓存
    private var pageCache: [String: CachedPage] = [:]

    /// 缓存最大数量
    private let maxCacheSize = 10

    /// 线程安全锁
    private let lock = NSLock()

    /// 预加载队列
    private let preloadQueue = DispatchQueue(label: "com.webbridgekit.pagecache", qos: .userInitiated)

    // MARK: - Public Methods

    /// 预加载页面
    /// - Parameters:
    ///   - pageName: 页面名称
    ///   - completion: 完成回调
    public func preloadPage(named pageName: String, completion: @escaping (Bool) -> Void) {
        // 检查是否已缓存
        if isCached(pageName: pageName) {
            WebBridgeLogger.shared.log(.info, "✅ [PageCache] Page '\(pageName)' already cached")
            completion(true)
            return
        }

        preloadQueue.async { [weak self] in
            guard let self = self else {
                completion(false)
                return
            }

            // 加载 HTML 内容
            guard let html = self.loadHTMLContent(for: pageName) else {
                WebBridgeLogger.shared.log(.error, "❌ [PageCache] Failed to load HTML for '\(pageName)'")
                completion(false)
                return
            }

            // 缓存页面
            let baseURL = self.getBaseURL()
            let cachedPage = CachedPage(pageName: pageName, html: html, baseURL: baseURL)

            self.lock.lock()
            // 使用 LRU 策略
            if self.pageCache.count >= self.maxCacheSize {
                self.evictLeastRecentlyUsed()
            }
            self.pageCache[pageName] = cachedPage
            self.lock.unlock()

            WebBridgeLogger.shared.log(.info, "✅ [PageCache] Preloaded page '\(pageName)' (cache size: \(self.pageCache.count))")
            completion(true)
        }
    }

    /// 获取缓存的页面
    /// - Parameter pageName: 页面名称
    /// - Returns: 缓存的页面，如果不存在则返回 nil
    public func getCachedPage(named pageName: String) -> CachedPage? {
        lock.lock()
        defer { lock.unlock() }

        guard var page = pageCache[pageName] else {
            return nil
        }

        // 更新命中次数
        page.hitCount += 1
        pageCache[pageName] = page

        WebBridgeLogger.shared.log(.info, "♻️ [PageCache] Cache hit for '\(pageName)' (hits: \(page.hitCount))")
        return page
    }

    /// 检查页面是否已缓存
    /// - Parameter pageName: 页面名称
    /// - Returns: 是否已缓存
    public func isCached(pageName: String) -> Bool {
        lock.lock()
        let cached = pageCache[pageName] != nil
        lock.unlock()
        return cached
    }

    /// 清除所有缓存
    public func clearCache() {
        lock.lock()
        let count = pageCache.count
        pageCache.removeAll()
        lock.unlock()

        WebBridgeLogger.shared.log(.info, "🧹 [PageCache] Cleared \(count) cached pages")
    }

    /// 获取缓存信息
    /// - Returns: 缓存信息字典
    public func getCacheInfo() -> [String: Any] {
        lock.lock()
        let info: [String: Any] = [
            "cacheSize": pageCache.count,
            "maxCacheSize": maxCacheSize,
            "cachedPages": pageCache.keys.sorted()
        ]
        lock.unlock()
        return info
    }

    // MARK: - Private Methods

    /// 加载 HTML 内容
    private func loadHTMLContent(for pageName: String) -> String? {
        // 首先尝试从 test_resources 加载
        if let html = loadFromTestResources(pageName: pageName) {
            return html
        }

        // 然后尝试从 Bundle 加载
        if let html = loadFromBundle(pageName: pageName) {
            return html
        }

        // 最后尝试从 HTTP 服务器加载
        return loadFromHTTPServer(pageName: pageName)
    }

    /// 从 test_resources 加载
    private func loadFromTestResources(pageName: String) -> String? {
        // 检查测试服务器是否运行
        guard isTestServerRunning() else {
            return nil
        }

        // 构建测试资源 URL
        let urlString = "http://localhost:8080/\(pageName).html"
        guard let url = URL(string: urlString) else {
            return nil
        }

        do {
            let html = try String(contentsOf: url, encoding: .utf8)
            WebBridgeLogger.shared.log(.info, "📥 [PageCache] Loaded from test_resources: \(pageName)")
            return html
        } catch {
            WebBridgeLogger.shared.log(.error, "❌ [PageCache] Failed to load from test_resources: \(error)")
            return nil
        }
    }

    /// 从 Bundle 加载
    private func loadFromBundle(pageName: String) -> String? {
        guard let path = Bundle.main.path(forResource: pageName, ofType: "html") else {
            return nil
        }

        do {
            let html = try String(contentsOfFile: path, encoding: .utf8)
            WebBridgeLogger.shared.log(.info, "📦 [PageCache] Loaded from bundle: \(pageName)")
            return html
        } catch {
            WebBridgeLogger.shared.log(.error, "❌ [PageCache] Failed to load from bundle: \(error)")
            return nil
        }
    }

    /// 从 HTTP 服务器加载
    private func loadFromHTTPServer(pageName: String) -> String? {
        // 这里可以扩展为从配置的 HTTP 服务器加载
        return nil
    }

    /// 获取 Base URL
    private func getBaseURL() -> URL? {
        // 优先返回测试服务器 URL
        if isTestServerRunning() {
            return URL(string: "http://localhost:8080/")
        }

        // 否则返回 Bundle URL
        return Bundle.main.bundleURL
    }

    /// 检查测试服务器是否运行
    private func isTestServerRunning() -> Bool {
        // 简单的检查：尝试连接到 localhost:8080
        let semaphore = DispatchSemaphore(value: 0)
        var isRunning = false

        DispatchQueue.global().async {
            if let url = URL(string: "http://localhost:8080/") {
                var request = URLRequest(url: url)
                request.timeoutInterval = 0.5
                let task = URLSession.shared.dataTask(with: request) { _, response, _ in
                    isRunning = (response as? HTTPURLResponse)?.statusCode == 200
                    semaphore.signal()
                }
                task.resume()
            } else {
                semaphore.signal()
            }
        }

        _ = semaphore.wait(timeout: .now() + 1.0)
        return isRunning
    }

    /// LRU 淘汰策略
    private func evictLeastRecentlyUsed() {
        // 按命中次数和缓存时间排序，移除最少使用的页面
        let sortedPages = pageCache.sorted { element1, element2 in
            let page1 = element1.value
            let page2 = element2.value

            // 先比较命中次数
            if page1.hitCount != page2.hitCount {
                return page1.hitCount < page2.hitCount
            }

            // 命中次数相同，比较缓存时间
            return page1.cachedAt < page2.cachedAt
        }

        if let leastUsed = sortedPages.first {
            pageCache.removeValue(forKey: leastUsed.key)
            WebBridgeLogger.shared.log(.info, "🗑️ [PageCache] Evicted LRU page: \(leastUsed.key)")
        }
    }
}

/// 页面缓存 Handler
public class WebPageCacheHandler: BaseWebNativeHandler {

    public override func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
        let params = body["params"] as? [String: Any] ?? body
        let action = params["action"] as? String ?? ""

        WebBridgeLogger.shared.log(.info, "[WebPageCacheHandler] Handling action: \(action)")

        switch action {
        case "preload":
            guard let pageName = params["page"] as? String else {
                reject(error: "Missing parameter: page", completion: completion)
                return
            }
            preloadPage(pageName: pageName, completion: completion)

        case "isCached":
            guard let pageName = params["page"] as? String else {
                reject(error: "Missing parameter: page", completion: completion)
                return
            }
            checkCached(pageName: pageName, completion: completion)

        case "clearCache":
            clearCache(completion: completion)

        case "getCacheInfo":
            getCacheInfo(completion: completion)

        default:
            reject(error: "Unsupported action: \(action)", code: 404, completion: completion)
        }
    }

    // MARK: - Actions

    private func preloadPage(pageName: String, completion: @escaping (Any) -> Void) {
        PageCacheManager.shared.preloadPage(named: pageName) { success in
            if success {
                self.resolve([
                    "success": true,
                    "page": pageName,
                    "cached": true
                ], completion: completion)
            } else {
                self.reject(error: "Failed to preload page: \(pageName)", completion: completion)
            }
        }
    }

    private func checkCached(pageName: String, completion: @escaping (Any) -> Void) {
        let isCached = PageCacheManager.shared.isCached(pageName: pageName)
        resolve([
            "page": pageName,
            "cached": isCached
        ], completion: completion)
    }

    private func clearCache(completion: @escaping (Any) -> Void) {
        PageCacheManager.shared.clearCache()
        resolve([
            "success": true,
            "cacheSize": 0
        ], completion: completion)
    }

    private func getCacheInfo(completion: @escaping (Any) -> Void) {
        let info = PageCacheManager.shared.getCacheInfo()
        resolve(info, completion: completion)
    }
}
