//
//  MessageDetailViewController+WebViewNavigation.swift
//  SuperApp
//
//  WKNavigationDelegate for the Markdown message detail webview.
//

import UIKit
import WebKit
import WebBridgeKit

extension MessageDetailViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, _ in
            guard let self, let height = (result as? NSNumber)?.doubleValue else { return }
            self.markdownHeightConstraint?.update(offset: ceil(height) + 16)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url, url.scheme?.lowercased() == "drel" {
            // Markdown 正文里的 drel://app 链接：拦截并按外部拉起语义处理。
            if DrelExternalAppLinkOpener.openIfAppLink(url, from: self) {
                decisionHandler(.cancel)
                return
            }
        }
        let scheme = navigationAction.request.url?.scheme?.lowercased()
        let isWebURL = scheme == "http" || scheme == "https"
        // Context-menu commits (link preview menu's 打开链接) arrive as
        // `.other` rather than `.linkActivated`; both must leave the embedded
        // height-constrained webview and open the shared browser instead.
        let isLinkNavigation = navigationAction.navigationType == .linkActivated
            || (navigationAction.navigationType == .other && isWebURL)
        if isLinkNavigation, let url = navigationAction.request.url, isWebURL {
            WebBrowserManager.shared.openBrowser(
                url: url,
                params: DrelMessageOpenPolicy.browserParams(
                    for: url,
                    mode: DrelMessageOpenPolicy.mode(for: self.message.payload),
                    payload: self.message.payload.userInfo,
                    useManifestLoader: false
                ),
                from: self
            )
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
}
