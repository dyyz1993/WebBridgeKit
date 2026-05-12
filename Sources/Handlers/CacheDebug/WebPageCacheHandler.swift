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

    var pageCache: [String: CachedPage] = [:]

    let maxCacheSize = 10

    let maxMemorySizeMB: Int = 50

    var currentMemoryUsageMB: Int = 0

    let lock = NSLock()

    let urlSession: URLSession

    /// 请求超时时间（秒）
    private let requestTimeout: TimeInterval = WebBridgeKitConfiguration.Timing.networkRequestTimeout

    // MARK: - Initialization

    private init() {
        // Configure URLSession with proper timeout
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = requestTimeout
        self.urlSession = URLSession(configuration: configuration)

        // Register memory warning observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Memory Warning Handling

    /// 处理内存警告
    @objc private func handleMemoryWarning() {
        WebBridgeLogger.shared.log(.warning, "⚠️ [PageCache] Memory warning received, performing aggressive cleanup")

        lock.lock()
        defer { lock.unlock() }

        // 计算需要释放的内存量（释放当前使用量的 50%）
        let targetReduction = max(1, currentMemoryUsageMB / 2)
        var freedMemory = 0

        // 按优先级排序页面：命中率低且时间久的优先删除
        let sortedPages = pageCache.values.sorted { page1, page2 in
            // 优先比较命中率（命中率低的优先）
            if page1.hitCount != page2.hitCount {
                return page1.hitCount < page2.hitCount
            }
            // 命中率相同时，比较缓存时间（时间久的优先）
            return page1.cachedAt < page2.cachedAt
        }

        // 逐个删除页面直到释放足够的内存
        for page in sortedPages {
            if freedMemory >= targetReduction {
                break
            }

            let pageSize = page.estimatedSizeKB / 1024 // 转换为 MB
            pageCache.removeValue(forKey: page.pageName)
            freedMemory += pageSize

            WebBridgeLogger.shared.log(.info, "🧹 [PageCache] Memory warning: evicted '\(page.pageName)' (\(pageSize)MB)")
        }

        // 更新当前内存使用量
        currentMemoryUsageMB = calculateCurrentMemoryUsage()

        WebBridgeLogger.shared.log(.info, "🧹 [PageCache] Memory warning cleanup: freed \(freedMemory)MB, current usage: \(currentMemoryUsageMB)MB")
    }

    // MARK: - Public Methods

    /// 预加载页面（异步版本）
    /// - Parameter pageName: 页面名称
    /// - Returns: 是否成功预加载
    /// - Throws: WebBridgeError 如果加载失败
    public func preloadPage(named pageName: String) async throws -> Bool {
        return try await PerformanceMonitor.shared.measure(
            "PageCache.preloadPage",
            metadata: ["pageName": pageName]
        ) {
            // 检查是否已缓存
            if isCached(pageName: pageName) {
                WebBridgeLogger.shared.log(.info, "✅ [PageCache] Page '\(pageName)' already cached")
                return true
            }

            // 使用 RequestDeduplicator 防止重复请求
            return try await RequestDeduplicator.shared.executePagePreload(pageName: pageName) {
                // 检查网络状态
                try NetworkMonitor.shared.ensureNetworkAvailable()

                // 检查是否为蜂窝网络并发出警告
                if NetworkMonitor.shared.warnIfCellular() {
                    WebBridgeLogger.shared.log(.warning, "⚠️ [PageCache] Preloading '\(pageName)' over cellular network - data charges may apply")
                }

                // 加载 HTML 内容
                let html = try await self.loadHTMLContent(for: pageName)

                // 缓存页面
                let baseURL = try await self.getBaseURL()
                let cachedPage = CachedPage(pageName: pageName, html: html, baseURL: baseURL)
                let newPageSizeMB = cachedPage.estimatedSizeKB / 1024

                self.lock.withLock {
                    // 检查是否超过内存限制
                    let potentialMemoryUsage = self.currentMemoryUsageMB + newPageSizeMB
                    if potentialMemoryUsage > self.maxMemorySizeMB {
                        // 需要释放内存
                        self.evictToFreeMemory(requiredMB: newPageSizeMB)
                    }

                    // 使用 LRU 策略（数量限制）
                    if self.pageCache.count >= self.maxCacheSize {
                        self.evictLeastRecentlyUsed()
                    }

                    self.pageCache[pageName] = cachedPage
                    self.currentMemoryUsageMB = self.calculateCurrentMemoryUsage()

                    WebBridgeLogger.shared.log(.info, "✅ [PageCache] Preloaded page '\(pageName)' (size: \(newPageSizeMB)MB, total: \(self.currentMemoryUsageMB)MB/\(self.maxMemorySizeMB)MB, count: \(self.pageCache.count))")
                }
                return true
            }
        }
    }

    /// 预加载页面（旧版本，保持向后兼容）
    /// - Parameters:
    ///   - pageName: 页面名称
    ///   - completion: 完成回调
    @available(*, deprecated, message: "Use async version: preloadPage(named:) async throws -> Bool")
    public func preloadPage(named pageName: String, completion: @escaping (Bool) -> Void) {
        Task {
            do {
                let success = try await preloadPage(named: pageName)
                completion(success)
            } catch {
                WebBridgeLogger.shared.log(.error, "❌ [PageCache] Failed to preload page '\(pageName)': \(error)")
                completion(false)
            }
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
        let memoryBefore = currentMemoryUsageMB
        pageCache.removeAll()
        currentMemoryUsageMB = 0
        lock.unlock()

        WebBridgeLogger.shared.log(.info, "🧹 [PageCache] Cleared \(count) cached pages, freed \(memoryBefore)MB")
    }

    /// 获取缓存信息
    /// - Returns: 缓存信息字典
    public func getCacheInfo() -> [String: Any] {
        lock.lock()
        defer { lock.unlock() }

        var pageInfo: [[String: Any]] = []
        for page in pageCache.values {
            pageInfo.append([
                "pageName": page.pageName,
                "hitCount": page.hitCount,
                "cachedAt": ISO8601DateFormatter().string(from: page.cachedAt),
                "sizeKB": page.estimatedSizeKB,
                "sizeMB": page.estimatedSizeKB / 1024
            ])
        }

        let info: [String: Any] = [
            "countMetrics": [
                "cacheSize": pageCache.count,
                "maxCacheSize": maxCacheSize,
                "utilizationPercent": (pageCache.count * 100) / maxCacheSize
            ],
            "memoryMetrics": [
                "currentUsageMB": currentMemoryUsageMB,
                "maxMemorySizeMB": maxMemorySizeMB,
                "utilizationPercent": currentMemoryUsageMB > 0 ? (currentMemoryUsageMB * 100) / maxMemorySizeMB : 0,
                "availableMB": maxMemorySizeMB - currentMemoryUsageMB
            ],
            "cachedPages": pageCache.keys.sorted(),
            "pageDetails": pageInfo.sorted { ($0["pageName"] as! String) < ($1["pageName"] as! String) }
        ]

        return info
    }
}


/**
 * 页面缓存 JS 接口处理器
 * 支持以下方法：
 * - preload: 预加载页面
 * - clear: 清除缓存
 * - getInfo: 获取缓存统计信息
 *
 * 调用示例：
 * BarkBridge.callNative('page', { method: 'preload', pageName: 'test' }, (res) => { ... })
 */
public class WebPageCacheHandler: BaseWebNativeHandler {

    /**
     * 处理 JS 请求（使用 async/await）
     * - Parameters:
     *   - body: JS 传来的原始参数
     *   - completion: 异步结果回调
     */
    public override func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
        // 使用自动日志记录
        handleWithAutoLog(body: body, action: "page", completion: completion) {
            guard let method = body["method"] as? String else {
                reject(error: "Missing parameter: method", completion: completion)
                return
            }

            switch method {
            case "preload":
                guard let pageName = body["pageName"] as? String else {
                    reject(error: "Missing parameter: pageName", completion: completion)
                    return
                }

                // 使用 Task 包装 async 调用
                Task {
                    do {
                        let success = try await PageCacheManager.shared.preloadPage(named: pageName)
                        self.resolve(["success": success], completion: completion)
                    } catch let error as WebBridgeError {
                        WebBridgeLogger.shared.log(
                            .error,
                            "❌ [PageCache] Preload failed for '\(pageName)': \(error.localizedDescription)"
                        )
                        self.reject(
                            error: error.localizedDescription,
                            code: getErrorCode(for: error),
                            completion: completion
                        )
                    } catch {
                        WebBridgeLogger.shared.log(
                            .error,
                            "❌ [PageCache] Unknown error preloading '\(pageName)': \(error.localizedDescription)"
                        )
                        self.reject(
                            error: "Unknown error: \(error.localizedDescription)",
                            completion: completion
                        )
                    }
                }

            case "clear":
                PageCacheManager.shared.clearCache()
                resolve(["cleared": true], completion: completion)

            case "getInfo":
                let info = PageCacheManager.shared.getCacheInfo()
                resolve(info, completion: completion)

            default:
                reject(error: "Unsupported method: \(method)", completion: completion)
            }
        }
    }

    // MARK: - Helper Methods

    /// 根据 WebBridgeError 获取对应的错误码
    private func getErrorCode(for error: WebBridgeError) -> Int {
        switch error {
        case .invalidInput:
            return 400
        case .networkRequestFailed:
            return 502
        case .cacheLoadFailed:
            return 503
        case .cacheSaveFailed:
            return 504
        case .databaseOperationFailed:
            return 500
        case .timeout:
            return 504
        case .networkUnavailable:
            return 503
        case .browserOpenFailed:
            return 500
        }
    }
}
