//
//  PersistentManifestLoader.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-02-02.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import WebKit
import UIKit
import CryptoKit

/// 持久化 Manifest 加载器
/// 实现完全离线缓存模式：
/// 1. 检查 manifest.json 的 persistent 字段
/// 2. 如果为 true，下载所有资源到本地缓存
/// 3. 显示实时进度弹窗
/// 4. 使用 loadHTMLString + wb-resource:// 加载
public class PersistentManifestLoader: NSObject {

    // MARK: - Types

    public enum LoaderError: Error, LocalizedError {
        case manifestNotFound
        case invalidManifestFormat
        case persistentModeDisabled
        case htmlDownloadFailed(Error)
        case resourceDownloadFailed(String, Error)
        case cacheDirectoryCreationFailed
        case webViewNotAvailable

        public var errorDescription: String? {
            switch self {
            case .manifestNotFound:
                return "Manifest file not found"
            case .invalidManifestFormat:
                return "Invalid manifest format"
            case .persistentModeDisabled:
                return "Persistent mode is not enabled for this page"
            case .htmlDownloadFailed(let error):
                return "Failed to download HTML: \(error.localizedDescription)"
            case .resourceDownloadFailed(let resource, let error):
                return "Failed to download resource '\(resource)': \(error.localizedDescription)"
            case .cacheDirectoryCreationFailed:
                return "Failed to create cache directory"
            case .webViewNotAvailable:
                return "WebView is not available"
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
        /// 如果不提供，将使用域名作为 AppID
        public let appid: String?

        /// 应用名称（可选，用于显示）
        /// 如果不提供，将从 HTML title 提取
        public let name: String?

        /// 应用图标 URL（可选，用于显示）
        /// 如果不提供，将生成默认圆形图标
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

    /// 加载状态
    public enum LoadingState {
        case idle
        case fetchingManifest
        case downloadingResources(current: Int, total: Int)
        case preparingHTML
        case loadingWebView
        case completed
        case failed(Error)
    }

    // MARK: - Properties

    private let urlSession: URLSession
    private let cacheDirectory: URL
    public let scheme = "wb-resource"
    private let manifestFileName = "manifest.json"

    private var progressModal: FullScreenProgressViewController?
    private var loadingState: LoadingState = .idle
    private let stateLock = NSLock()

    // 下载任务管理
    private var downloadTasks: [URLSessionDataTask] = []
    private let tasksLock = NSLock()

    // URL 到 AppID 的映射（内存缓存，用于快速检查 isCached）
    private var urlToAppID: [URL: String] = [:]
    private let urlMappingLock = NSLock()

    // MARK: - Singleton

    public static let shared = PersistentManifestLoader()

    // MARK: - Initialization

    private override init() {
        // 配置 URLSession
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        config.httpMaximumConnectionsPerHost = 6  // 并发下载数量
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        ]
        self.urlSession = URLSession(configuration: config)

        // 设置缓存目录
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.cacheDirectory = cachesDir.appendingPathComponent("WebBridgeKit/PersistentCache")

        super.init()

        // 创建缓存目录
        createCacheDirectoryIfNeeded()
    }

    // MARK: - Public API

    /// 加载持久化页面
    /// - Parameters:
    ///   - url: 页面 URL
    ///   - webView: 目标 WebView
    ///   - viewController: 用于显示进度弹窗的控制器
    ///   - completion: 完成回调
    public static func load(
        url: URL,
        in webView: WKWebView,
        from viewController: UIViewController? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task { @MainActor in
            do {
                try await shared.loadPersistentPage(
                    url: url,
                    in: webView,
                    from: viewController
                )
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// 检查 URL 是否支持持久化模式
    /// - Parameter url: 页面 URL
    /// - Returns: 是否支持持久化
    public static func supportsPersistentMode(for url: URL) async -> Bool {
        do {
            let manifest = try await shared.fetchManifest(from: url)
            return manifest.persistent
        } catch {
            return false
        }
    }

    /// 获取缓存大小
    /// - Parameter cacheID: 缓存 ID
    /// - Returns: 缓存大小（字节）
    public func getCacheSize(for cacheID: String) -> Int64 {
        let cacheDir = cacheDirectory.appendingPathComponent(cacheID)
        return calculateDirectorySize(at: cacheDir)
    }

    private func calculateDirectorySize(at url: URL) -> Int64 {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: []) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resourceValues.fileSize {
                totalSize += Int64(fileSize)
            }
        }
        return totalSize
    }

    // MARK: - Private Implementation

    /// 加载持久化页面的主流程
    private func loadPersistentPage(
        url: URL,
        in webView: WKWebView,
        from viewController: UIViewController?
    ) async throws {
        NSLog("🔄 [PersistentManifestLoader] 开始加载持久化页面")
        NSLog("   URL: %@", url.absoluteString)
        updateState(.fetchingManifest)

        // 1. 下载 manifest.json
        NSLog("📥 [PersistentManifestLoader] 步骤 1: 下载 manifest.json")
        let manifest = try await fetchManifest(from: url)
        NSLog("✅ [PersistentManifestLoader] manifest.json 下载成功")
        NSLog("   persistent: \(manifest.persistent)")
        NSLog("   资源数量: \(manifest.resources.count)")
        NSLog("   版本: \(manifest.resolvedVersion)")
        NSLog("   AppID: \(manifest.appid ?? "使用域名")")
        NSLog("   名称: \(manifest.name ?? "未设置")")

        // 2. 检查是否启用持久化
        guard manifest.persistent else {
            NSLog("❌ [PersistentManifestLoader] persistent=false，取消持久化加载")
            updateState(.failed(LoaderError.persistentModeDisabled))
            throw LoaderError.persistentModeDisabled
        }

        // 3. 生成缓存 ID（使用 AppID）
        NSLog("🆔 [PersistentManifestLoader] 步骤 2: 生成缓存 ID (基于 AppID)")
        let cacheID = generateCacheID(for: url, manifest: manifest)
        
        // 记录 URL 到 CacheID 的映射
        urlMappingLock.lock()
        urlToAppID[url] = cacheID
        urlMappingLock.unlock()
        
        NSLog("   缓存 ID: %@", cacheID)
        let cacheDir = cacheDirectory.appendingPathComponent(cacheID)
        NSLog("   缓存目录: %@", cacheDir.path)

        // 4. 创建缓存目录
        NSLog("📁 [PersistentManifestLoader] 步骤 3: 创建缓存目录")
        try createCacheDirectory(at: cacheDir)
        NSLog("✅ [PersistentManifestLoader] 缓存目录创建成功")

        // ✅ 5. 检查是否已经缓存（跳过进度页面）
        let htmlPath = cacheDir.appendingPathComponent("index.html")
        let manifestPath = cacheDir.appendingPathComponent("manifest.json")

        if FileManager.default.fileExists(atPath: htmlPath.path),
           FileManager.default.fileExists(atPath: manifestPath.path) {
            NSLog("♻️ [PersistentManifestLoader] 发现完整缓存，跳过下载")

            // 直接从缓存加载
            if let html = try? String(contentsOfFile: htmlPath.path, encoding: .utf8) {
                // ✅ 确保 ManifestStore 中也有这份数据（用于 UI 显示）
                var finalManifest: Manifest
                if let existing = ManifestStore.shared.getManifest(for: cacheID) {
                    // 保留现有用户设置
                    finalManifest = Manifest(
                        resources: manifest.resources,
                        version: manifest.version,
                        lastUpdated: Date(),
                        appid: manifest.appid,
                        name: manifest.name,
                        icon: manifest.icon,
                        isPinned: existing.isPinned,
                        isFavorite: existing.isFavorite,
                        lastAccessed: Date(),
                        accessCount: (existing.accessCount ?? 0) + 1
                    )
                } else {
                    finalManifest = Manifest(
                        resources: manifest.resources,
                        version: manifest.version,
                        lastUpdated: Date(),
                        appid: manifest.appid,
                        name: manifest.name,
                        icon: manifest.icon,
                        isPinned: false,
                        isFavorite: false,
                        lastAccessed: Date(),
                        accessCount: 1
                    )
                }
                ManifestStore.shared.saveManifest(finalManifest, for: cacheID)
                ManifestStore.shared.saveHTML(html, for: cacheID)

                await registerManifest(manifest, for: cacheID, in: webView)
                try await loadHTML(html, cacheID: cacheID, in: webView)
                
                // 🔥 发送通知用于 UI 更新
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .manifestCacheHit,
                        object: nil,
                        userInfo: ["source": "MANIFEST"]
                    )
                }
                
                NSLog("✅ [PersistentManifestLoader] 从缓存加载完成")
                return
            }
        }

        // 6. 没有缓存，显示进度页面
        NSLog("📦 [PersistentManifestLoader] 未缓存，开始下载资源")
        let totalResources = manifest.resources.count
        
        var modal: FullScreenProgressViewController?
        if let vc = viewController {
            modal = await showProgressModal(
                from: vc,
                description: manifest.name ?? "正在缓存页面资源",
                totalResources: totalResources
            )
        }

        // 7. 下载 HTML
        updateState(.downloadingResources(current: 0, total: totalResources))
        let html = try await downloadHTML(from: url)

        // 8. 下载所有资源
        let baseURL = url.deletingLastPathComponent()
        try await downloadAllResources(
            manifest: manifest,
            cacheID: cacheID,
            cacheDir: cacheDir,
            baseURL: baseURL
        ) { [weak modal] current, total, resourceName in
            modal?.updateProgress(current: current, total: total, message: "正在下载", resourceName: resourceName)
        }

        // 9. 保存 HTML
        try saveHTML(html, to: cacheDir)

        // 10. 保存 manifest
        try saveManifest(manifest, to: cacheDir)
        
        // ✅ 10b. 注册到 ManifestStore（用于首页展示）
        var finalManifest: Manifest
        if let existing = ManifestStore.shared.getManifest(for: cacheID) {
            finalManifest = Manifest(
                resources: manifest.resources,
                version: manifest.version,
                lastUpdated: Date(),
                appid: manifest.appid,
                name: manifest.name,
                icon: manifest.icon,
                isPinned: existing.isPinned,
                isFavorite: existing.isFavorite,
                lastAccessed: Date(),
                accessCount: (existing.accessCount ?? 0) + 1
            )
        } else {
            finalManifest = Manifest(
                resources: manifest.resources,
                version: manifest.version,
                lastUpdated: Date(),
                appid: manifest.appid,
                name: manifest.name,
                icon: manifest.icon,
                isPinned: false,
                isFavorite: false,
                lastAccessed: Date(),
                accessCount: 1
            )
        }
        ManifestStore.shared.saveManifest(finalManifest, for: cacheID)
        ManifestStore.shared.saveHTML(html, for: cacheID)

        // 11. 注册到 URL Scheme Handler
        await registerManifest(manifest, for: cacheID, in: webView)

        // 12. 加载 HTML 到 WebView
        updateState(.loadingWebView)
        try await loadHTML(html, cacheID: cacheID, in: webView)

        // 13. 完成
        updateState(.completed)

        // 延迟关闭弹窗（让用户看到完成状态）
        try? await Task.sleep(nanoseconds: 300_000_000)  // 0.3秒
        await dismissProgressModal()
    }

