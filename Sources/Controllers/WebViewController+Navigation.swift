//
//  WebViewController+Navigation.swift
//  WebBridgeKit
//

import WebKit

// MARK: - WKNavigationDelegate
extension WebViewController {

    /// 页面开始加载 - 更新缓存状态为下载中
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        #if DEBUG
        if let url = webView.url {
            updateCacheDebugStatus(
                url: url.absoluteString,
                status: .downloading,
                resourceCount: 0,
                cacheSize: 0
            )
        }
        #endif
    }

    /// 页面内容开始提交 - 检查缓存状态
    public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        #if DEBUG
        guard let url = webView.url else { return }

        // 检查是否在缓存中
        let entries = WebCompressedCacheStore.shared.getAllEntries()
        let isCached = entries.contains { $0.url == url.absoluteString }
        let cacheStatus: WebCacheDebugFloatingButton.CacheStatus = isCached ? .hit : .noCache

        // 获取缓存统计
        let cacheInfo = WebCompressedCacheStore.shared.getMemoryInfo()

        // 计算当前域名的缓存资源数量
        let domainResources = entries.filter { $0.domain == url.host ?? "" }
        let resourceCount = domainResources.count

        updateCacheDebugStatus(
            url: url.absoluteString,
            status: cacheStatus,
            resourceCount: resourceCount,
            cacheSize: Int64(cacheInfo.totalCompressedSize)
        )

        print("🔍 [CacheDebug] Navigation committed - URL: \(url.absoluteString)")
        print("   - Cache Status: \(cacheStatus.description)")
        print("   - Cached Resources: \(resourceCount)")
        #endif
    }

    /// 页面加载完成
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        #if DEBUG
        if let url = webView.url {
            print("✅ [CacheDebug] Page loaded: \(url.absoluteString)")
        }
        #endif
    }

    /// 页面加载失败
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        #if DEBUG
        if let url = webView.url {
            updateCacheDebugStatus(
                url: url.absoluteString,
                status: .error,
                resourceCount: 0,
                cacheSize: 0
            )
            print("❌ [CacheDebug] Navigation failed: \(url.absoluteString)")
            print("   - Error: \(error.localizedDescription)")
        }
        #endif
    }

    /// 页面内容加载失败
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        #if DEBUG
        if let url = webView.url {
            updateCacheDebugStatus(
                url: url.absoluteString,
                status: .error,
                resourceCount: 0,
                cacheSize: 0
            )
            print("❌ [CacheDebug] Provisional navigation failed: \(url.absoluteString)")
            print("   - Error: \(error.localizedDescription)")
        }
        #endif
    }
}
