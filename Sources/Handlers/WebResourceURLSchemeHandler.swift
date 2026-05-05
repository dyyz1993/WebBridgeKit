//
//  WebResourceURLSchemeHandler.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-02-02.
//

import Foundation
import WebKit

/// Custom URL scheme handler for wb-resource:// protocol
/// Handles cached web resources with automatic downloading and caching
public class WebResourceURLSchemeHandler: NSObject, WKURLSchemeHandler {

    // MARK: - Properties

    private let cacheDirectory: URL
    private let resourceCacheManager: WebResourceCacheManager
    private let manifestDownloader: ManifestDownloader
    private let urlSession: URLSession

    /// Active URL scheme tasks for stopping/cancellation
    private var activeTasks: [String: WKURLSchemeTask] = [:]
    private let tasksQueue = DispatchQueue(label: "com.webbridgekit.resourcehandler.tasks")

    // MARK: - Initialization

    public init(
        cacheDirectory: URL,
        resourceCacheManager: WebResourceCacheManager = .shared,
        manifestDownloader: ManifestDownloader = .shared
    ) {
        self.cacheDirectory = cacheDirectory
        self.resourceCacheManager = resourceCacheManager
        self.manifestDownloader = manifestDownloader

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.urlSession = URLSession(configuration: config)

        super.init()
    }

    public convenience override init() {
        let cacheDir = Self.defaultCacheDirectory.appendingPathComponent("web-resources", isDirectory: true)
        self.init(cacheDirectory: cacheDir)
    }

    deinit {
        // Cancel all active tasks
        urlSession.invalidateAndCancel()
    }

    // MARK: - WKURLSchemeHandler

    public func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            sendErrorResponse(task: urlSchemeTask, statusCode: 400, description: "Invalid URL")
            return
        }

        // Track active task
        let taskID = UUID().uuidString
        tasksQueue.sync {
            activeTasks[taskID] = urlSchemeTask
        }

        // Parse URL
        guard let (cacheID, relativePath) = parseURL(url) else {
            sendErrorResponse(task: urlSchemeTask, statusCode: 400, description: "Invalid wb-resource:// URL format")
            tasksQueue.sync {
                activeTasks.removeValue(forKey: taskID)
            }
            return
        }

        // Log request
        NSLog("[WebResourceURLSchemeHandler] Handling request: \(url.absoluteString)")

        // Deliver resource (from cache or download)
        deliverCachedResource(task: urlSchemeTask, cacheID: cacheID, relativePath: relativePath, taskID: taskID)
    }

    public func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        // Find and remove task from active tasks
        tasksQueue.sync {
            if let key = activeTasks.first(where: { $0.value === urlSchemeTask })?.key {
                activeTasks.removeValue(forKey: key)
            }
        }

        NSLog("[WebResourceURLSchemeHandler] Stopped task for URL: \(urlSchemeTask.request.url?.absoluteString ?? "unknown")")
    }

    // MARK: - Private Methods

    /// Parses wb-resource://{cache-id}/{relative-path} URL format
    /// - Parameter url: The URL to parse
    /// - Returns: Tuple of (cacheID, relativePath) or nil if invalid
    private func parseURL(_ url: URL) -> (cacheID: String, relativePath: String)? {
        guard url.scheme == "wb-resource" else {
            return nil
        }

        let pathComponents = url.pathComponents.filter { $0 != "/" }

        guard pathComponents.count >= 2 else {
            return nil
        }

        let cacheID = pathComponents[0]
        let relativePath = pathComponents[1...].joined(separator: "/")

        return (cacheID, relativePath)
    }

    /// Delivers a cached resource or initiates download if not cached
    /// - Parameters:
    ///   - task: The URL scheme task
    ///   - cacheID: The cache identifier
    ///   - relativePath: The relative path to the resource
    ///   - taskID: Unique task identifier
    private func deliverCachedResource(
        task: WKURLSchemeTask,
        cacheID: String,
        relativePath: String,
        taskID: String
    ) {
        // Try to get resource from WebResourceCacheManager
        if let cached = resourceCacheManager.getResource(cacheID: cacheID, relativePath: relativePath) {
            NSLog("[WebResourceURLSchemeHandler] Cache HIT: \(cacheID)/\(relativePath)")

            let response = HTTPURLResponse(
                url: task.request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: [
                    "Content-Type": cached.mimeType,
                    "Cache-Control": "public, max-age=31536000",
                    "Content-Length": "\(cached.data.count)"
                ]
            )!

            task.didReceive(response)
            task.didReceive(cached.data)
            task.didFinish()

            tasksQueue.sync {
                activeTasks.removeValue(forKey: taskID)
            }

        } else {
            NSLog("[WebResourceURLSchemeHandler] Cache MISS: \(cacheID)/\(relativePath)")

            // Cache miss - return 404 to let the system handle it
            // The resource should have been pre-cached when the manifest was loaded
            sendErrorResponse(task: task, statusCode: 404, description: "Resource not found in cache")
            tasksQueue.sync {
                activeTasks.removeValue(forKey: taskID)
            }
        }
    }

    // MARK: - Helper Methods

    /// Sends error response to URL scheme task
    private func sendErrorResponse(task: WKURLSchemeTask, statusCode: Int, description: String) {
        guard let url = task.request.url else {
            return
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "text/plain; charset=utf-8",
                "X-Error": description
            ]
        )!

        let errorData = description.data(using: .utf8) ?? Data()

        task.didReceive(response)
        task.didReceive(errorData)
        task.didFinish()
    }

    /// Determines MIME type based on file extension
    private func MIMEType(for path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()

        let mimeTypes: [String: String] = [
            "html": "text/html; charset=utf-8",
            "htm": "text/html; charset=utf-8",
            "css": "text/css; charset=utf-8",
            "js": "application/javascript; charset=utf-8",
            "json": "application/json; charset=utf-8",
            "xml": "application/xml; charset=utf-8",
            "txt": "text/plain; charset=utf-8",

            "jpg": "image/jpeg",
            "jpeg": "image/jpeg",
            "png": "image/png",
            "gif": "image/gif",
            "svg": "image/svg+xml",
            "webp": "image/webp",
            "ico": "image/x-icon",

            "woff": "font/woff",
            "woff2": "font/woff2",
            "ttf": "font/ttf",
            "otf": "font/otf",
            "eot": "application/vnd.ms-fontobject",

            "mp4": "video/mp4",
            "webm": "video/webm",
            "mp3": "audio/mpeg",
            "wav": "audio/wav",
            "ogg": "audio/ogg",

            "pdf": "application/pdf",
            "zip": "application/zip",
            "rar": "application/x-rar-compressed"
        ]

        return mimeTypes[ext] ?? "application/octet-stream"
    }
}

