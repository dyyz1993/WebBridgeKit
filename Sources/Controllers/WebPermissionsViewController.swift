//
//  WebPermissionsViewController.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-13.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import WebKit

// Framework imports

class WebPermissionsViewController: UIViewController {
    private var webView: WKWebView!
    private var bridge: WebJavaScriptBridge!

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "权限管理"
        view.backgroundColor = ThemeTokens.Color.background

        // 创建 WebView 配置
        let webConfiguration = WKWebViewConfiguration()
        let userContentController = WKUserContentController()

        // 注入 JavaScript Bridge 代码
        let bridgeScript = """
        window.BarkBridge = {
            callbacks: {},
            callbackId: 0,

            callNative: function(action, params, callback) {
                const id = ++this.callbackId;
                if (callback) {
                    this.callbacks[id] = callback;
                }

                const message = {
                    action: action,
                    params: params || {},
                    callbackId: id
                };

                window.webkit.messageHandlers.barkBridge.postMessage(message);
            },

            receiveResult: function(result) {
                const id = result.callbackId;
                if (this.callbacks[id]) {
                    this.callbacks[id](result);
                    delete this.callbacks[id];
                }
            }
        };
        """

        userContentController.addUserScript(WKUserScript(
            source: bridgeScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))

        // 注册消息处理器
        userContentController.add(self, name: "barkBridge")

        webConfiguration.userContentController = userContentController

        // 创建 WebView
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.navigationDelegate = self
        view.addSubview(webView)

        webView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // 初始化桥接
        bridge = WebJavaScriptBridge()
        bridge.setWebView(webView)

        // 加载权限管理页面
        loadPermissionsPage()
    }

    private func loadPermissionsPage() {
        guard let htmlPath = Bundle.main.path(forResource: "permissions", ofType: "html"),
              let html = try? String(contentsOfFile: htmlPath) else {
            showErrorPage()
            return
        }

        let htmlURL = URL(fileURLWithPath: htmlPath)
        webView.loadHTMLString(html, baseURL: htmlURL.deletingLastPathComponent())
    }

    private func showErrorPage() {
        let errorHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body { font-family: -apple-system, sans-serif; padding: 20px; text-align: center; }
                h1 { color: #ff3b30; }
                p { color: #8e8e93; }
            </style>
        </head>
        <body>
            <h1>😕 加载失败</h1>
            <p>权限管理页面文件未找到</p>
        </body>
        </html>
        """
        webView.loadHTMLString(errorHTML, baseURL: nil)
    }

    private func checkPermissions(completion: @escaping ([[String: Any]]) -> Void) {
        WebPermissionManager.shared.checkAllPermissions(completion: completion)
    }

    // MARK: - Cleanup

    deinit {
        // 🔒 Stop loading and remove delegates to prevent memory leaks
        webView?.stopLoading()
        webView?.navigationDelegate = nil

        // 🔒 Remove script message handler to break strong reference cycle
        // WKUserContentController.add(_:name:) creates a strong reference to the handler
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "barkBridge")

        // 🔒 Remove from superview
        webView?.removeFromSuperview()

        print("🧹 [WebPermissionsVC] Cleaned up with proper memory management")
    }
}

extension WebPermissionsViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let action = body["action"] as? String else {
            return
        }

        switch action {
        case "getPermissionStatus":
            checkPermissions { permissions in
                var response: [String: Any] = [:]
                let summary = self.calculateSummary(permissions)
                response = [
                    "success": true,
                    "data": [
                        "permissions": permissions,
                        "summary": summary
                    ]
                ]

                // 添加 callbackId
                if let callbackId = body["callbackId"] {
                    response["callbackId"] = callbackId
                }

                // 发送回 JavaScript
                let script = "window.BarkBridge.receiveResult(\(self.toJson(response)));"
                self.webView.evaluateJavaScript(script, completionHandler: nil)
            }

        case "openSettings":
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            var response: [String: Any] = ["success": true]
            if let callbackId = body["callbackId"] {
                response["callbackId"] = callbackId
            }
            let script = "window.BarkBridge.receiveResult(\(toJson(response)));"
            webView.evaluateJavaScript(script, completionHandler: nil)

        default:
            var response: [String: Any] = [
                "success": false,
                "error": "Unknown action: \(action)"
            ]
            if let callbackId = body["callbackId"] {
                response["callbackId"] = callbackId
            }
            let script = "window.BarkBridge.receiveResult(\(toJson(response)));"
            webView.evaluateJavaScript(script, completionHandler: nil)
        }
    }

    private func calculateSummary(_ permissions: [[String: Any]]) -> [String: Any] {
        var total = 0
        var granted = 0
        var denied = 0
        var notDetermined = 0

        for perm in permissions {
            total += 1
            if let grantedValue = perm["granted"] as? Bool, grantedValue {
                granted += 1
            } else if let status = perm["status"] as? String {
                switch status {
                case "denied", "restricted":
                    denied += 1
                case "notDetermined":
                    notDetermined += 1
                default:
                    break
                }
            }
        }

        return [
            "total": total,
            "granted": granted,
            "denied": denied,
            "notDetermined": notDetermined
        ]
    }

    private func toJson(_ object: Any) -> String {
        if let data = try? JSONSerialization.data(withJSONObject: object, options: []),
           let jsonString = String(data: data, encoding: .utf8) {
            return jsonString
        }
        return "{}"
    }
}

extension WebPermissionsViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        decisionHandler(.allow)
    }
}
