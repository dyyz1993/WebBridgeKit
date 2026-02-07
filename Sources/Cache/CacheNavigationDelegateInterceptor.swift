//
//  CacheNavigationDelegateInterceptor.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-02-01.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import WebKit

/// 缓存导航拦截器
/// 通过 WKNavigationDelegate 拦截请求，实现透明的缓存回退机制
public class CacheNavigationDelegateInterceptor: NSObject {

    // MARK: - Properties

    public weak var webView: WKWebView?
    public var originalDelegate: WKNavigationDelegate?

    // 是否启用缓存拦截
    public var isInterceptionEnabled: Bool = true

    // 缓存策略
    public var cachePolicy: CachePolicy = .standard

    public enum CachePolicy {
        case standard    // 标准模式：优先使用缓存，无缓存时回退到网络
        case networkOnly // 仅网络模式：不使用缓存
        case cacheOnly   // 仅缓存模式：只使用缓存，无缓存时失败
    }

    // MARK: - Initialization

    public init(webView: WKWebView? = nil) {
        self.webView = webView
        super.init()
    }

    // MARK: - Public API

    /// 检查URL是否应该被缓存
    /// - Parameter url: 要检查的URL
    /// - Returns: 是否应该缓存此URL
    public func shouldCacheURL(_ url: URL) -> Bool {
        // 只缓存 HTTP/HTTPS 请求
        guard url.scheme == "http" || url.scheme == "https" else {
            return false
        }

        // 不缓存 POST 请求（通常有副作用）
        // 这个检查在实际拦截时需要从 request.httpMethod 获取

        // 根据路径扩展名判断
        let pathExtension = url.pathExtension.lowercased()

        // 缓存静态资源
        let cacheableExtensions = [
            "js", "css",      // 脚本和样式
            "png", "jpg", "jpeg", "gif", "webp", "svg", "ico",  // 图片
            "woff", "woff2", "ttf", "eot",  // 字体
            "json", "xml"      // 数据文件
        ]

        return cacheableExtensions.contains(pathExtension)
    }

    /// 检查URL是否应该被拦截（检查缓存）
    /// - Parameter url: 要检查的URL
    /// - Returns: 是否应该拦截此请求
    public func shouldInterceptURL(_ url: URL) -> Bool {
        // 检查缓存策略
        switch cachePolicy {
        case .networkOnly:
            return false

        case .cacheOnly:
            return InterceptiveCacheManager.shared.hasCachedResource(for: url)

        case .standard:
            // 标准模式：检查是否有缓存
            return shouldCacheURL(url) &&
                   InterceptiveCacheManager.shared.hasCachedResource(for: url)
        }
    }
}

// MARK: - WKNavigationDelegate

extension CacheNavigationDelegateInterceptor: WKNavigationDelegate {

    /// 决策导航动作（核心拦截点）
    public func webView(_ webView: WKWebView,
                       decidePolicyFor navigationAction: WKNavigationAction,
                       decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            callOriginalDelegate(.allow)
            return
        }

        // 检查是否启用拦截
        guard isInterceptionEnabled else {
            decisionHandler(.allow)
            callOriginalDelegate(.allow)
            return
        }

        // 检查是否为主文档请求
        let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? false

        // 主文档请求不拦截（让 WebView 正常加载）
        if isMainFrame {
            decisionHandler(.allow)
            callOriginalDelegate(.allow)
            return
        }

        // 检查请求方法
        let httpMethod = navigationAction.request.httpMethod?.uppercased() ?? "GET"

        // POST 请求不拦截（有副作用）
        if httpMethod == "POST" {
            decisionHandler(.allow)
            callOriginalDelegate(.allow)
            return
        }

        // 检查是否应该拦截此请求
        guard shouldInterceptURL(url) else {
            decisionHandler(.allow)
            callOriginalDelegate(.allow)
            return
        }

        // 🔑 关键点：有缓存，注入缓存数据
        if let cachedResource = InterceptiveCacheManager.shared.loadCachedResource(for: url) {
            print("✅ [CacheInterceptor] Cache HIT: \(url.lastPathComponent)")

            // 注入缓存数据
            ResourceInjector.shared.injectResource(cachedResource, into: webView) { success in
                if success {
                    // 取消网络请求
                    decisionHandler(.cancel)

                    // 不调用原始 delegate（因为我们已经处理了）
                } else {
                    // 注入失败，允许网络请求
                    decisionHandler(.allow)
                    self.callOriginalDelegate(.allow)
                }
            }
        } else {
            // 无缓存，允许网络请求
            print("🌐 [CacheInterceptor] Cache MISS: \(url.lastPathComponent)")

            decisionHandler(.allow)
            self.callOriginalDelegate(.allow)
        }
    }

    /// 响应到达（用于后台缓存）
    public func webView(_ webView: WKWebView,
                       decidePolicyFor navigationResponse: WKNavigationResponse,
                       decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {

        // 检查是否应该缓存此响应
        if let url = navigationResponse.response.url,
           shouldCacheURL(url),
           let httpResponse = navigationResponse.response as? HTTPURLResponse,
           httpResponse.statusCode == 200 {

            // 异步缓存这个响应
            cacheResponseIfNeeded(navigationResponse)
        }

        decisionHandler(.allow)
        callOriginalDelegate(.allow)
    }

    /// 页面加载完成
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("✅ [CacheInterceptor] Page loaded: \(webView.url?.absoluteString ?? "unknown")")

        // TODO: 检查是否需要缓存主文档 (暂时注释，避免编译顺序问题)
        // if let url = webView.url,
        //    let history = WebPageHistoryManager.shared.findHistory(url: url),
        //    history.isCached {
        //     print("✅ [CacheInterceptor] Main page is cached")
        // }

        // 调用原始 delegate
        if let didFinish = originalDelegate?.webView(_:didFinish:) {
            didFinish(webView, navigation)
        } else {
            originalDelegate?.webView?(webView, didFinish: navigation)
        }
    }

    /// 页面加载失败
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("❌ [CacheInterceptor] Page failed: \(error.localizedDescription)")

        // 调用原始 delegate
        if let didFail = originalDelegate?.webView(_:didFail:withError:) {
            didFail(webView, navigation, error)
        } else {
            originalDelegate?.webView?(webView, didFail: navigation, withError: error)
        }
    }

    // MARK: - Private Helpers

    /// 异步缓存响应
    private func cacheResponseIfNeeded(_ navigationResponse: WKNavigationResponse) {
        guard let url = navigationResponse.response.url,
              let httpResponse = navigationResponse.response as? HTTPURLResponse else {
            return
        }

        // 读取响应数据
        // 注意：WKNavigationResponse 不提供数据访问，这里需要其他方式获取
        // 可以通过 WKURLSchemeTask 或其他拦截方式获取

        print("📦 [CacheInterceptor] Would cache: \(url.lastPathComponent)")
        // TODO: 实现实际的响应缓存逻辑
    }

    /// 调用原始 delegate
    private func callOriginalDelegate(_ policy: WKNavigationActionPolicy) {
        // 注意：由于我们已经处理了请求，通常不需要再调用原始 delegate
        // 但某些情况下可能需要通知原始 delegate
    }
}
