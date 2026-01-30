//
//  HTMLResourceParser.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-15.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import CryptoKit

// Framework imports
// 依赖: SwiftSoup (~> 2.6.0) - 需要在 Podfile 中添加

/// 资源类型
enum ResourceType {
    case css
    case js
    case image
    case font
    case media
    case favicon
    case other
}

/// 资源URL信息
struct ResourceURL {
    let originalURL: URL
    let type: ResourceType
    let element: String // link, script, img, etc.
    let attribute: String // href, src, etc.
}

/// HTML资源解析器
/// 使用SwiftSoup解析HTML，提取资源URL并重写为本地路径
class HTMLResourceParser {

    // MARK: - 解析资源

    /// 解析HTML并提取所有资源URL
    /// - Parameters:
    ///   - html: HTML内容
    ///   - baseURL: 基础URL
    /// - Returns: 资源URL列表
    func parseResources(html: String, baseURL: URL) -> [ResourceURL] {
        var resources: [ResourceURL] = []

        // 注意: 这里使用正则表达式作为fallback，实际应使用SwiftSoup
        // 由于SwiftSoup需要CocoaPods依赖，这里先实现基础版本

        // 1. 提取 link 标签 (CSS, favicon)
        resources.append(contentsOf: parseLinkTags(html: html, baseURL: baseURL))

        // 2. 提取 script 标签 (JS)
        resources.append(contentsOf: parseScriptTags(html: html, baseURL: baseURL))

        // 3. 提取 img 标签 (图片)
        resources.append(contentsOf: parseImageTags(html: html, baseURL: baseURL))

        // 4. 提取 video/audio 标签 (媒体)
        resources.append(contentsOf: parseMediaTags(html: html, baseURL: baseURL))

        return deduplicateResources(resources)
    }

    // MARK: - 标签解析

    private func parseLinkTags(html: String, baseURL: URL) -> [ResourceURL] {
        var resources: [ResourceURL] = []

        // 匹配 <link href="...">
        let pattern = #"<link[^>]+href=(["'])([^"']+)\1[^>]*>"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let range = NSRange(html.startIndex..., in: html)

        regex?.enumerateMatches(in: html, options: [], range: range) { match, _, _ in
            guard let match = match,
                  let hrefRange = Range(match.range(at: 2), in: html) else { return }

            let hrefString = String(html[hrefRange])
            let rel = extractRel(from: html, match: match)

            let type: ResourceType
            if rel?.contains("stylesheet") == true {
                type = .css
            } else if rel?.contains("icon") == true {
                type = .favicon
            } else {
                type = .other
            }

            if let url = resolveURL(hrefString, baseURL: baseURL) {
                resources.append(ResourceURL(originalURL: url, type: type, element: "link", attribute: "href"))
            }
        }

        return resources
    }

    private func parseScriptTags(html: String, baseURL: URL) -> [ResourceURL] {
        var resources: [ResourceURL] = []

        // 匹配 <script src="...">
        let pattern = #"<script[^>]+src=(["'])([^"']+)\1[^>]*>"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let range = NSRange(html.startIndex..., in: html)

        regex?.enumerateMatches(in: html, options: [], range: range) { match, _, _ in
            guard let match = match,
                  let srcRange = Range(match.range(at: 2), in: html) else { return }

            let srcString = String(html[srcRange])

            if let url = resolveURL(srcString, baseURL: baseURL) {
                resources.append(ResourceURL(originalURL: url, type: .js, element: "script", attribute: "src"))
            }
        }

        return resources
    }

    private func parseImageTags(html: String, baseURL: URL) -> [ResourceURL] {
        var resources: [ResourceURL] = []

        // 匹配 <img src="..."> 和 <img srcset="...">
        let pattern = #"<img[^>]+src=(["'])([^"']+)\1[^>]*>"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let range = NSRange(html.startIndex..., in: html)

        regex?.enumerateMatches(in: html, options: [], range: range) { match, _, _ in
            guard let match = match,
                  let srcRange = Range(match.range(at: 2), in: html) else { return }

            let srcString = String(html[srcRange])

            if let url = resolveURL(srcString, baseURL: baseURL) {
                resources.append(ResourceURL(originalURL: url, type: .image, element: "img", attribute: "src"))
            }
        }

        return resources
    }

