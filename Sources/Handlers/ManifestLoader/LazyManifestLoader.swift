//
//  LazyManifestLoader.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-02-02.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import WebKit
import UIKit
import CryptoKit

private struct AnyCodableValue: Codable {
    let stringValue: String?
    let objectValue: [String: AnyCodableValue]?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            stringValue = str
            objectValue = nil
        } else if let obj = try? container.decode([String: AnyCodableValue].self) {
            stringValue = nil
            objectValue = obj
        } else {
            stringValue = nil
            objectValue = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let str = stringValue {
            try container.encode(str)
        } else if let obj = objectValue {
            try container.encode(obj)
        }
    }
}

/// 懒加载 Manifest 加载器
/// 实现懒加载缓存模式：
/// 1. 检查 manifest.json 的 persistent 字段
/// 2. 如果为 false，立即加载 HTML，后台异步下载资源
/// 3. 使用 loadHTMLString + baseURL + custom:// 加载
public class LazyManifestLoader: NSObject {

    // MARK: - Types

    public enum LazyLoadError: Error, LocalizedError {
        case manifestNotFound
        case manifestDownloadFailed(Error)
        case htmlDownloadFailed(Error)
        case resourceDownloadFailed(String, Error)
        case managerDeallocated

        public var errorDescription: String? {
            switch self {
            case .manifestNotFound:
                return "Manifest file not found"
            case .manifestDownloadFailed(let error):
                return "Failed to download manifest: \(error.localizedDescription)"
            case .htmlDownloadFailed(let error):
                return "Failed to download HTML: \(error.localizedDescription)"
            case .resourceDownloadFailed(let resource, let error):
                return "Failed to download resource '\(resource)': \(error.localizedDescription)"
            case .managerDeallocated:
                return "Manager was deallocated"
            }
        }
    }

    public struct WebManifest: Codable {
        public let persistent: Bool
        public let resources: [String: String]
        public let version: String?
        public let appid: String?
        public let name: String?
        public let icon: String?
        public let updatedAt: String?
        public let description: String?

        private enum CodingKeys: String, CodingKey {
            case persistent, resources, version, appid, name, icon, updatedAt, description
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            persistent = try container.decodeIfPresent(Bool.self, forKey: .persistent) ?? false
            version = try container.decodeIfPresent(String.self, forKey: .version)
            appid = try container.decodeIfPresent(String.self, forKey: .appid)
            name = try container.decodeIfPresent(String.self, forKey: .name)
            icon = try container.decodeIfPresent(String.self, forKey: .icon)
            updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
            description = try container.decodeIfPresent(String.self, forKey: .description)
            resources = try Self.decodeResources(from: container)
        }

        private static func decodeResources(from container: KeyedDecodingContainer<CodingKeys>) throws -> [String: String] {
            if let flat = try? container.decode([String: String].self, forKey: .resources) {
                return flat
            }
            if let nested = try? container.decode([String: [String: AnyCodableValue]].self, forKey: .resources) {
                var flat: [String: String] = [:]
                for (_, entries) in nested {
                    for (path, value) in entries {
                        if let obj = value.objectValue, let url = obj["url"]?.stringValue {
                            flat[path] = url
                        } else if let str = value.stringValue {
                            flat[path] = str
                        }
                    }
                }
                return flat
            }
            return [:]
        }

        public init(
            persistent: Bool,
            resources: [String: String],
            version: String? = nil,
            appid: String? = nil,
            name: String? = nil,
            icon: String? = nil,
            updatedAt: String? = nil,
            description: String? = nil
        ) {
            self.persistent = persistent
            self.resources = resources
            self.version = version
            self.appid = appid
            self.name = name
            self.icon = icon
            self.updatedAt = updatedAt
            self.description = description
        }

        public var resolvedVersion: String {
            return version ?? "0.0.1"
        }
    }

    // MARK: - Properties

    private var urlSession: URLSession!
    private let manifestCacheManager: ManifestCacheManager
    public let scheme = "custom"
    private let manifestFileName = "manifest.json"

    // MARK: - Singleton

    public static let shared = LazyManifestLoader()

