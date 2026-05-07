//
//  WebViewController+UIDelegate.swift
//  WebBridgeKit
//

import UIKit
import WebKit

// MARK: - UINavigationControllerDelegate
extension WebViewController {
    public func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        // 🔥 确保侧滑手势始终被禁用（如果配置要求）
        if let config = browserConfig, config.disableSwipeBack {
            navigationController.interactivePopGestureRecognizer?.isEnabled = false
        }
    }
}

// MARK: - WKScriptMessageHandler
@MainActor
extension WebViewController {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let action = body["action"] as? String else {
            return
        }

        print("🎮 [BarkWebVC] Received action: \(action)")

        // 获取当前 callbackId
        let callbackId = body["callbackId"] as? String

        // 特殊处理浏览器特性设置
        if action == "browser" {
            handleBrowserAction(body: body, callbackId: callbackId)
            return
        }

        // 使用 getHandler 方法支持懒加载
        guard let handler = bridge.getHandler(for: action) else {
            print("❌ [BarkWebVC] No handler for: \(action)")
            bridge.sendErrorToJS("Unsupported action: \(action)", callbackId: callbackId)
            return
        }

        handler.handle(body: body) { [weak self] result in
            self?.bridge.sendResultToJS(result, callbackId: callbackId)
        }
    }

    /// 🔥 处理浏览器特性相关的 Bridge 调用
    private func handleBrowserAction(body: [String: Any], callbackId: String?) {
        guard let params = body["params"] as? [String: Any],
              let action = params["action"] as? String else {
            bridge.sendErrorToJS("Missing action parameter", callbackId: callbackId)
            return
        }

        switch action {
        case "setFeature":
            if let feature = params["feature"] as? String,
               let enabled = params["enabled"] as? Bool {
                setBrowserFeature(feature, enabled: enabled)
                bridge.sendResultToJS([
                    "success": true,
                    "feature": feature,
                    "enabled": enabled
                ], callbackId: callbackId)
            } else {
                bridge.sendErrorToJS("Missing feature or enabled parameter", callbackId: callbackId)
            }

        case "getFeatures":
            bridge.sendResultToJS([
                "success": true,
                "features": [
                    "bounces": bouncesEnabled,
                    "scrollIndicator": scrollIndicatorEnabled,
                    "backForwardGestures": backForwardGesturesEnabled
                ]
            ], callbackId: callbackId)

        default:
            bridge.sendErrorToJS("Unknown browser action: \(action)", callbackId: callbackId)
        }
    }
}
