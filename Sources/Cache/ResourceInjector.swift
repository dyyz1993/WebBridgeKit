//
//  ResourceInjector.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-02-01.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import WebKit

/// 资源注入器
/// 负责将缓存的资源数据注入到 WebView 中
public class ResourceInjector {

    public static let shared = ResourceInjector()

    private init() {}

    // MARK: - Public API

    /// 注入缓存的资源到 WebView
    /// - Parameters:
    ///   - resource: 缓存的资源
    ///   - webView: 目标 WebView
    ///   - completion: 完成回调
    public func injectResource(_ resource: CachedResource,
                              into webView: WKWebView,
                              completion: @escaping (Bool) -> Void) {

        DispatchQueue.main.async {
            let success: Bool

            switch resource.mimeType {
            case "application/javascript", "text/javascript":
                success = self.injectJavaScript(resource, into: webView)

            case "text/css":
                success = self.injectCSS(resource, into: webView)

            case "image/png", "image/jpeg", "image/gif", "image/webp", "image/svg+xml":
                success = self.injectImage(resource, into: webView)

            case "application/json", "text/plain":
                success = self.injectText(resource, into: webView)

            default:
                // 其他类型使用临时 URL Scheme
                success = self.injectViaTemporaryScheme(resource, into: webView)
            }

            completion(success)
        }
    }

    // MARK: - Private Methods

    /// 注入 JavaScript
    private func injectJavaScript(_ resource: CachedResource, into webView: WKWebView) -> Bool {
        guard let jsString = String(data: resource.data, encoding: .utf8) else {
            return false
        }

        // 转义 JavaScript 中的特殊字符
        let escapedJS = escapeJSString(jsString)

        // 使用 eval 执行 JavaScript
        let script = "eval('\(escapedJS)');"

        webView.evaluateJavaScript(script) { _, error in
            if let error = error {
                print("❌ [ResourceInjector] Failed to inject JS: \(error.localizedDescription)")
            } else {
                print("✅ [ResourceInjector] Injected JS: \(resource.url.lastPathComponent)")
            }
        }

        return true
    }

    /// 注入 CSS
    private func injectCSS(_ resource: CachedResource, into webView: WKWebView) -> Bool {
        guard let cssString = String(data: resource.data, encoding: .utf8) else {
            return false
        }

        // 转义 CSS 中的特殊字符
        let escapedCSS = escapeJSString(cssString)

        // 创建 style 标签并注入
        let script = """
        (function() {
            var style = document.createElement('style');
            style.textContent = '\(escapedCSS)';
            document.head.appendChild(style);
            console.log('✅ [Cache] Injected CSS: \(resource.url.lastPathComponent)');
        })();
        """

        webView.evaluateJavaScript(script) { _, error in
            if let error = error {
                print("❌ [ResourceInjector] Failed to inject CSS: \(error.localizedDescription)")
            }
        }

        return true
    }

    /// 注入图片
    private func injectImage(_ resource: CachedResource, into webView: WKWebView) -> Bool {
        // 将图片转换为 Base64
        let base64 = resource.data.base64EncodedString()
        let mimeType = resource.mimeType

        // 创建 data URL
        let dataURL = "data:\(mimeType);base64,\(base64)"

        // 查找并替换所有使用此 URL 的图片
        let script = """
        (function() {
            var url = '\(resource.url.absoluteString)';
            var dataURL = '\(dataURL)';

            // 替换 img 标签的 src
            document.querySelectorAll('img[src="' + url + '"]').forEach(function(img) {
                img.src = dataURL;
            });

            // 替换 background-image
            var elements = document.querySelectorAll('[style*="' + url + '"]');
            Array.from(elements).forEach(function(el) {
                var style = el.getAttribute('style') || '';
                el.setAttribute('style', style.replace(url, dataURL));
            });

            console.log('✅ [Cache] Injected Image: \(resource.url.lastPathComponent)');
        })();
        """

        webView.evaluateJavaScript(script) { _, error in
            if let error = error {
                print("❌ [ResourceInjector] Failed to inject Image: \(error.localizedDescription)")
            }
        }

        return true
    }

    /// 注入文本内容
    private func injectText(_ resource: CachedResource, into webView: WKWebView) -> Bool {
        guard let text = String(data: resource.data, encoding: .utf8) else {
            return false
        }

        let escapedText = escapeJSString(text)
        let script = "console.log('[Cached Resource: \(resource.url.lastPathComponent)]', '\(escapedText)');"

        webView.evaluateJavaScript(script)

        return true
    }

    /// 通过临时 URL Scheme 注入
    /// 用于无法通过 JavaScript 直接注入的资源（如字体、视频等）
    private func injectViaTemporaryScheme(_ resource: CachedResource, into webView: WKWebView) -> Bool {
        // 为这个资源创建一个临时的 URL
        let tempURLString = "bark-temp-cache://\(resource.url.absoluteString.hashValue)"

        // 注册临时的 scheme handler
        let handler = TemporaryCacheHandler(resource: resource)
        webView.configuration.setURLSchemeHandler(handler, forURLScheme: "bark-temp-cache")

        // 通知页面重新加载资源
        let script = """
        (function() {
            var originalURL = '\(resource.url.absoluteString)';
            var tempURL = '\(tempURLString)';

            // 替换所有使用此 URL 的元素
            document.querySelectorAll('[src="' + originalURL + '"]').forEach(function(el) {
                el.src = tempURL;
            });

            document.querySelectorAll('[href="' + originalURL + '"]').forEach(function(el) {
                el.href = tempURL;
            });

            console.log('✅ [Cache] Replaced URL: ' + originalURL + ' -> ' + tempURL);
        })();
        """

        webView.evaluateJavaScript(script) { _, error in
            if let error = error {
                print("❌ [ResourceInjector] Failed to replace URL: \(error.localizedDescription)")
            }
        }

        return true
    }

    // MARK: - Helper Methods

    /// 转义 JavaScript 字符串中的特殊字符
    private func escapeJSString(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
    }
}

// MARK: - TemporaryCacheHandler

/// 临时缓存 URL Scheme Handler
/// 用于处理无法通过 JavaScript 直接注入的资源
private class TemporaryCacheHandler: NSObject, WKURLSchemeHandler {

    private let resource: CachedResource

    init(resource: CachedResource) {
        self.resource = resource
        super.init()
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }

        print("📦 [TemporaryCacheHandler] Serving: \(url.lastPathComponent)")

        // 构造 HTTP 响应
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": resource.mimeType,
                "Cache-Control": "max-age=31536000",
                "Access-Control-Allow-Origin": "*",
                "X-Cache-Status": "HIT"
            ]
        )!

        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(resource.data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        // 任务被取消
    }
}
