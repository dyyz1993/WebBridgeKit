//
//  WebScreenHandler.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-14.
//

import UIKit
import WebKit

// Framework imports

/// 屏幕与显示控制 Handler
/// 支持：黑屏模拟（潜行模式）、长按解锁、屏幕常亮控制
public class WebScreenHandler: BaseWebNativeHandler {
    
    // MARK: - Properties
    
    /// 黑屏遮罩层
    private var stealthOverlay: UIView?
    
    /// 原始亮度，用于退出潜行模式时恢复
    private var originalBrightness: CGFloat = UIScreen.main.brightness
    
    // MARK: - Handle
    
    /**
     * 处理 JS 调用
     * @param body 调用参数，包含 action 和 params
     * @param completion 处理完成后的回调，返回结果给 JS
     */
    public override func handle(body: [String : Any], completion: @escaping (Any) -> Void) {
        let params = body["params"] as? [String: Any] ?? body
        let action = params["action"] as? String ?? ""
        
        WebBridgeLogger.shared.log(.info, "[WebScreenHandler] Handling action: \(action)")
        
        switch action {
        case "enterStealthMode":
            enterStealthMode(completion: completion)
            
        case "exitStealthMode":
            exitStealthMode(completion: completion)
            
        case "setKeepScreenOn":
            let enabled = params["enabled"] as? Bool ?? true
            setKeepScreenOn(enabled: enabled, completion: completion)
            
        default:
            completion(WebBridgeResponse.error(code: 404, message: "Unsupported action: \(action)"))
        }
    }
    
    // MARK: - Actions
    
    /**
     * 进入潜行模式（黑屏模拟）
     * @param completion 返回结果
     */
    private func enterStealthMode(completion: @escaping (Any) -> Void) {
        runOnMainThread { [weak self] in
            guard let self = self else { return }
            
            // 如果已经在潜行模式，直接返回成功
            if self.stealthOverlay != nil {
                self.resolve(["status": "already_in_stealth_mode"], completion: completion)
                return
            }
            
            // 记录原始亮度并调至最低
            self.originalBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = 0.0
            
            // 禁用休眠
            UIApplication.shared.isIdleTimerDisabled = true
            
            // 创建全屏黑色遮罩
            let overlay = UIView(frame: UIScreen.main.bounds)
            overlay.backgroundColor = .black
            overlay.isUserInteractionEnabled = true
            
            // 添加长按手势用于解锁
            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(self.handleLongPress(_:)))
            longPress.minimumPressDuration = 1.5 // 需长按 1.5 秒
            overlay.addGestureRecognizer(longPress)
            
            // 添加提示文字（可选，极其暗淡）
            let label = UILabel()
            label.text = "长按恢复"
            label.textColor = UIColor(white: 0.1, alpha: 1.0) // 几乎看不见
            label.font = .systemFont(ofSize: 12)
            label.sizeToFit()
            label.center = CGPoint(x: overlay.bounds.midX, y: overlay.bounds.maxY - 50)
            overlay.addSubview(label)
            
            // 注入到最顶层 Window
            if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
                window.addSubview(overlay)
                self.stealthOverlay = overlay
                
                WebBridgeLogger.shared.log(.info, "[WebScreenHandler] Stealth mode entered")
                self.resolve(["status": "entered"], completion: completion)
            } else {
                self.reject(error: "Key window not found", completion: completion)
            }
        }
    }
    
    /**
     * 退出潜行模式
     * @param completion 返回结果
     */
    private func exitStealthMode(completion: @escaping (Any) -> Void) {
        runOnMainThread { [weak self] in
            guard let self = self else { return }
            
            if let overlay = self.stealthOverlay {
                overlay.removeFromSuperview()
                self.stealthOverlay = nil
                
                // 恢复亮度
                UIScreen.main.brightness = self.originalBrightness
                
                // 恢复休眠设置（默认跟随系统，或显式开启）
                UIApplication.shared.isIdleTimerDisabled = false
                
                WebBridgeLogger.shared.log(.info, "[WebScreenHandler] Stealth mode exited")
                self.resolve(["status": "exited"], completion: completion)
            } else {
                self.resolve(["status": "not_in_stealth_mode"], completion: completion)
            }
        }
    }
    
    /**
     * 设置屏幕常亮
     * @param enabled 是否常亮
     * @param completion 返回结果
     */
    private func setKeepScreenOn(enabled: Bool, completion: @escaping (Any) -> Void) {
        runOnMainThread { [weak self] in
            UIApplication.shared.isIdleTimerDisabled = enabled
            WebBridgeLogger.shared.log(.info, "[WebScreenHandler] Set keepScreenOn: \(enabled)")
            self?.resolve(["enabled": enabled], completion: completion)
        }
    }
    
    // MARK: - Gestures
    
    /**
     * 处理长按手势解锁
     * @param gesture 手势对象
     */
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            // 震动反馈
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
            
            // 退出黑屏
            exitStealthMode { [weak self] _ in
                // 通知 JS 端已解锁
                self?.notifyJS(event: "onScreenUnlocked", data: ["timestamp": Date().timeIntervalSince1970])
            }
        }
    }
    
    /**
     * 主动通知 JS 事件
     * @param event 事件名称
     * @param data 携带的数据
     */
    private func notifyJS(event: String, data: [String: Any]) {
        let script = "if(window.onScreenUnlocked) { window.onScreenUnlocked(\(data.jsonString ?? "{}")); } " +
                     "window.BarkBridge.receiveEvent('\(event)', \(data.jsonString ?? "{}"));"
        
        runOnMainThread { [weak self] in
            self?.webView?.evaluateJavaScript(script, completionHandler: nil)
        }
    }
}

// 简单的 JSON 转换扩展
fileprivate extension Dictionary {
    var jsonString: String? {
        guard let data = try? JSONSerialization.data(withJSONObject: self, options: []) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
