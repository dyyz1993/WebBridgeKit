//
//  ManifestCacheManager+Download.swift
//  WebBridgeKit
//
//  Extracted from ManifestCacheManager.swift
//

import Foundation
import WebKit

extension ManifestCacheManager {

    // MARK: - Resource Fetching & Download

    func fetchResource(relativePath: String, for pageKey: String, completion: @escaping (Result<ResourceData, Error>) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                completion(.failure(ManifestCacheError.managerDeallocated))
                return
            }

            let fileName = (relativePath as NSString).lastPathComponent

            NSLog("⬇️ [\(fileName)] 检查缓存...")

            if let cached = self.resourceCache.get(relativePath, for: pageKey) {
                self.recordCacheHit()
                NSLog("✅ [\(fileName)] 缓存命中 (大小: \(cached.data.count) bytes)")

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

            guard let manifest = self.manifestStore.getCurrentManifest(for: pageKey),
                  let urlString = manifest.resources[relativePath],
                  let url = URL(string: urlString) else {
                NSLog("❌ [\(fileName)] Manifest 中未找到该资源")
                completion(.failure(ManifestCacheError.resourceNotFound(relativePath)))
                return
            }

            NSLog("📥 [\(fileName)] 正在下载...")

            Task {
                do {
                    let resource = try await RetryHelper.executeAsync(maxRetries: 3, delay: 1.0) {
                        try await self.downloadResource(from: url, relativePath: relativePath)
                    }

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

    func downloadResource(from url: URL, relativePath: String) async throws -> ResourceData {
        return try await PerformanceMonitor.shared.measure(
            "ManifestCache.downloadResource",
            metadata: ["relativePath": relativePath, "url": url.absoluteString]
        ) {
            let result: Any = try await RequestDeduplicator.shared.executeResourceDownload(
                urlString: url.absoluteString,
                relativePath: relativePath
            ) {
                try NetworkMonitor.shared.ensureNetworkAvailable()

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

    func performDownload(from url: URL, relativePath: String) async throws -> ResourceData {
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

    // MARK: - Cache Statistics Helpers

    func recordCacheHit() {
        statsLock.lock()
        defer { statsLock.unlock() }
        cacheHits += 1
    }

    func recordCacheMiss() {
        statsLock.lock()
        defer { statsLock.unlock() }
        cacheMisses += 1
    }

    func resetStats() {
        statsLock.lock()
        defer { statsLock.unlock() }
        cacheHits = 0
        cacheMisses = 0
    }

    // MARK: - MIME Type

    func getMimeType(forPath path: String) -> String {
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
}