    /// 下载 manifest.json
    public func fetchManifest(from url: URL) async throws -> WebManifest {
        // 🔥 修复：如果 URL 看起来像是一个 HTML 文件，先取其父目录
        var baseURL = url
        if url.pathExtension.lowercased() == "html" || url.pathExtension.lowercased() == "htm" {
            baseURL = url.deletingLastPathComponent()
        }
        
        let manifestURL = baseURL.appendingPathComponent(manifestFileName)
        print("📡 [PersistentManifestLoader] 请求 manifest.json")
        print("   完整 URL: \(manifestURL.absoluteString)")

        return try await withCheckedThrowingContinuation { continuation in
            let task = urlSession.dataTask(with: manifestURL) { data, response, error in
                if let error = error {
                    print("❌ [PersistentManifestLoader] 请求失败 (网络错误)")
                    print("   错误: \(error)")
                    if let urlError = error as? URLError {
                        print("   URLError 代码: \(urlError.code.rawValue)")
                        print("   URLError 描述: \(urlError.localizedDescription)")
                        if let failURL = urlError.failureURLString {
                            print("   失败的 URL: \(failURL)")
                        }
                    }
                    continuation.resume(throwing: LoaderError.htmlDownloadFailed(error))
                    return
                }

                guard let data = data else {
                    print("❌ [PersistentManifestLoader] 数据为空")
                    continuation.resume(throwing: LoaderError.manifestNotFound)
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    print("📊 [PersistentManifestLoader] 响应状态码: \(httpResponse.statusCode)")
                    if httpResponse.statusCode != 200 {
                        print("❌ [PersistentManifestLoader] HTTP 错误: \(httpResponse.statusCode)")
                        continuation.resume(throwing: LoaderError.htmlDownloadFailed(NSError(
                            domain: "HTTP",
                            code: httpResponse.statusCode,
                            userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"]
                        )))
                        return
                    }
                }

                do {
                    let manifest = try JSONDecoder().decode(WebManifest.self, from: data)
                    print("✅ [PersistentManifestLoader] manifest.json 解析成功")
                    continuation.resume(returning: manifest)
                } catch {
                    print("❌ [PersistentManifestLoader] JSON 解析失败")
                    print("   解析错误: \(error)")
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("   原始 JSON (前 500 字符):")
                        print("   \(String(jsonString.prefix(500)))")
                    }
                    continuation.resume(throwing: LoaderError.invalidManifestFormat)
                }
            }

            task.resume()
        }
    }