    private func parseMediaTags(html: String, baseURL: URL) -> [ResourceURL] {
        var resources: [ResourceURL] = []

        // 匹配 <video src="..."> 和 <audio src="...">
        let pattern = #"<(video|audio)[^>]+src=(["'])([^"']+)\2[^>]*>"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let range = NSRange(html.startIndex..., in: html)

        regex?.enumerateMatches(in: html, options: [], range: range) { match, _, _ in
            guard let match = match,
                  let srcRange = Range(match.range(at: 3), in: html) else { return }

            let srcString = String(html[srcRange])

            if let url = resolveURL(srcString, baseURL: baseURL) {
                resources.append(ResourceURL(originalURL: url, type: .media, element: "source", attribute: "src"))
            }
        }

        return resources
    }

    // MARK: - URL重写

    /// 重写HTML中的URL为本地路径
    /// - Parameters:
    ///   - html: 原始HTML
    ///   - baseURL: 基础URL
    ///   - uuid: 缓存UUID
    /// - Returns: 重写后的HTML
    func rewriteURLs(html: String, baseURL: URL, uuid: String) -> String {
        var rewritten = html

        // 重写 link href
        rewritten = rewriteLinkTags(rewritten, baseURL: baseURL, uuid: uuid)

        // 重写 script src
        rewritten = rewriteScriptTags(rewritten, baseURL: baseURL, uuid: uuid)

        // 重写 img src
        rewritten = rewriteImageTags(rewritten, baseURL: baseURL, uuid: uuid)

        // 重写 video/audio src
        rewritten = rewriteMediaTags(rewritten, baseURL: baseURL, uuid: uuid)

        return rewritten
    }

    private func rewriteLinkTags(_ html: String, baseURL: URL, uuid: String) -> String {
        let pattern = #"(<link[^>]+href=)(["'])([^"']+)\2([^>]*>)"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])

        guard let regex = regex else { return html }

        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, options: [], range: range)

        var result = html
        var offset = 0

        for match in matches.reversed() {
            guard let htmlRange = Range(match.range, in: html),
                  let urlRange = Range(match.range(at: 3), in: html),
                  let suffixRange = Range(match.range(at: 4), in: html) else {
                continue
            }

            let urlString = String(html[urlRange])
            let suffix = String(html[suffixRange])

            guard let url = resolveURL(urlString, baseURL: baseURL),
                  let localPath = getLocalPath(for: url) else {
                continue
            }

            let replacement = "$1$2bark-cache://\(uuid)\(localPath)$2\(suffix)"
            let replacementRange = NSRange(location: match.range.location + offset, length: match.range.length)

            if let nsRange = Range(replacementRange, in: result) {
                result = result.replacingCharacters(in: nsRange, with: replacement)
                offset += replacement.count - match.range.length
            }
        }

