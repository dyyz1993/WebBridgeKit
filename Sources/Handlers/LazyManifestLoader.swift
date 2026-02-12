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

    /// Web Manifest 结构
    public struct WebManifest: Codable {
        /// 是否启用持久化缓存
        public let persistent: Bool

        /// 资源映射：相对路径 -> 真实 URL
        public let resources: [String: String]

        /// 版本号（默认 "0.0.1"）
        public let version: String?

        /// 应用标识符（可选，用于缓存路径和清理）
        public let appid: String?

        /// 应用名称（可选，用于显示）
        public let name: String?

        /// 应用图标 URL（可选，用于显示）
        public let icon: String?

        /// 最后更新时间（可选，用于兼容性）
        public let updatedAt: String?

        /// 描述信息（可选，用于兼容性）
        public let description: String?

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

        /// 获取版本号，如果没有则返回默认值
        public var resolvedVersion: String {
            return version ?? "0.0.1"
        }
    }

    // MARK: - Properties

    private let urlSession: URLSession
    private let manifestCacheManager: ManifestCacheManager
    public let scheme = "custom"
    private let manifestFileName = "manifest.json"

    // MARK: - Singleton

    public static let shared = LazyManifestLoader()

    // MARK: - Initialization

    private override init() {
        // 配置 URLSession
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.httpMaximumConnectionsPerHost = 10
        self.urlSession = URLSession(configuration: config)
        self.manifestCacheManager = ManifestCacheManager.shared
        super.init()
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
            do {
                if forceRefresh {
                    shared.postLog("🔄 [强制刷新] 绕过缓存，重新下载所有内容")
                }
                shared.postLog("🔍 [智能加载] 正在检查 manifest.json...")
                let manifest = try await shared.fetchManifestSync(from: url)
                shared.postLog("📋 [智能加载] Manifest 已加载")
                shared.postLog("   版本: \(manifest.version ?? "无")")
                shared.postLog("   持久化: \(manifest.persistent)")
                shared.postLog("   资源数量: \(manifest.resources.count)")

                if manifest.persistent {
                    shared.postLog("💾 [智能加载] 选择持久化模式")
                    guard let viewController = viewController else {
                        completion(.failure(LazyLoadError.manifestDownloadFailed(NSError(
                            domain: "LazyManifestLoader",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "ViewController is required for persistent mode"]
                        ))))
                        return
                    }
                    await PersistentManifestLoader.load(
                        url: url,
                        in: webView,
                        from: viewController
                    ) { result in
                        completion(result)
                    }
                } else {
                    shared.postLog("⚡ [智能加载] 选择懒加载模式")
                    // ✅ 直接调用内部加载逻辑，不再重复下载 manifest
                    shared.loadInternal(url: url, in: webView, manifest: manifest, forceRefresh: forceRefresh, completion: completion)
                }
            } catch {
                shared.postLog("⚠️ [智能加载] 未找到 manifest.json，回退到普通 WebView 加载")
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

        postLog("🔄 [加载流程] URL: \(url.absoluteString)")
        postLog("   Initial Cache ID: \(initialCacheID)")
        if forceRefresh {
            postLog("   🔄 强制刷新模式：绕过缓存")
        }

        let handleManifest: (WebManifest) -> Void = { [weak self] manifest in
            guard let self = self else {
                completion(.failure(LazyLoadError.managerDeallocated))
                return
            }

            self.postLog("📋 [Manifest] 版本: \(manifest.version ?? "无"), 资源数: \(manifest.resources.count), 持久化: \(manifest.persistent)")

            // 使用 AppID 生成最终的 cache ID
            let cacheID = self.generateCacheID(for: url, manifest: manifest)
            self.postLog("   Final Cache ID (AppID-based): \(cacheID)")
            self.postLog("   AppID: \(manifest.appid ?? "使用域名")")

            // 2. 检查是否已有缓存（除非强制刷新）
            if !forceRefresh, let cachedHTML = self.manifestCacheManager.getCachedHTML(for: cacheID) {
                // ✅ FIX: 检查版本，如果版本变化则清除旧缓存
                let cachedManifest = self.manifestCacheManager.getCachedManifest(for: cacheID)
                let currentVersion = manifest.resolvedVersion
                let cachedVersion = cachedManifest?.version ?? "unknown"

                self.postLog("🔍 [缓存检查] 发现缓存 HTML (版本: \(cachedVersion))")

                if currentVersion != cachedVersion {
                    self.postLog("🔄 [版本变化] \(cachedVersion) -> \(currentVersion), 清除旧缓存重新下载")
                    // 清除旧缓存
                    self.manifestCacheManager.removeCache(for: cacheID)
                    // 继续下载新的 HTML
                    self.lazyLoad(url: url, manifest: manifest, cacheID: cacheID, webView: webView, completion: completion)
                    return
                }

                // 检查缓存 HTML 的大小
                let cachedSize = cachedHTML.count
                self.postLog("♻️ [缓存命中] 使用缓存 HTML (版本: \(currentVersion), 大小: \(cachedSize) chars)")

                // 从缓存加载
                self.manifestCacheManager.loadHTML(cachedHTML, into: webView)
                
                // 🔥 发送通知用于 UI 更新
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .manifestCacheHit,
                        object: nil,
                        userInfo: ["source": "INTERCEPT"]
                    )
                }

                // ✅ FIX: 从缓存加载时也需要设置 pageKey
                if let schemeHandler = webView.configuration.urlSchemeHandler(forURLScheme: self.scheme) as? ManifestURLSchemeHandler {
                    schemeHandler.setPageKey(cacheID, for: webView)
                    self.postLog("✅ [pageKey] 已设置 '\(cacheID)'")
                } else {
                    self.postLog("⚠️ [pageKey] ManifestURLSchemeHandler 未找到")
                }

                completion(.success(()))
                return
            }

            if forceRefresh {
                self.postLog("🔄 [强制刷新] 清除旧缓存，重新下载")
                self.manifestCacheManager.removeCache(for: cacheID)
            } else {
                self.postLog("📭 [缓存未命中] 无缓存 HTML，开始下载")
            }

            // 3. 根据 persistent 决定加载策略
            if !manifest.persistent {
                // 懒加载模式：立即加载 HTML，后台下载资源
                self.postLog("⚡ [加载模式] 懒加载（立即显示 HTML）")
                self.lazyLoad(url: url, manifest: manifest, cacheID: cacheID, webView: webView, completion: completion)
            } else {
                // 持久化模式：等待所有资源下载完成
                self.postLog("💾 [加载模式] 持久化（等待资源下载）")
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
                    NSLog("❌ [LazyManifestLoader] Failed to download manifest: %@", error.localizedDescription)
                    completion(.failure(error))
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func generateCacheID(for url: URL, manifest: WebManifest? = nil) -> String {
        // 使用框架统一的 AppID 解析逻辑
        let coreManifest = manifest.map { convertToManifest($0) }
        return AppIDResolver.resolveAppID(from: url, manifest: coreManifest)
    }

    private func postLog(_ message: String) {
        NSLog("🌐 [LazyLoader] %@", message)
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .resourceLogNotification,
                object: nil,
                userInfo: ["message": message]
            )
        }
    }

    private func fetchManifestSync(from url: URL) async throws -> WebManifest {
        // 🔥 修复：如果 URL 看起来像是一个 HTML 文件，先取其父目录
        var baseURL = url
        if url.pathExtension.lowercased() == "html" || url.pathExtension.lowercased() == "htm" {
            baseURL = url.deletingLastPathComponent()
        }
        
        let manifestURL = baseURL.appendingPathComponent(manifestFileName)
        NSLog("🌐 [LazyLoader] 正在尝试下载 Manifest: %@", manifestURL.absoluteString)
        do {
            let (data, response) = try await urlSession.data(from: manifestURL)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                NSLog("❌ [LazyLoader] Manifest 下载失败，状态码: %d", httpResponse.statusCode)
                throw LazyLoadError.manifestDownloadFailed(NSError(domain: "LazyManifestLoader", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"]))
            }
            return try JSONDecoder().decode(WebManifest.self, from: data)
        } catch {
            NSLog("❌ [LazyLoader] Manifest 处理失败: %@", error.localizedDescription)
            throw error
        }
    }

    private func downloadManifest(from url: URL, completion: @escaping (Result<WebManifest, Error>) -> Void) {
        let manifestURL = url.appendingPathComponent(manifestFileName)
        urlSession.dataTask(with: manifestURL) { data, response, error in
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
            guard let self = self else { return }
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
                self.downloadAllResources(manifest: manifest, baseURL: url.deletingLastPathComponent(), pageKey: cacheID)

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
            await PersistentManifestLoader.load(url: url, in: webView, completion: completion)
        }
    }

    private func downloadHTML(from url: URL, completion: @escaping (Result<String, Error>) -> Void) {
        urlSession.dataTask(with: url) { data, response, error in
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
            urlSession.dataTask(with: resourceURL) { [weak self] data, response, error in
                guard let self = self, let data = data, let response = response as? HTTPURLResponse else { return }
                let mimeType = response.mimeType ?? "application/octet-stream"
                let resource = ResourceData(relativePath: relativePath, data: data, mimeType: mimeType)
                ResourceCache.shared.set(resource, for: pageKey)
                self.postLog("✅ [资源下载] 已缓存: \(relativePath)")
                
                // ✅ 资源下载完成后通知 UI 刷新，以便更新缓存大小显示
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