    // MARK: - Initialization

    private override init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.httpMaximumConnectionsPerHost = 10
        self.manifestCacheManager = ManifestCacheManager.shared
        super.init()
        self.urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    // MARK: - Public API

    /// 取消所有正在进行的下载
    public func cancelAllDownloads() {
        urlSession.getTasksWithCompletionHandler { dataTasks, uploadTasks, downloadTasks in
            dataTasks.forEach { $0.cancel() }
            uploadTasks.forEach { $0.cancel() }
            downloadTasks.forEach { $0.cancel() }
        }
    }

    /// 智能加载 URL - 根据 manifest 的 persistent 属性自动选择加载器
    /// - Parameters:
    ///   - url: 要加载的 URL
    ///   - webView: 目标 WebView
    ///   - viewController: 用于显示持久化模式进度的控制器
    ///   - forceRefresh: 是否强制刷新
    ///   - completion: 完成回调
    public static func smartLoad(
        url: URL,
        in webView: WKWebView,
        from viewController: UIViewController? = nil,
        forceRefresh: Bool = false,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            let isOffline = !NetworkMonitor.shared.isConnected
            NSLog("[DIAG-SMART] smartLoad url=\(url.absoluteString) isOffline=\(isOffline) forceRefresh=\(forceRefresh)")

            if isOffline && !forceRefresh {
                NSLog("[WEB-DIAG] smartLoad: isOffline=true, URL=\(url.absoluteString)")
                shared.postLog("[SATELLITE] [离线检测] 设备离线，尝试从本地缓存加载")

                let loaded = shared.tryLoadFromCache(url: url, in: webView) { result in
                    completion(result)
                }

                if !loaded {
                    shared.postLog("[FAIL] [离线检测] 未找到本地缓存，显示离线提示页")
                    DispatchQueue.main.async {
                        shared.loadOfflineErrorPage(url: url, in: webView)
                    }
                    completion(.success(()))
                }
                return
            }

            if !forceRefresh && PersistentManifestLoader.shared.isCached(url: url) {
                NSLog("[WEB-DIAG] smartLoad: 在线但缓存命中, URL=\(url.absoluteString)")
                shared.postLog("[FAST] [智能加载] 缓存命中，秒开（零网络请求）")
                PersistentManifestLoader.shared.loadFromCache(url: url, in: webView) { cacheResult in
                    switch cacheResult {
                    case .success:
                        completion(.success(()))
                    case .failure(let error):
                        shared.postLog("[WARN] [智能加载] loadFromCache 失败: \(error.localizedDescription)，降级到网络加载")
                        Self.performOnlineLoad(
                            url: url,
                            in: webView,
                            from: viewController,
                            forceRefresh: false,
                            completion: completion
                        )
                    }
                }
                return
            }

            NSLog("[DIAG-SMART] BRANCH: calling performOnlineLoad (no cache hit)")
            Self.performOnlineLoad(
                url: url,
                in: webView,
                from: viewController,
                forceRefresh: forceRefresh,
                completion: completion
            )
        }
    }

    private static func performOnlineLoad(
        url: URL,
        in webView: WKWebView,
        from viewController: UIViewController?,
        forceRefresh: Bool,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            NSLog("[DIAG-PERFORM] performOnlineLoad START url=\(url.absoluteString) forceRefresh=\(forceRefresh) hasVC=\(viewController != nil)")
            do {
                if forceRefresh {
                    shared.postLog("[SYNC] [强制刷新] 绕过缓存，重新下载所有内容")
                }
                shared.postLog("[SEARCH] [智能加载] 正在检查 manifest.json...")
                NSLog("[DIAG-PERFORM] fetching manifest...")
                let manifest = try await shared.fetchManifestSync(from: url)
                NSLog("[DIAG-PERFORM] manifest decoded OK: persistent=\(manifest.persistent) resources=\(manifest.resources.count) version=\(manifest.version ?? "nil")")
                shared.postLog("[LIST] [智能加载] Manifest 已加载")
                shared.postLog("   版本: \(manifest.version ?? "无")")
                shared.postLog("   持久化: \(manifest.persistent)")
                shared.postLog("   资源数量: \(manifest.resources.count)")

                if manifest.persistent {
                    NSLog("[DIAG-PERFORM] BRANCH: persistent=true, checking viewController...")
                    shared.postLog("[SAVE] [智能加载] 选择持久化模式")
                    guard let viewController = viewController else {
                        NSLog("[DIAG-PERFORM] FAIL: viewController is nil, cannot use persistent mode")
                        completion(.failure(LazyLoadError.manifestDownloadFailed(NSError(
                            domain: "LazyManifestLoader",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "ViewController is required for persistent mode"]
                        ))))
                        return
                    }
                    NSLog("[DIAG-PERFORM] CALLING PersistentManifestLoader.load url=\(url.absoluteString)")
                    PersistentManifestLoader.load(
                        url: url,
                        in: webView,
                        from: viewController
                    ) { result in
                        NSLog("[DIAG-PERFORM] PersistentManifestLoader.load completed: \(result)")
                        completion(result)
                    }
                } else {
                    NSLog("[DIAG-PERFORM] BRANCH: persistent=false, using lazy-load")
                    shared.postLog("[FAST] [智能加载] 选择懒加载模式")
                    shared.loadInternal(url: url, in: webView, manifest: manifest, forceRefresh: forceRefresh, completion: completion)
                }
            } catch {
                NSLog("[DIAG-PERFORM] CATCH: fetchManifestSync failed: \(error)")
                shared.postLog("[WARN] [智能加载] 未找到 manifest.json，尝试本地缓存")

                let loaded = shared.tryLoadFromCache(url: url, in: webView) { result in
                    completion(result)
                }

                if !loaded {
                    NSLog("[DIAG-PERFORM] FALLBACK: no cache, loading plain WebView")
                    shared.postLog("[WARN] [智能加载] 本地也无缓存，回退到普通 WebView 加载")
                    DispatchQueue.main.async {
                        if url.isFileURL {
                            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
                        } else {
                            let request = URLRequest(url: url)
                            webView.load(request)
                        }
                        completion(.success(()))
                    }
                }
            }
        }
    }

    /// 加载 URL（懒加载模式）
    /// - Parameters:
    ///   - url: 要加载的 URL
    ///   - webView: 目标 WebView
    ///   - forceRefresh: 是否强制刷新
    ///   - completion: 完成回调
    public static func load(
        url: URL,
        in webView: WKWebView,
        forceRefresh: Bool = false,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        shared.loadInternal(url: url, in: webView, forceRefresh: forceRefresh, completion: completion)
    }

    // MARK: - Internal Loading Logic

    private func loadInternal(
        url: URL,
        in webView: WKWebView,
        manifest: WebManifest? = nil,
        forceRefresh: Bool = false,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let initialCacheID = generateCacheID(for: url)

        postLog("[SYNC] [加载流程] URL: \(url.absoluteString)")
        postLog("   Initial Cache ID: \(initialCacheID)")
        if forceRefresh {
            postLog("   [SYNC] 强制刷新模式：绕过缓存")
        }

        let handleManifest: (WebManifest) -> Void = { [weak self] manifest in
            guard let self = self else {
                completion(.failure(LazyLoadError.managerDeallocated))
                return
            }

            self.postLog("[LIST] [Manifest] 版本: \(manifest.version ?? "无"), 资源数: \(manifest.resources.count), 持久化: \(manifest.persistent)")

            // 使用 AppID 生成最终的 cache ID
            let cacheID = self.generateCacheID(for: url, manifest: manifest)
            self.postLog("   Final Cache ID (AppID-based): \(cacheID)")
            self.postLog("   AppID: \(manifest.appid ?? "使用域名")")

            // 2. 检查是否已有缓存（除非强制刷新）
            if !forceRefresh, let cachedHTML = self.manifestCacheManager.getCachedHTML(for: cacheID) {
                //  FIX: 检查版本，如果版本变化则清除旧缓存
                let cachedManifest = self.manifestCacheManager.getCachedManifest(for: cacheID)
                let currentVersion = manifest.resolvedVersion
                let cachedVersion = cachedManifest?.version ?? "unknown"

                self.postLog("[SEARCH] [缓存检查] 发现缓存 HTML (版本: \(cachedVersion))")

                if currentVersion != cachedVersion {
                    self.postLog("[SYNC] [版本变化] \(cachedVersion) -> \(currentVersion), 清除旧缓存重新下载")
                    // 清除旧缓存
                    self.manifestCacheManager.removeCache(for: cacheID)
                    // 继续下载新的 HTML
                    self.lazyLoad(url: url, manifest: manifest, cacheID: cacheID, webView: webView, completion: completion)
                    return
                }

                // 检查缓存 HTML 的大小
                let cachedSize = cachedHTML.count
                self.postLog("[RECYCLE] [缓存命中] 使用缓存 HTML (版本: \(currentVersion), 大小: \(cachedSize) chars)")

                // 从缓存加载
                self.manifestCacheManager.loadHTML(cachedHTML, into: webView)

                //  发送通知用于 UI 更新
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .manifestCacheHit,
                        object: nil,
                        userInfo: ["source": "INTERCEPT"]
                    )
                }

                //  FIX: 从缓存加载时也需要设置 pageKey
                if let schemeHandler = webView.configuration.urlSchemeHandler(forURLScheme: self.scheme) as? ManifestURLSchemeHandler {
                    schemeHandler.setPageKey(cacheID, for: webView)
                    self.postLog("[OK] [pageKey] 已设置 '\(cacheID)'")
                } else {
                    self.postLog("[WARN] [pageKey] ManifestURLSchemeHandler 未找到")
                }

                completion(.success(()))
                return
            }

            if forceRefresh {
                self.postLog("[SYNC] [强制刷新] 清除旧缓存，重新下载")
                self.manifestCacheManager.removeCache(for: cacheID)
            } else {
                self.postLog("[EMOJI] [缓存未命中] 无缓存 HTML，开始下载")
            }

            // 3. 根据 persistent 决定加载策略
            if !manifest.persistent {
                // 懒加载模式：立即加载 HTML，后台下载资源
                self.postLog("[FAST] [加载模式] 懒加载（立即显示 HTML）")
                self.lazyLoad(url: url, manifest: manifest, cacheID: cacheID, webView: webView, completion: completion)
            } else {
                // 持久化模式：等待所有资源下载完成
                self.postLog("[SAVE] [加载模式] 持久化（等待资源下载）")
                self.persistentLoad(url: url, manifest: manifest, cacheID: cacheID, webView: webView, completion: completion)
            }
        }

        if let manifest = manifest {
            handleManifest(manifest)
        } else {
            // 1. 下载 manifest.json
            downloadManifest(from: url) { result in
                switch result {
                case .success(let manifest):
                    handleManifest(manifest)
                case .failure(let error):
                    NSLog("[FAIL] [LazyManifestLoader] Failed to download manifest: %@", error.localizedDescription)
                    completion(.failure(error))
                }
            }
        }
    }

    // MARK: - Offline Fallback

    @discardableResult
    private func tryLoadFromCache(
        url: URL,
        in webView: WKWebView,
        completion: @escaping (Result<Void, Error>) -> Void
    ) -> Bool {
        let cacheID = generateCacheID(for: url)

        NSLog("[WEB-DIAG] tryLoadFromCache URL: \(url.absoluteString), cacheID: \(cacheID)")
        let persistentLoader = PersistentManifestLoader.shared
        let isCachedResult = persistentLoader.isCached(url: url)
        NSLog("[WEB-DIAG] tryLoadFromCache PersistentManifestLoader.isCached: \(isCachedResult)")
        if isCachedResult {
            postLog("[RECYCLE] [离线回退] 发现本地持久化缓存: \(cacheID)")
            persistentLoader.loadFromCache(url: url, in: webView) { [weak self] result in
                switch result {
                case .success:
                    self?.postLog("[OK] [离线回退] 从本地缓存加载成功")
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: .manifestCacheHit,
                            object: nil,
                            userInfo: ["source": "OFFLINE_FALLBACK"]
                        )
                    }
                    completion(.success(()))
                case .failure(let error):
                    self?.postLog("[FAIL] [离线回退] 本地缓存加载失败: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
            return true
        }

        if let cachedHTML = manifestCacheManager.getCachedHTML(for: cacheID) {
            postLog("[RECYCLE] [离线回退] 发现内存缓存: \(cacheID)")
            manifestCacheManager.loadHTML(cachedHTML, into: webView)
            if let schemeHandler = webView.configuration.urlSchemeHandler(forURLScheme: scheme) as? ManifestURLSchemeHandler {
                schemeHandler.setPageKey(cacheID, for: webView)
            }
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .manifestCacheHit,
                    object: nil,
                    userInfo: ["source": "OFFLINE_FALLBACK"]
                )
            }
            completion(.success(()))
            return true
        }

        return false
    }

    private func loadOfflineErrorPage(url: URL, in webView: WKWebView) {
        let escaped = url.absoluteString
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                body { font-family: -apple-system; display: flex; justify-content: center; align-items: center; min-height: 100vh; margin: 0; background: #f5f7fa; color: #333; text-align: center; padding: 20px; }
                .container { max-width: 320px; }
                .icon { font-size: 48px; margin-bottom: 16px; }
                h2 { font-size: 18px; font-weight: 600; margin-bottom: 8px; }
                p { font-size: 14px; color: #666; line-height: 1.5; margin-bottom: 16px; }
                .url { font-size: 12px; color: #999; word-break: break-all; padding: 8px; background: #fff; border-radius: 8px; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="icon">\u{1F4E1}</div>
                <h2>\u{65E0}\u{6CD5}\u{8BBF}\u{95EE}\u{6B64}\u{9875}\u{9762}</h2>
                <p>\u{8BBE}\u{5907}\u{5904}\u{4E8E}\u{79BB}\u{7EBF}\u{72B6}\u{6001}\u{FF0C}\u{4E14}\u{8BE5}\u{9875}\u{9762}\u{5C1A}\u{672A}\u{7F13}\u{5B58}\u{3002}\u{8BF7}\u{8FDE}\u{63A5}\u{7F51}\u{7EDC}\u{540E}\u{91CD}\u{8BD5}\u{3002}</p>
                <div class="url">\(escaped)</div>
            </div>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    // MARK: - Helper Methods

    private func generateCacheID(for url: URL, manifest: WebManifest? = nil) -> String {
        // 使用框架统一的 AppID 解析逻辑
        let coreManifest = manifest.map { convertToManifest($0) }
        return AppIDResolver.resolveAppID(from: url, manifest: coreManifest)
    }

    private func postLog(_ message: String) {
        NSLog("[WEB] [LazyLoader] %@", message)
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .resourceLogNotification,
                object: nil,
                userInfo: ["message": message]
            )
        }
    }

    private func fetchManifestSync(from url: URL) async throws -> WebManifest {
        //  修复：如果 URL 看起来像是一个 HTML 文件，先取其父目录
        var baseURL = url
        if url.pathExtension.lowercased() == "html" || url.pathExtension.lowercased() == "htm" {
            baseURL = url.deletingLastPathComponent()
        }

        let manifestURL = baseURL.appendingPathComponent(manifestFileName)
        NSLog("[WEB] [LazyLoader] 正在尝试下载 Manifest: %@", manifestURL.absoluteString)
        do {
            let (data, response) = try await urlSession.data(from: manifestURL)
            NSLog("[DIAG-FETCH] manifest data size: \(data.count) bytes")
            if let httpResponse = response as? HTTPURLResponse {
                NSLog("[DIAG-FETCH] HTTP status: \(httpResponse.statusCode)")
            }
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                NSLog("[FAIL] [LazyLoader] Manifest 下载失败，状态码: %d", httpResponse.statusCode)
                throw LazyLoadError.manifestDownloadFailed(NSError(domain: "LazyManifestLoader", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"]))
            }
            NSLog("[DIAG-FETCH] raw JSON: \(String(data: data.prefix(500), encoding: .utf8) ?? "nil")")
            let decoded = try JSONDecoder().decode(WebManifest.self, from: data)
            NSLog("[DIAG-FETCH] decoded OK: persistent=\(decoded.persistent) resources.count=\(decoded.resources.count)")
            return decoded
        } catch {
            NSLog("[FAIL] [LazyLoader] Manifest 处理失败: %@", error.localizedDescription)
            throw error
        }
    }

    private func downloadManifest(from url: URL, completion: @escaping (Result<WebManifest, Error>) -> Void) {
        let manifestURL = url.appendingPathComponent(manifestFileName)
        urlSession.dataTask(with: manifestURL) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(LazyLoadError.manifestNotFound))
                return
            }
            do {
                let manifest = try JSONDecoder().decode(WebManifest.self, from: data)
                completion(.success(manifest))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    private func lazyLoad(
        url: URL,
        manifest: WebManifest,
        cacheID: String,
        webView: WKWebView,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        downloadHTML(from: url) { [weak self] result in
            guard let self = self else {
                completion(.failure(LazyLoadError.managerDeallocated))
                return
            }
            switch result {
            case .success(let html):
                // 1. 保存 HTML
                self.manifestCacheManager.savePage(pageKey: cacheID, html: html, manifest: self.convertToManifest(manifest))

                // 2. 立即加载 HTML
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.manifestCacheManager.loadHTML(html, into: webView)
                    if let schemeHandler = webView.configuration.urlSchemeHandler(forURLScheme: self.scheme) as? ManifestURLSchemeHandler {
                        schemeHandler.setPageKey(cacheID, for: webView)
                    }
                }
                completion(.success(()))

                // 3. 后台异步下载所有资源
                let resourceBaseURL = (url.pathExtension.isEmpty || url.hasDirectoryPath) ? url : url.deletingLastPathComponent()
                self.downloadAllResources(manifest: manifest, baseURL: resourceBaseURL, pageKey: cacheID)

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func persistentLoad(
        url: URL,
        manifest: WebManifest,
        cacheID: String,
        webView: WKWebView,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // 持久化加载逻辑由 PersistentManifestLoader 处理，这里仅作兼容
        Task { @MainActor in
            PersistentManifestLoader.load(url: url, in: webView, completion: completion)
        }
    }

    private func downloadHTML(from url: URL, completion: @escaping (Result<String, Error>) -> Void) {
        urlSession.dataTask(with: url) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                completion(.failure(LazyLoadError.htmlDownloadFailed(NSError(domain: "LazyManifestLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid HTML data"]))))
                return
            }
            completion(.success(html))
        }.resume()
    }

    private func downloadAllResources(manifest: WebManifest, baseURL: URL, pageKey: String) {
        for (relativePath, resourceURLString) in manifest.resources {
            guard let resourceURL = URL(string: resourceURLString, relativeTo: baseURL) else { continue }
            urlSession.dataTask(with: resourceURL) { [weak self] data, response, _ in
                guard let self = self, let data = data, let response = response as? HTTPURLResponse else { return }
                let mimeType = response.mimeType ?? "application/octet-stream"
                let resource = ResourceData(relativePath: relativePath, data: data, mimeType: mimeType)
                ResourceCache.shared.set(resource, for: pageKey)
                self.postLog("[OK] [资源下载] 已缓存: \(relativePath)")

                //  资源下载完成后通知 UI 刷新，以便更新缓存大小显示
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .manifestCacheDidUpdate,
                        object: nil
                    )
                }
            }.resume()
        }
    }

    private func convertToManifest(_ webManifest: WebManifest) -> Manifest {
        return Manifest(
            resources: webManifest.resources,
            version: webManifest.version,
            persistent: webManifest.persistent,
            lastUpdated: Date(),
            appid: webManifest.appid,
            name: webManifest.name,
            icon: webManifest.icon
        )
    }
}

// MARK: - URLSessionDelegate (SSL Trust for Development)
extension LazyManifestLoader: URLSessionDelegate {
    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            #if DEBUG
            NSLog("[WEB] [LazyLoader] Trusting SSL cert for: %@", challenge.protectionSpace.host)
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
            #else
            completionHandler(.performDefaultHandling, nil)
            #endif
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