        return result
    }

    private func rewriteScriptTags(_ html: String, baseURL: URL, uuid: String) -> String {
        let pattern = #"(<script[^>]+src=)(["'])([^"']+)\2([^>]*>)"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])

        guard let regex = regex else { return html }

        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, options: [], range: range)

        var result = html
        var offset = 0

        for match in matches.reversed() {
            guard let urlRange = Range(match.range(at: 3), in: html),
                  let suffixRange = Range(match.range(at: 4), in: html) else {
                continue
            }

            let urlString = String(html[urlRange])
            let suffix = String(html[suffixRange])

            guard let url = resolveURL(urlString, baseURL: baseURL),
                  let localPath = getLocalPath(for: url) else {
                continue
            }

            let replacement = "$1$2bark-cache://\(uuid)\(localPath)$2\(suffix)"
            let replacementRange = NSRange(location: match.range.location + offset, length: match.range.length)

            if let nsRange = Range(replacementRange, in: result) {
                result = result.replacingCharacters(in: nsRange, with: replacement)
                offset += replacement.count - match.range.length
            }
        }

        return result
    }

    private func rewriteImageTags(_ html: String, baseURL: URL, uuid: String) -> String {
        let pattern = #"(<img[^>]+src=)(["'])([^"']+)\2([^>]*>)"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])

        guard let regex = regex else { return html }

        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, options: [], range: range)

        var result = html
        var offset = 0

        for match in matches.reversed() {
            guard let urlRange = Range(match.range(at: 3), in: html),
                  let suffixRange = Range(match.range(at: 4), in: html) else {
                continue
            }

            let urlString = String(html[urlRange])
            let suffix = String(html[suffixRange])

            guard let url = resolveURL(urlString, baseURL: baseURL),
                  let localPath = getLocalPath(for: url) else {
                continue
            }

            let replacement = "$1$2bark-cache://\(uuid)\(localPath)$2\(suffix)"
            let replacementRange = NSRange(location: match.range.location + offset, length: match.range.length)

            if let nsRange = Range(replacementRange, in: result) {
                result = result.replacingCharacters(in: nsRange, with: replacement)
                offset += replacement.count - match.range.length
            }
        }

        return result
    }

    private func rewriteMediaTags(_ html: String, baseURL: URL, uuid: String) -> String {
        let pattern = #"(<(video|audio)[^>]+src=)(["'])([^"']+)\3([^>]*>)"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])

        guard let regex = regex else { return html }

        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, options: [], range: range)

        var result = html
        var offset = 0

        for match in matches.reversed() {
            guard let urlRange = Range(match.range(at: 4), in: html),
                  let suffixRange = Range(match.range(at: 5), in: html) else {
                continue
            }

            let urlString = String(html[urlRange])
            let suffix = String(html[suffixRange])

            guard let url = resolveURL(urlString, baseURL: baseURL),
                  let localPath = getLocalPath(for: url) else {
                continue
            }

            let replacement = "$1$3bark-cache://\(uuid)\(localPath)$3\(suffix)"
            let replacementRange = NSRange(location: match.range.location + offset, length: match.range.length)

            if let nsRange = Range(replacementRange, in: result) {
                result = result.replacingCharacters(in: nsRange, with: replacement)
                offset += replacement.count - match.range.length
            }
        }

        return result
    }

    // MARK: - Helper

    private func extractRel(from html: String, match: NSTextCheckingResult) -> String? {
        let fullRange = Range(match.range, in: html)!
        let fullText = String(html[fullRange])

        let relPattern = #"rel=(["'])([^"']+)\1"#
        let relRegex = try? NSRegularExpression(pattern: relPattern, options: .caseInsensitive)
        let relMatch = relRegex?.firstMatch(in: fullText, options: [], range: NSRange(fullText.startIndex..., in: fullText))

        guard let relMatch = relMatch,
              let relValueRange = Range(relMatch.range(at: 2), in: fullText) else {
            return nil
        }

        return String(fullText[relValueRange])
    }

    private func resolveURL(_ urlString: String, baseURL: URL) -> URL? {
        // 跳过data: URL, javascript: URL, // 协议相对URL
        if urlString.hasPrefix("data:") ||
           urlString.hasPrefix("javascript:") ||
           urlString.hasPrefix("//") {
            return nil
        }

        // 已经是完整的HTTP URL
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            return URL(string: urlString)
        }

        // 相对路径
        return baseURL.appendingPathComponent(urlString)
    }

    private func getLocalPath(for url: URL) -> String? {
        // 根据文件扩展名确定本地路径
        let ext = (url.path as NSString).pathExtension.lowercased()

        switch ext {
        case "css":
            return "/resources/css/" + url.lastPathComponent
        case "js":
            return "/resources/js/" + url.lastPathComponent
        case "png", "jpg", "jpeg", "gif", "svg", "webp", "ico":
            return "/resources/images/" + url.lastPathComponent
        case "woff", "woff2", "ttf", "eot":
            return "/resources/fonts/" + url.lastPathComponent
        case "mp4", "webm", "ogg":
            return "/resources/media/" + url.lastPathComponent
        case "mp3", "wav":
            return "/resources/media/" + url.lastPathComponent
        default:
            return "/resources/other/" + url.lastPathComponent
        }
    }

    private func deduplicateResources(_ resources: [ResourceURL]) -> [ResourceURL] {
        var seen = Set<String>()
        return resources.filter { resource in
            let key = resource.originalURL.absoluteString
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }
    }

    // MARK: - Auto-Cache by Rules

    /// 缓存统计信息
    public struct CacheStatistics {
        public let totalResources: Int
        public let cachedCount: Int
        public let failedCount: Int
        public let totalSize: Int64
    }

    /// 解析并缓存 URL 对应页面的所有资源
    /// - Parameters:
    ///   - url: 页面 URL
    ///   - cacheStore: 缓存存储
    ///   - completion: 完成回调
    public static func parseAndCacheResources(
        for url: URL,
        useCacheStore cacheStore: WebCompressedCacheStore,
        completion: @escaping (Result<CacheStatistics, Error>) -> Void
    ) {
        // 使用 URLSession 下载数据
        let session = URLSession.shared

        // 首先下载页面 HTML
        let task = session.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "HTMLResourceParser", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"])))
                return
            }

            guard let htmlData = data,
                  let html = String(data: htmlData, encoding: .utf8) else {
                completion(.failure(NSError(domain: "HTMLResourceParser", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid HTML encoding"])))
                return
            }

            // 解析 HTML 提取资源
            let parser = HTMLResourceParser()
            let resources = parser.parseResources(html: html, baseURL: url)

            // 下载并缓存所有资源
            let group = DispatchGroup()
            var cachedCount = 0
            var failedCount = 0
            var totalSize: Int64 = 0
            let sizeLock = NSLock()

            for resource in resources {
                group.enter()
                session.dataTask(with: resource.originalURL) { data, response, error in
                    defer { group.leave() }

                    if let error = error {
                        sizeLock.lock()
                        failedCount += 1
                        sizeLock.unlock()

                        WebBridgeLogger.shared.warning("Failed to download resource: \(resource.originalURL.absoluteString) - \(error.localizedDescription)")
                        return
                    }

                    guard let httpResponse = response as? HTTPURLResponse,
                          (200...299).contains(httpResponse.statusCode),
                          let data = data else {
                        sizeLock.lock()
                        failedCount += 1
                        sizeLock.unlock()

                        WebBridgeLogger.shared.warning("Failed to download resource: \(resource.originalURL.absoluteString)")
                        return
                    }

                    // 生成缓存键
                    let key = resource.originalURL.sha256

                    // 确定 MIME 类型
                    let mimeType = self.getMimeType(for: resource)

                    // 保存到缓存
                    do {
                        try cacheStore.save(
                            data: data,
                            forKey: key,
                            url: resource.originalURL.absoluteString,
                            mimeType: mimeType
                        )

                        sizeLock.lock()
                        cachedCount += 1
                        totalSize += Int64(data.count)
                        sizeLock.unlock()

                        WebBridgeLogger.shared.debug("Cached resource: \(resource.originalURL.absoluteString)")
                    } catch {
                        sizeLock.lock()
                        failedCount += 1
                        sizeLock.unlock()

                        WebBridgeLogger.shared.warning("Failed to cache resource: \(resource.originalURL.absoluteString) - \(error.localizedDescription)")
                    }
                }.resume()
            }

            group.notify(queue: .main) {
                let stats = CacheStatistics(
                    totalResources: resources.count,
                    cachedCount: cachedCount,
                    failedCount: failedCount,
                    totalSize: totalSize
                )
                completion(.success(stats))
            }
        }

        task.resume()
    }

    /// 获取资源的 MIME 类型
    private static func getMimeType(for resource: ResourceURL) -> String {
        switch resource.type {
        case .css:
            return "text/css"
        case .js:
            return "application/javascript"
        case .image:
            return getMimeTypeForImageURL(resource.originalURL)
        case .font:
            return "font/" + (resource.originalURL.pathExtension.isEmpty ? "woff" : resource.originalURL.pathExtension)
        case .media:
            return getMimeTypeForMediaURL(resource.originalURL)
        case .favicon:
            return "image/x-icon"
        case .other:
            return "application/octet-stream"
        }
    }

    private static func getMimeTypeForImageURL(_ url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "webp": return "image/webp"
        case "ico": return "image/x-icon"
        default: return "image/jpeg"
        }
    }

    private static func getMimeTypeForMediaURL(_ url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "mp4": return "video/mp4"
        case "webm": return "video/webm"
        case "ogg": return "video/ogg"
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"
        default: return "video/mp4"
        }
    }
}
