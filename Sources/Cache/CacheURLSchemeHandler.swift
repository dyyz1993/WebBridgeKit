//
//  CacheURLSchemeHandler.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-15.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import WebKit

// Framework imports

/// Bark自定义缓存URL Scheme处理器
/// 拦截 bark-cache:// 请求，从本地文件系统读取缓存的资源
/// 支持两种格式：
/// 1. bark-cache://{uuid}/path - 离线页面缓存
/// 2. bark-cache://{key} - 压缩资源缓存
public class CacheURLSchemeHandler: NSObject, WKURLSchemeHandler {

    private let queue = DispatchQueue(label: "com.bark.cache.scheme", qos: .userInitiated)

    // 访问统计
    private var accessStats: [String: Int] = [:]
    private var lastAccessTime: [String: Date] = [:]
    private let statsLock = NSLock()

    // MARK: - WKURLSchemeHandler

    public func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        queue.async { [weak self] in
            self?.handleSchemeTask(urlSchemeTask)
        }
    }

    public func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        // 任务被取消，无需特殊处理
    }

    // MARK: - Private

    private func handleSchemeTask(_ urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }

        WebBridgeLogger.shared.log(.debug, "📦 CacheScheme: \(url.absoluteString)")

        // 记录访问
        recordAccess(for: url)

        // 检查是否是压缩缓存格式 (bark-cache://{key} - 没有路径)
        if url.path.isEmpty || url.path == "/" {
            let key = url.host ?? ""
            serveFromCompressedCache(key: key, url: url, urlSchemeTask: urlSchemeTask)
        } else {
            // 离线页面缓存格式 (bark-cache://{uuid}/path/to/resource)
            serveFromOfflineCache(uuid: url.host ?? "", resourcePath: url.path, url: url, urlSchemeTask: urlSchemeTask)
        }
    }

    /// 从压缩缓存读取
    private func serveFromCompressedCache(key: String, url: URL, urlSchemeTask: WKURLSchemeTask) {
        if let (data, mimeType) = WebCompressedCacheStore.shared.load(key: key) {
            // 更新命中统计
            updateHitStats(for: key)

            deliverResponse(data: data, mimeType: mimeType, url: url, urlSchemeTask: urlSchemeTask)
            WebBridgeLogger.shared.log(.debug, "✅ Served from compressed cache: \(key)")
        } else {
            // 未找到，尝试离线缓存
            WebBridgeLogger.shared.log(.warning, "⚠️ Not in compressed cache, trying offline cache")
            serveFromOfflineCache(uuid: key, resourcePath: "/index.html", url: url, urlSchemeTask: urlSchemeTask)
        }
    }

    /// 从离线页面缓存读取
    private func serveFromOfflineCache(uuid: String, resourcePath: String, url: URL, urlSchemeTask: WKURLSchemeTask) {
        // 获取本地文件路径
        let localPath = getLocalCachePath(uuid: uuid, resourcePath: resourcePath)

        do {
            let fileData = try Data(contentsOf: localPath)
            let mimeType = getMimeType(forPath: resourcePath)

            deliverResponse(data: fileData, mimeType: mimeType, url: url, urlSchemeTask: urlSchemeTask)

            WebBridgeLogger.shared.log(.debug, "✅ Served cached resource: \(resourcePath)")
        } catch {
            WebBridgeLogger.shared.log(.error, "❌ Failed to read cached resource: \(localPath.path) - \(error.localizedDescription)")
            urlSchemeTask.didFailWithError(error)
        }
    }

    /// 发送 HTTP 响应
    private func deliverResponse(data: Data, mimeType: String, url: URL, urlSchemeTask: WKURLSchemeTask) {
        // 构造HTTP响应
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": mimeType,
                "Cache-Control": "max-age=31536000", // 1年
                "Access-Control-Allow-Origin": "*",
                "X-Cache-Status": "HIT"
            ]
        )!

        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    /// 记录访问
    private func recordAccess(for url: URL) {
        statsLock.lock()
        defer { statsLock.unlock() }

        let key = url.absoluteString
        accessStats[key, default: 0] += 1
        lastAccessTime[key] = Date()
    }

    /// 更新命中统计
    private func updateHitStats(for key: String) {
        statsLock.lock()
        defer { statsLock.unlock() }

        // 压缩缓存的命中统计在 WebCompressedCacheStore 内部处理
        // 这里可以添加额外的统计逻辑
    }

    /// 获取访问统计
    public func getAccessStats() -> [String: (count: Int, lastAccess: Date)] {
        statsLock.lock()
        defer { statsLock.unlock() }

        var result: [String: (count: Int, lastAccess: Date)] = [:]
        for (key, count) in accessStats {
            result[key] = (count, lastAccessTime[key] ?? Date.distantPast)
        }
        return result
    }

    /// 获取本地缓存文件路径
    private func getLocalCachePath(uuid: String, resourcePath: String) -> URL {
        let cacheBase = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let cacheDir = cacheBase.appendingPathComponent("WebPageCache").appendingPathComponent(uuid)

        // 根路径返回index.html
        if resourcePath == "/" || resourcePath.isEmpty {
            return cacheDir.appendingPathComponent("index.html")
        }

        return cacheDir.appendingPathComponent(resourcePath)
    }

    /// 根据文件扩展名获取MIME类型
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
        case "eot":
            return "application/vnd.ms-fontobject"
        case "mp4":
            return "video/mp4"
        case "webm":
            return "video/webm"
        case "mp3":
            return "audio/mpeg"
        case "wav":
            return "audio/wav"
        case "pdf":
            return "application/pdf"
        default:
            return "application/octet-stream"
        }
    }
}
