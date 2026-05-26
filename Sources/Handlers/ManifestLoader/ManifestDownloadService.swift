//
//  ManifestDownloadService.swift
//  WebBridgeKit
//
//  Download & persistence methods for PersistentManifestLoader (split from main file).
//

import Foundation

// MARK: - Download Operations

extension PersistentManifestLoader {

    /// 下载 manifest.json
    public func fetchManifest(from url: URL) async throws -> WebManifest {
        var baseURL = url
        if url.pathExtension.lowercased() == "html" || url.pathExtension.lowercased() == "htm" {
            baseURL = url.deletingLastPathComponent()
        }

        let manifestURL = baseURL.appendingPathComponent(manifestFileName)
        StructuredLogger.shared.debug("[SATELLITE] [PersistentManifestLoader] 请求 manifest.json", category: .handler)
        StructuredLogger.shared.debug("   完整 URL: \(manifestURL.absoluteString)", category: .handler)

        return try await withCheckedThrowingContinuation { continuation in
            let task = urlSession.dataTask(with: manifestURL) { data, response, error in
                if let error = error {
                    StructuredLogger.shared.error("[FAIL] [PersistentManifestLoader] 请求失败 (网络错误)", category: .handler)
                    StructuredLogger.shared.error("   错误: \(error)", category: .handler)
                    if let urlError = error as? URLError {
                        StructuredLogger.shared.error("   URLError 代码: \(urlError.code.rawValue)", category: .handler)
                        StructuredLogger.shared.error("   URLError 描述: \(urlError.localizedDescription)", category: .handler)
                        if let failURL = urlError.failureURLString {
                            StructuredLogger.shared.error("   失败的 URL: \(failURL)", category: .handler)
                        }
                    }
                    continuation.resume(throwing: LoaderError.htmlDownloadFailed(error))
                    return
                }

                guard let data = data else {
                    StructuredLogger.shared.error("[FAIL] [PersistentManifestLoader] 数据为空", category: .handler)
                    continuation.resume(throwing: LoaderError.manifestNotFound)
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    StructuredLogger.shared.debug("[STATS] [PersistentManifestLoader] 响应状态码: \(httpResponse.statusCode)", category: .handler)
                    if httpResponse.statusCode != 200 {
                        StructuredLogger.shared.error("[FAIL] [PersistentManifestLoader] HTTP 错误: \(httpResponse.statusCode)", category: .handler)
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
                    StructuredLogger.shared.info("[OK] [PersistentManifestLoader] manifest.json 解析成功", category: .handler)
                    continuation.resume(returning: manifest)
                } catch {
                    StructuredLogger.shared.error("[FAIL] [PersistentManifestLoader] JSON 解析失败", category: .handler)
                    StructuredLogger.shared.error("   解析错误: \(error)", category: .handler)
                    if let jsonString = String(data: data, encoding: .utf8) {
                        StructuredLogger.shared.debug("   原始 JSON (前 500 字符):", category: .handler)
                        StructuredLogger.shared.debug("   \(String(jsonString.prefix(500)))", category: .handler)
                    }
                    continuation.resume(throwing: LoaderError.invalidManifestFormat)
                }
            }

            task.resume()
        }
    }

    /// 下载 HTML
    func downloadHTML(from url: URL) async throws -> String {
        NSLog("[WEB] [PersistentLoader] downloadHTML 开始: %@", url.absoluteString)
        return try await withCheckedThrowingContinuation { continuation in
            let task = urlSession.dataTask(with: url) { data, response, error in
                if let error = error {
                    NSLog("[WEB] [PersistentLoader] downloadHTML 失败: %@", error.localizedDescription)
                    continuation.resume(throwing: LoaderError.htmlDownloadFailed(error))
                    return
                }

                guard let data = data,
                      let html = String(data: data, encoding: .utf8) else {
                    NSLog("[WEB] [PersistentLoader] downloadHTML: 数据为空或非 UTF-8")
                    continuation.resume(throwing: LoaderError.htmlDownloadFailed(LoaderError.invalidManifestFormat))
                    return
                }

                NSLog("[WEB] [PersistentLoader] downloadHTML 成功: %d bytes, 前200字符: %@", html.count, String(html.prefix(200)))
                continuation.resume(returning: html)
            }

            task.resume()
        }
    }

    /// 下载所有资源
    func downloadAllResources(
        manifest: WebManifest,
        cacheID: String,
        cacheDir: URL,
        baseURL: URL,
        progress: @escaping (Int, Int, String) -> Void
    ) async throws {
        let resources = Array(manifest.resources.enumerated())
        let total = resources.count
        NSLog("[WEB] [PersistentLoader] downloadAllResources: %d 资源, baseURL: %@", total, baseURL.absoluteString)

        let progressLock = NSLock()
        var completedCount = 0

        try await withThrowingTaskGroup(of: (Int, String).self) { group in
            for (index, (relativePath, urlString)) in resources {
                group.addTask { [weak self] in
                    guard let self = self else {
                        throw LoaderError.webViewNotAvailable
                    }

                    guard let url = URL(string: urlString, relativeTo: baseURL) else {
                        throw LoaderError.resourceDownloadFailed(relativePath, LoaderError.invalidManifestFormat)
                    }

                    let data = try await self.downloadResource(from: url)

                    let localPath = self.getLocalPath(for: relativePath, in: cacheDir)
                    try self.saveResource(data, to: localPath)

                    return (index + 1, relativePath)
                }
            }

            for try await (_, resourceName) in group {
                let current = progressLock.withLock {
                    completedCount += 1
                    return completedCount
                }

                await MainActor.run {
                    progress(current, total, resourceName)
                }
            }
        }
    }

    /// 下载单个资源
    func downloadResource(from url: URL) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            let task = urlSession.dataTask(with: url) { data, _, error in
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

            tasksLock.lock()
            downloadTasks.append(task)
            tasksLock.unlock()

            task.resume()
        }
    }

    /// 保存资源到本地
    func saveResource(_ data: Data, to path: URL) throws {
        let directory = path.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: path)
    }

    /// 保存 HTML
    /// - Parameters:
    ///   - html: HTML 内容
    ///   - cacheDir: 目标目录（可能是临时目录或最终缓存目录）
    ///   - cacheID: 缓存 ID，传 nil 则不更新 ManifestStore（用于临时目录写入）
    func saveHTML(_ html: String, to cacheDir: URL, cacheID: String? = nil) throws {
        let htmlPath = cacheDir.appendingPathComponent("index.html")
        try html.write(to: htmlPath, atomically: true, encoding: .utf8)

        if let cacheID = cacheID {
            ManifestStore.shared.saveHTML(html, for: cacheID)
        }
    }

    /// 保存 manifest
    /// - Parameters:
    ///   - manifest: Web Manifest
    ///   - cacheDir: 目标目录（可能是临时目录或最终缓存目录）
    ///   - cacheID: 缓存 ID，传 nil 则不更新 ManifestStore（用于临时目录写入）
    func saveManifest(_ manifest: WebManifest, to cacheDir: URL, cacheID: String? = nil) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(manifest)
        let manifestPath = cacheDir.appendingPathComponent(manifestFileName)
        try data.write(to: manifestPath)

        guard let cacheID = cacheID else { return }

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
        NSLog("[OK] [PersistentManifestLoader] 已同步更新 ManifestStore: %@", cacheID)
    }
}
