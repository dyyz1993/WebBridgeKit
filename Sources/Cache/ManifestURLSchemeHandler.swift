//
//  ManifestURLSchemeHandler.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-02-02.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import WebKit

/// WKURLSchemeHandler 实现
/// 拦截 custom:// 请求，从 manifest.json 查找真实 URL 并返回资源
public class ManifestURLSchemeHandler: NSObject, WKURLSchemeHandler {

    // MARK: - Properties

    private var activeTasks: [String: WKURLSchemeTask] = [:]
    private let taskLock = NSLock()
    private let currentPagesLock = NSLock()
    private var currentPageKeys: [String: String] = [:]  // webViewID -> pageKey

    // MARK: - WKURLSchemeHandler

    public func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(ManifestCacheError.invalidURL)
            return
        }

        NSLog("🔍 [SchemeHandler] Intercepted: %@", url.absoluteString)

        // 检测是否是持久化缓存请求 (wb-resource://{cacheID}/{path})
        let absoluteString = url.absoluteString
        if absoluteString.hasPrefix("wb-resource://") {
            // 提取 cacheID
            let pathWithoutScheme = absoluteString.replacingOccurrences(of: "wb-resource://", with: "")
            if let firstSlashIndex = pathWithoutScheme.firstIndex(of: "/") {
                let cacheID = String(pathWithoutScheme[..<firstSlashIndex])
                NSLog("   - Persistent cache: %@", cacheID)
                handlePersistentRequest(urlSchemeTask, cacheID: cacheID)
                return
            }
        }

        // 懒加载缓存请求 (custom://{path})
        let relativePath = extractRelativePath(from: url)
        let pageKey = getPageKey(for: webView)

        NSLog("   - Lazy cache: %@, pageKey: %@", relativePath, pageKey)
        
        // 保存活跃任务
        let taskID = UUID().uuidString
        saveTask(urlSchemeTask, forID: taskID)

        // 从 ManifestCacheManager 获取资源
        ManifestCacheManager.shared.fetchResource(relativePath: relativePath, for: pageKey) { [weak self] result in
            guard let self = self else {
                urlSchemeTask.didFailWithError(ManifestCacheError.managerDeallocated)
                return
            }

            switch result {
            case .success(let resource):
                NSLog("   ✅ Delivered: %@", relativePath)
                self.deliverResource(resource, to: urlSchemeTask, originalURL: url)
                self.removeTask(forID: taskID)

                // 发送通知用于 UI 更新
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: ManifestCacheManager.cacheHitNotification,
                        object: nil,
                        userInfo: ["relativePath": relativePath, "source": "INTERCEPT"]
                    )
                }

            case .failure(let error):
                NSLog("   ❌ Failed: %@, error: %@", relativePath, error.localizedDescription)
                
                // 🔥 优化：如果是 HTML 页面或主请求失败，显示错误提示页，而不是白屏
                let isPageRequest = relativePath.isEmpty || relativePath.hasSuffix(".html") || relativePath.hasSuffix(".htm")
                if isPageRequest {
                    self.deliverErrorPage(to: urlSchemeTask, url: url, error: error)
                } else {
                    urlSchemeTask.didFailWithError(error)
                }
                self.removeTask(forID: taskID)
            }
        }
    }

    func handlePersistentRequest(_ urlSchemeTask: WKURLSchemeTask, cacheID: String) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(ManifestCacheError.invalidURL)
            return
        }

        // 提取相对路径
        let relativePath = extractRelativePathFromPersistentURL(url, cacheID: cacheID)

        // 从缓存目录读取资源
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WebBridgeKit/PersistentCache")
            .appendingPathComponent(cacheID)
        let resourcePath = cacheDir.appendingPathComponent(relativePath)

        guard FileManager.default.fileExists(atPath: resourcePath.path) else {
            let error = ManifestCacheError.resourceNotFound(relativePath)
            NSLog("❌ [SchemeHandler] Resource not found in cache: %@", relativePath)
            
            // 🔥 优化：如果是 HTML 页面失败，显示错误提示页
            let isPageRequest = relativePath.isEmpty || relativePath.hasSuffix(".html") || relativePath.hasSuffix(".htm")
            if isPageRequest {
                self.deliverErrorPage(to: urlSchemeTask, url: url, error: error)
            } else {
                urlSchemeTask.didFailWithError(error)
            }
            return
        }

        do {
            let data = try Data(contentsOf: resourcePath)
            let mimeType = getMimeType(forPath: relativePath)

            let headers = [
                "Content-Type": mimeType,
                "Cache-Control": "max-age=31536000",  // 缓存1年
                "Content-Length": String(data.count)
            ]

            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: headers
            )!

            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()

            NSLog("✅ [SchemeHandler] Served from persistent cache: %@", relativePath)
            
            // 发送通知用于 UI 更新
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: ManifestCacheManager.cacheHitNotification,
                    object: nil,
                    userInfo: ["relativePath": relativePath, "source": "MANIFEST"]
                )
            }
        } catch {
            NSLog("❌ [SchemeHandler] Failed to read resource: %@", error.localizedDescription)
            urlSchemeTask.didFailWithError(error)
        }
    }

    private func extractRelativePathFromPersistentURL(_ url: URL, cacheID: String) -> String {
        let absoluteString = url.absoluteString
        let prefix = "wb-resource://\(cacheID)/"
        if absoluteString.hasPrefix(prefix) {
            return absoluteString.replacingOccurrences(of: prefix, with: "")
        }
        return url.path.hasPrefix("/") ? String(url.path.dropFirst()) : url.path
    }

    private func getMimeType(forPath path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "html", "htm": return "text/html"
        case "js": return "application/javascript"
        case "css": return "text/css"
        case "json": return "application/json"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        default: return "application/octet-stream"
        }
    }

    public func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        // 找到并移除任务
        taskLock.lock()
        let tasksToRemove = activeTasks.filter { $0.value === urlSchemeTask }
        taskLock.unlock()

        for (taskID, _) in tasksToRemove {
            removeTask(forID: taskID)
        }

        NSLog("⏹️ [SchemeHandler] Stopped task for: %@", urlSchemeTask.request.url?.absoluteString ?? "unknown")
    }

    // MARK: - Page Key Management

    /// 设置 WebView 对应的 pageKey
    public func setPageKey(_ pageKey: String, for webView: WKWebView) {
        currentPagesLock.lock()
        defer { currentPagesLock.unlock() }

        let webViewID = getWebViewID(for: webView)
        currentPageKeys[webViewID] = pageKey

        NSLog("📋 [SchemeHandler] Set pageKey '%@' for WebView", pageKey)
    }

    /// 获取 WebView 对应的 pageKey
    private func getPageKey(for webView: WKWebView) -> String {
        currentPagesLock.lock()
        defer { currentPagesLock.unlock() }

        let webViewID = getWebViewID(for: webView)
        return currentPageKeys[webViewID] ?? "default"
    }

    private func getWebViewID(for webView: WKWebView) -> String {
        return String(format: "%p", unsafeBitCast(webView, to: Int.self))
    }

    // MARK: - Resource Delivery

    private func deliverResource(_ resource: ResourceData, to urlSchemeTask: WKURLSchemeTask, originalURL: URL) {
        let response = HTTPURLResponse(
            url: originalURL,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": resource.mimeType,
                "Access-Control-Allow-Origin": "*",
                "Cache-Control": "no-cache"
            ]
        )

        urlSchemeTask.didReceive(response!)
        urlSchemeTask.didReceive(resource.data)
        urlSchemeTask.didFinish()
        
        NSLog("   ✅ Delivered resource: %@ (%d bytes)", resource.relativePath, resource.data.count)
        
        // 发送通知用于 UI 更新
        NotificationCenter.default.post(
            name: .resourceDelivered,
            object: nil,
            userInfo: ["path": resource.relativePath]
        )
    }

    // MARK: - Task Management

    private func saveTask(_ task: WKURLSchemeTask, forID taskID: String) {
        taskLock.lock()
        defer { taskLock.unlock() }
        activeTasks[taskID] = task
    }

    private func removeTask(forID taskID: String) {
        taskLock.lock()
        defer { taskLock.unlock() }
        activeTasks.removeValue(forKey: taskID)
    }

    // MARK: - Error Feedback

    private func deliverErrorPage(to urlSchemeTask: WKURLSchemeTask, url: URL, error: Error) {
        let errorHTML = generateErrorHTML(url: url, error: error)
        guard let data = errorHTML.data(using: .utf8) else {
            urlSchemeTask.didFailWithError(error)
            return
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: 404, // 使用 404 表示资源缺失
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "text/html",
                "Cache-Control": "no-cache",
                "Access-Control-Allow-Origin": "*"
            ]
        )!

        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
        
        NSLog("⚠️ [SchemeHandler] Delivered error page for: %@", url.absoluteString)
    }

    private func generateErrorHTML(url: URL, error: Error) -> String {
        let urlString = url.absoluteString
        let errorMessage = error.localizedDescription
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>WebBridge 资源加载失败</title>
            <style>
                body { font-family: -apple-system, sans-serif; background-color: #f8f9fa; margin: 0; padding: 20px; color: #2d3748; line-height: 1.5; }
                .container { max-width: 600px; margin: 40px auto; background: white; padding: 30px; border-radius: 12px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); border-top: 6px solid #e53e3e; }
                h1 { color: #c53030; font-size: 22px; margin-top: 0; display: flex; align-items: center; }
                .icon { font-size: 28px; margin-right: 12px; }
                .info-box { background: #fff5f5; border: 1px solid #feb2b2; padding: 15px; border-radius: 8px; margin: 20px 0; word-break: break-all; }
                .label { font-weight: bold; color: #742a2a; display: block; margin-bottom: 5px; font-size: 14px; text-transform: uppercase; letter-spacing: 0.5px; }
                code { background: #edf2f7; padding: 3px 6px; border-radius: 4px; font-family: "SFMono-Regular", Consolas, monospace; font-size: 13px; color: #1a202c; }
                .footer { margin-top: 30px; font-size: 14px; color: #4a5568; border-top: 1px solid #edf2f7; padding-top: 20px; }
                ul { padding-left: 20px; margin-top: 10px; }
                li { margin-bottom: 8px; }
                .btn { display: inline-block; background: #4a5568; color: white; padding: 8px 16px; border-radius: 6px; text-decoration: none; margin-top: 15px; font-size: 14px; }
                .btn:hover { background: #2d3748; }
            </style>
        </head>
        <body>
            <div class="container">
                <h1><span class="icon">🚫</span>WebBridge 资源加载失败</h1>
                <p>在处理自定义协议请求时遇到了错误，无法加载目标资源。</p>
                
                <div class="info-box">
                    <span class="label">请求地址 (Request URL):</span>
                    <code>\(urlString)</code>
                </div>
                
                <div class="info-box">
                    <span class="label">错误原因 (Error):</span>
                    <code>\(errorMessage)</code>
                </div>
                
                <div class="footer">
                    <span class="label">排查建议:</span>
                    <ul>
                        <li>检查 <code>manifest.json</code> 映射表是否包含该相对路径。</li>
                        <li>如果是 <code>wb-resource://</code>，请确认持久化缓存目录中是否存在该文件。</li>
                        <li>确认本地网络连接是否正常（如果是懒加载模式且本地无缓存）。</li>
                        <li>尝试在管理页面清理缓存并重新加载。</li>
                    </ul>
                    <a href="javascript:location.reload()" class="btn">重试加载 (Reload)</a>
                </div>
            </div>
        </body>
        </html>
        """
    }

    // MARK: - URL Parsing

    private func extractRelativePath(from url: URL) -> String {
        let absoluteString = url.absoluteString
        
        // 1. 处理 wb-resource://{cacheID}/{path}
        if absoluteString.hasPrefix("wb-resource://") {
            let pathWithoutScheme = absoluteString.replacingOccurrences(of: "wb-resource://", with: "")
            if let firstSlashIndex = pathWithoutScheme.firstIndex(of: "/") {
                return String(pathWithoutScheme[firstSlashIndex...].dropFirst())
            }
        }

        // 2. 处理 custom://{path}
        if absoluteString.hasPrefix("custom://") {
            // custom://res/style.css -> res/style.css
            // URL(string: "custom://res/style.css")?.path -> "/style.css"
            // URL(string: "custom://res/style.css")?.host -> "res"
            
            let path = url.path
            let host = url.host ?? ""
            
            if !host.isEmpty {
                let fullPath = host + path
                return fullPath.hasPrefix("/") ? String(fullPath.dropFirst()) : fullPath
            }
            return path.hasPrefix("/") ? String(path.dropFirst()) : path
        }
        
        // 3. 后备方案
        return url.path.hasPrefix("/") ? String(url.path.dropFirst()) : url.path
    }

    // MARK: - Cleanup

    /// 清理 WebView 对应的 pageKey
    public func cleanupPage(for webView: WKWebView) {
        currentPagesLock.lock()
        defer { currentPagesLock.unlock() }

        let webViewID = getWebViewID(for: webView)
        currentPageKeys.removeValue(forKey: webViewID)

        NSLog("🗑️ [SchemeHandler] Cleaned up page for WebView")
    }

    // MARK: - Manifest Registration

    /// 为页面注册 Manifest
    /// - Parameters:
    ///   - pageName: 页面名称
    ///   - manifest: 资源清单（相对路径 -> 真实 URL）
    public func registerManifest(forPage pageName: String, manifest: [String: String]) {
        let manifestObj = Manifest(resources: manifest, version: nil, lastUpdated: nil)
        ManifestCacheManager.shared.registerManifest(manifestObj, forPage: pageName)
        NSLog("✅ [SchemeHandler] Registered manifest for page: %@ with %d resources", pageName, manifest.count)
    }

    /// 注销页面的 Manifest
    /// - Parameter pageName: 页面名称
    public func unregisterManifest(forPage pageName: String) {
        ManifestCacheManager.shared.unregisterManifest(forPage: pageName)
        NSLog("🗑️ [SchemeHandler] Unregistered manifest for page: %@", pageName)
    }
}

// MARK: - WKURLSchemeHandler Lifecycle Extension

public extension ManifestURLSchemeHandler {

    /// 为 WebView 配置注册 URL Scheme Handler
    /// - Parameters:
    ///   - configuration: WKWebViewConfiguration
    ///   - scheme: 自定义 URL Scheme（默认 "custom"）
    static func register(to configuration: WKWebViewConfiguration, scheme: String = "custom") {
        let handler = ManifestURLSchemeHandler()
        configuration.setURLSchemeHandler(handler, forURLScheme: scheme)
        NSLog("✅ [SchemeHandler] Registered for scheme: %@://", scheme)
    }
}
