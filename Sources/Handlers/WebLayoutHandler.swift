//
//  WebLayoutHandler.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-14.
//

import UIKit
import WebKit

// Framework imports

/// 界面布局与方向控制 Handler
/// 支持：强制横竖屏切换、全屏显示控制
public class WebLayoutHandler: BaseWebNativeHandler {
    
    // MARK: - Handle
    
    /**
     * 处理 JS 调用
     * @param body 调用参数
     * @param completion 处理完成后的回调
     */
    public override func handle(body: [String : Any], completion: @escaping (Any) -> Void) {
        let params = body["params"] as? [String: Any] ?? body
        let action = params["action"] as? String ?? ""

        WebBridgeLogger.shared.log(.info, "[WebLayoutHandler] Handling action: \(action)")

        // 如果没有指定子操作，返回布局状态
        if action.isEmpty {
            getLayoutStatus(completion: completion)
            return
        }

        switch action {
        case "setOrientation":
            let orientation = params["orientation"] as? String ?? "portrait"
            setOrientation(orientation, completion: completion)

        case "setFullscreen":
            let enabled = params["enabled"] as? Bool ?? true
            setFullscreen(enabled: enabled, completion: completion)

        case "setScrollEnabled":
            let enabled = params["enabled"] as? Bool ?? true
            setScrollEnabled(enabled: enabled, completion: completion)

        default:
            self.reject(error: "Unsupported action: \(action)", code: 404, completion: completion)
        }
    }

    /// 获取布局状态
    private func getLayoutStatus(completion: @escaping (Any) -> Void) {
        runOnMainThread { [weak self] in
            let orientation: String
            switch UIDevice.current.orientation {
            case .landscapeLeft, .landscapeRight:
                orientation = "landscape"
            case .portrait, .portraitUpsideDown:
                orientation = "portrait"
            default:
                orientation = "unknown"
            }

            self?.resolve([
                "orientation": orientation,
                "fullscreen": UIApplication.shared.isStatusBarHidden,
                "scrollEnabled": self?.webView?.scrollView.isScrollEnabled ?? true
            ], completion: completion)
        }
    }
    
    // MARK: - Actions
    
    /**
     * 设置屏幕方向
     * @param orientation 方向：portrait, landscape, auto
     * @param completion 返回结果
     */
    private func setOrientation(_ orientation: String, completion: @escaping (Any) -> Void) {
        runOnMainThread { [weak self] in
            // 发送通知让 WebViewController 处理
            NotificationCenter.default.post(
                name: NSNotification.Name("BarkOrientationChanged"),
                object: nil,
                userInfo: ["orientation": orientation]
            )
            
            // 兼容性保留：尝试直接旋转
            let preferred: UIInterfaceOrientation
            switch orientation {
            case "landscape": preferred = .landscapeLeft
            case "auto": preferred = .unknown
            default: preferred = .portrait
            }
            UIDevice.current.setValue(preferred.rawValue, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
            
            WebBridgeLogger.shared.log(.info, "[WebLayoutHandler] Orientation change requested: \(orientation)")
            self?.resolve(["orientation": orientation], completion: completion)
        }
    }
    
    /**
     * 设置全屏模式
     * @param enabled 是否全屏（隐藏状态栏）
     * @param completion 返回结果
     */
    private func setFullscreen(enabled: Bool, completion: @escaping (Any) -> Void) {
        runOnMainThread { [weak self] in
            // 发送通知告知 VC 刷新状态栏
            NotificationCenter.default.post(
                name: NSNotification.Name("BarkStatusBarVisibilityChanged"),
                object: nil,
                userInfo: ["hidden": enabled]
            )
            
            // 尝试通过全局设置隐藏状态栏 (仅作为辅助)
            #if !targetEnvironment(macCatalyst)
            UIApplication.shared.isStatusBarHidden = enabled
            #endif
            
            WebBridgeLogger.shared.log(.info, "[WebLayoutHandler] Fullscreen change requested: \(enabled)")
            self?.resolve(["fullscreen": enabled], completion: completion)
        }
    }
    
    private func setScrollEnabled(enabled: Bool, completion: @escaping (Any) -> Void) {
        runOnMainThread { [weak self] in
            self?.webView?.scrollView.isScrollEnabled = enabled
            self?.resolve(["enabled": enabled], completion: completion)
        }
    }
}
