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

    // MARK: - Types (defined in ManifestLoader/ManifestLoaderTypes.swift)
    //
    // Nested types are declared in extensions within:
    //   - ManifestLoaderTypes.swift       (LoaderError, WebManifest, LoadingState)
    //   - ManifestDownloadService.swift   (download & save methods)
    //   - ManifestProgressUI.swift        (progress modal & WebView methods)

    // MARK: - Properties

    let urlSession: URLSession
    let cacheDirectory: URL
    public let scheme = "wb-resource"
    let manifestFileName = "manifest.json"

    var progressModal: FullScreenProgressViewController?
    private var loadingState: LoadingState = .idle
    private let stateLock = NSLock()

    var downloadTasks: [URLSessionDataTask] = []
    let tasksLock = NSLock()

    var urlToAppID: [URL: String] = [:]
    let urlMappingLock = NSLock()

    // MARK: - Singleton

    public static let shared = PersistentManifestLoader()

    // MARK: - Initialization

    private override init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        config.httpMaximumConnectionsPerHost = 6
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        ]
        self.urlSession = URLSession(configuration: config)

        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.cacheDirectory = cachesDir.appendingPathComponent("WebBridgeKit/PersistentCache")

        super.init()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleClearAllCaches),
            name: .clearAllCaches,
            object: nil
        )
    }

    @objc private func handleClearAllCaches() {
        clearAllCache()
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

        urlMappingLock.withLock {
            urlToAppID[url] = cacheID
        }

        NSLog("   缓存 ID: %@", cacheID)
        let cacheDir = cacheDirectory.appendingPathComponent(cacheID)
        NSLog("   缓存目录: %@", cacheDir.path)

        // 4. 创建缓存目录
        NSLog("📁 [PersistentManifestLoader] 步骤 3: 创建缓存目录")
        try createCacheDirectory(at: cacheDir)
        NSLog("✅ [PersistentManifestLoader] 缓存目录创建成功")

        // 5. 检查是否已经缓存（跳过进度页面）
        let htmlPath = cacheDir.appendingPathComponent("index.html")
        let manifestPath = cacheDir.appendingPathComponent("manifest.json")

        if FileManager.default.fileExists(atPath: htmlPath.path),
           FileManager.default.fileExists(atPath: manifestPath.path) {
            NSLog("♻️ [PersistentManifestLoader] 发现完整缓存，跳过下载")

            if let html = try? String(contentsOfFile: htmlPath.path, encoding: .utf8) {
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

                await registerManifest(manifest, for: cacheID, in: webView)
                try await loadHTML(html, cacheID: cacheID, in: webView)

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

        // 10b. 注册到 ManifestStore（用于首页展示）
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

        try? await Task.sleep(nanoseconds: 300_000_000)
        await dismissProgressModal()
    }

    // MARK: - Helper Methods

    private func generateCacheID(for url: URL) -> String {
        return AppIDResolver.resolveAppID(from: url, manifest: nil)
    }

    /// 基于 manifest 生成 cache ID（使用 AppID）
    /// - Parameters:
    ///   - url: 页面 URL
    ///   - manifest: Web Manifest（可能包含 appid）
    /// - Returns: 缓存 ID
    private func generateCacheID(for url: URL, manifest: WebManifest) -> String {
        let coreManifest = Manifest(
            resources: manifest.resources,
            version: manifest.version,
            appid: manifest.appid
        )
        return AppIDResolver.resolveAppID(from: url, manifest: coreManifest)
    }

    func getLocalPath(for relativePath: String, in cacheDir: URL) -> URL {
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

        let cacheID = generateCacheID(for: url)
        let cacheDir = cacheDirectory.appendingPathComponent(cacheID)
        let manifestPath = cacheDir.appendingPathComponent(manifestFileName)

        guard FileManager.default.fileExists(atPath: manifestPath.path) else {
            return false
        }

        do {
            let data = try Data(contentsOf: manifestPath)
            let manifest = try JSONDecoder().decode(WebManifest.self, from: data)

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
            let html = try String(contentsOf: htmlPath, encoding: .utf8)

            let manifestData = try Data(contentsOf: manifestPath)
            let manifest = try JSONDecoder().decode(WebManifest.self, from: manifestData)

            Task { @MainActor in
                await registerManifest(manifest, for: cacheID, in: webView)

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