    /// 下载 HTML
    private func downloadHTML(from url: URL) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let task = urlSession.dataTask(with: url) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: LoaderError.htmlDownloadFailed(error))
                    return
                }

                guard let data = data,
                      let html = String(data: data, encoding: .utf8) else {
                    continuation.resume(throwing: LoaderError.htmlDownloadFailed(LoaderError.invalidManifestFormat))
                    return
                }

                continuation.resume(returning: html)
            }

            task.resume()
        }
    }

    /// 下载所有资源
    private func downloadAllResources(
        manifest: WebManifest,
        cacheID: String,
        cacheDir: URL,
        baseURL: URL,
        progress: @escaping (Int, Int, String) -> Void
    ) async throws {
        let resources = Array(manifest.resources.enumerated())
        let total = resources.count

        // 用于追踪进度的线程安全计数器
        let progressLock = NSLock()
        var completedCount = 0

        // 使用 TaskGroup 并发下载
        try await withThrowingTaskGroup(of: (Int, String).self) { group in
            for (index, (relativePath, urlString)) in resources {
                group.addTask { [weak self] in
                    guard let self = self else {
                        throw LoaderError.webViewNotAvailable
                    }

                    // ✅ 处理相对路径资源 URL
                    guard let url = URL(string: urlString, relativeTo: baseURL) else {
                        throw LoaderError.resourceDownloadFailed(relativePath, LoaderError.invalidManifestFormat)
                    }

                    // 下载资源
                    let data = try await self.downloadResource(from: url)

                    // 保存到缓存
                    let localPath = self.getLocalPath(for: relativePath, in: cacheDir)
                    try self.saveResource(data, to: localPath)

                    return (index + 1, relativePath)
                }
            }

            // 收集完成的任务并更新进度
            for try await (completedIndex, resourceName) in group {
                progressLock.lock()
                completedCount += 1
                let current = completedCount
                progressLock.unlock()

                // ⚠️ 确保进度更新在主线程执行
                await MainActor.run {
                    progress(current, total, resourceName)
                }
            }
        }
    }

    /// 下载单个资源
    private func downloadResource(from url: URL) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            let task = urlSession.dataTask(with: url) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let data = data else {
                    continuation.resume(throwing: LoaderError.resourceDownloadFailed(url.lastPathComponent, LoaderError.invalidManifestFormat))
                    return
                }

                continuation.resume(returning: data)
            }

            // 保存任务引用以便取消
            tasksLock.lock()
            downloadTasks.append(task)
            tasksLock.unlock()

            task.resume()
        }
    }

    /// 保存资源到本地
    private func saveResource(_ data: Data, to path: URL) throws {
        // 创建父目录
        let directory = path.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // 写入文件
        try data.write(to: path)
    }

    /// 保存 HTML
    private func saveHTML(_ html: String, to cacheDir: URL) throws {
        let htmlPath = cacheDir.appendingPathComponent("index.html")
        try html.write(to: htmlPath, atomically: true, encoding: .utf8)
        
        // ✅ 同步更新 ManifestStore
        let cacheID = cacheDir.lastPathComponent
        ManifestStore.shared.saveHTML(html, for: cacheID)
    }

    /// 保存 manifest
    private func saveManifest(_ manifest: WebManifest, to cacheDir: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(manifest)
        let manifestPath = cacheDir.appendingPathComponent(manifestFileName)
        try data.write(to: manifestPath)

        // ✅ 同步更新 ManifestStore，确保 UI 能够实时更新
        let cacheID = cacheDir.lastPathComponent
        
        // 尝试获取现有 Manifest 以保留用户字段（如 isPinned, isFavorite, accessCount）
        var coreManifest: Manifest
        if let existing = ManifestStore.shared.getManifest(for: cacheID) {
            coreManifest = existing
            coreManifest.resources = manifest.resources
            coreManifest.version = manifest.version
            coreManifest.lastUpdated = Date()
            coreManifest.appid = manifest.appid ?? existing.appid
            coreManifest.name = manifest.name ?? existing.name
            coreManifest.icon = manifest.icon ?? existing.icon
        } else {
            coreManifest = Manifest(
                resources: manifest.resources,
                version: manifest.version,
                lastUpdated: Date(),
                appid: manifest.appid,
                name: manifest.name,
                icon: manifest.icon
            )
        }
        
        ManifestStore.shared.saveManifest(coreManifest, for: cacheID)
        NSLog("✅ [PersistentManifestLoader] 已同步更新 ManifestStore: %@", cacheID)
    }

    /// 加载 HTML 到 WebView
    private func loadHTML(_ html: String, cacheID: String, in webView: WKWebView) async throws {
        // 构建入口 URL (wb-resource://{cacheID}/index.html)
        // 使用自定义 Scheme URL 触发 SchemeHandler 拦截，这样主页面和资源都通过 SchemeHandler 加载
        guard let entryURL = URL(string: "\(scheme)://\(cacheID)/index.html") else {
            throw LoaderError.invalidManifestFormat
        }

        NSLog("🌐 [PersistentManifestLoader] 加载入口页面: %@", entryURL.absoluteString)

        // 在主线程加载
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                webView.load(URLRequest(url: entryURL))
                continuation.resume()
            }
        }
    }

    /// 注册 manifest 到 URL Scheme Handler
    private func registerManifest(_ manifest: WebManifest, for cacheID: String, in webView: WKWebView) async {
        // 这里需要与 ManifestURLSchemeHandler 集成
        // 将 manifest 注册到 scheme handler，以便它能够拦截 wb-resource:// 请求
        await MainActor.run {
            if let schemeHandler = webView.configuration.urlSchemeHandler(forURLScheme: scheme) as? ManifestURLSchemeHandler {
                schemeHandler.registerManifest(forPage: cacheID, manifest: manifest.resources)
            }
        }
    }

    // MARK: - Progress Modal

    @MainActor
    private func showProgressModal(
        from viewController: UIViewController,
        description: String,
        totalResources: Int
    ) -> FullScreenProgressViewController {
        let modal = FullScreenProgressViewController(totalResources: totalResources)
        modal.modalPresentationStyle = .fullScreen
        viewController.present(modal, animated: false)

        self.progressModal = modal
        return modal
    }

    @MainActor
    private func dismissProgressModal() async {
        progressModal?.dismissWithAnimation {
            // Animation complete
        }
        progressModal = nil
    }

    // MARK: - Helper Methods

    private func generateCacheID(for url: URL) -> String {
        // 使用 URL host 作为回退方案
        return AppIDResolver.resolveAppID(from: url, manifest: nil)
    }

    /// 基于 manifest 生成 cache ID（使用 AppID）
    /// - Parameters:
    ///   - url: 页面 URL
    ///   - manifest: Web Manifest（可能包含 appid）
    /// - Returns: 缓存 ID
    private func generateCacheID(for url: URL, manifest: WebManifest) -> String {
        // 将 WebManifest 转换为框架内部 Manifest 以便解析
        let coreManifest = Manifest(
            resources: manifest.resources,
            version: manifest.version,
            appid: manifest.appid
        )
        return AppIDResolver.resolveAppID(from: url, manifest: coreManifest)
    }

    private func getLocalPath(for relativePath: String, in cacheDir: URL) -> URL {
        return cacheDir.appendingPathComponent(relativePath)
    }

    private func createCacheDirectoryIfNeeded() {
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    private func createCacheDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private func updateState(_ newState: LoadingState) {
        stateLock.lock()
        defer { stateLock.unlock() }
        loadingState = newState
    }

    public func getCurrentState() -> LoadingState {
        stateLock.lock()
        defer { stateLock.unlock() }
        return loadingState
    }

    // MARK: - Cancellation

    private func cancelDownloads() {
        tasksLock.lock()
        let tasks = downloadTasks
        downloadTasks.removeAll()
        tasksLock.unlock()

        for task in tasks {
            task.cancel()
        }

        updateState(.failed(LoaderError.resourceDownloadFailed("Cancelled", NSError(domain: "PersistentManifestLoader", code: -999))))
    }

    // MARK: - Cache Management

    /// 清除指定页面的缓存
    public func clearCache(for url: URL) {
        let cacheID = generateCacheID(for: url)
        let cacheDir = cacheDirectory.appendingPathComponent(cacheID)

        try? FileManager.default.removeItem(at: cacheDir)
        print("🗑️ [PersistentManifestLoader] Cleared cache for: \(url.absoluteString)")
    }

    /// 清除所有缓存
    public func clearAllCache() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            try? FileManager.default.removeItem(at: self.cacheDirectory)
            self.createCacheDirectoryIfNeeded()
            print("🗑️ [PersistentManifestLoader] Cleared all cache (async)")
        }
    }

    /// 获取缓存大小
    public func getCacheSize() -> Int64 {
        guard let enumerator = FileManager.default.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resourceValues.fileSize {
                totalSize += Int64(fileSize)
            }
        }

        return totalSize
    }

    /// 检查页面是否已缓存
    public func isCached(url: URL) -> Bool {
        // 1. 优先从映射中获取 AppID
        urlMappingLock.lock()
        let mappedAppID = urlToAppID[url]
        urlMappingLock.unlock()
        
        if let appID = mappedAppID {
            let cacheDir = cacheDirectory.appendingPathComponent(appID)
            let manifestPath = cacheDir.appendingPathComponent(manifestFileName)
            if FileManager.default.fileExists(atPath: manifestPath.path) {
                return true
            }
        }
        
        // 2. 如果映射中没有，尝试使用默认 AppID (host-based)
        let cacheID = generateCacheID(for: url)
        let cacheDir = cacheDirectory.appendingPathComponent(cacheID)
        let manifestPath = cacheDir.appendingPathComponent(manifestFileName)
        
        guard FileManager.default.fileExists(atPath: manifestPath.path) else {
            return false
        }
        
        // 进一步检查是否是持久化模式
        do {
            let data = try Data(contentsOf: manifestPath)
            let manifest = try JSONDecoder().decode(WebManifest.self, from: data)
            
            // 如果成功找到并确认是持久化，记录到映射中
            if manifest.persistent {
                let appID = AppIDResolver.resolveAppID(from: url, manifest: Manifest(resources: manifest.resources, version: manifest.version, appid: manifest.appid))
                urlMappingLock.lock()
                urlToAppID[url] = appID
                urlMappingLock.unlock()
                return true
            }
            return false
        } catch {
            return false
        }
    }

    /// 从缓存加载页面（如果已缓存）
    public func loadFromCache(
        url: URL,
        in webView: WKWebView,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let cacheID = generateCacheID(for: url)
        let cacheDir = cacheDirectory.appendingPathComponent(cacheID)
        let htmlPath = cacheDir.appendingPathComponent("index.html")
        let manifestPath = cacheDir.appendingPathComponent(manifestFileName)

        guard FileManager.default.fileExists(atPath: htmlPath.path),
              FileManager.default.fileExists(atPath: manifestPath.path) else {
            completion(.failure(LoaderError.manifestNotFound))
            return
        }

        do {
            // 读取 HTML
            let html = try String(contentsOf: htmlPath, encoding: .utf8)

            // 读取 manifest
            let manifestData = try Data(contentsOf: manifestPath)
            let manifest = try JSONDecoder().decode(WebManifest.self, from: manifestData)

            // 注册 manifest
            Task { @MainActor in
                await registerManifest(manifest, for: cacheID, in: webView)

                // 加载 HTML
                guard let baseURL = URL(string: "\(scheme)://\(cacheID)/") else {
                    completion(.failure(LoaderError.invalidManifestFormat))
                    return
                }

                webView.loadHTMLString(html, baseURL: baseURL)
                completion(.success(()))
            }
        } catch {
            completion(.failure(error))
        }
    }
}