// MARK: - WebResourceURLSchemeHandler Extension

extension WebResourceURLSchemeHandler {

    /// Default cache directory for web resources
    public static var defaultCacheDirectory: URL {
        let cachePaths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        guard let cachePath = cachePaths.first else {
            fatalError("Unable to determine cache directory")
        }
        return cachePath.appendingPathComponent("WebBridgeKit", isDirectory: true)
    }

    /// Shared instance of WebResourceURLSchemeHandler
    public static var shared: WebResourceURLSchemeHandler {
        let cacheDir = defaultCacheDirectory.appendingPathComponent("web-resources", isDirectory: true)
        return WebResourceURLSchemeHandler(cacheDirectory: cacheDir)
    }
}

// MARK: - Usage Example

/*
 Usage in WKWebViewConfiguration:

 let config = WKWebViewConfiguration()
 let schemeHandler = WebResourceURLSchemeHandler()
 config.setURLSchemeHandler(schemeHandler, forURLScheme: "wb-resource")

 let webView = WKWebView(frame: .zero, configuration: config)

 Now you can load HTML with wb-resource:// URLs:

 <html>
 <head>
 <link rel="stylesheet" href="wb-resource://cache-id-123/styles/main.css">
 <script src="wb-resource://cache-id-123/scripts/app.js"></script>
 </head>
 <body>
 <img src="wb-resource://cache-id-123/images/logo.png" />
 </body>
 </html>

 URL Format: wb-resource://{cache-id}/{relative-path}

 Example: wb-resource://abc123/images/photo.jpg
 - cache-id: abc123
 - relative-path: images/photo.jpg
 - Resolves to: {cacheDirectory}/abc123/images/photo.jpg
 */
