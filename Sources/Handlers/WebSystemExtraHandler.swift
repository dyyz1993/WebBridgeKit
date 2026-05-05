//
//  WebSystemExtraHandler.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-14.
//

import UIKit
import WebKit
import AVFoundation
import LocalAuthentication

// Framework imports

/// 系统增强功能 Handler
/// 支持：手电筒控制、生物识别、桌面角标设置
public class WebSystemExtraHandler: BaseWebNativeHandler {

    // MARK: - Handle

    /**
     * 处理 JS 调用
     * @param body 调用参数
     * @param completion 处理完成后的回调
     */
    public override func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
        let params = body["params"] as? [String: Any] ?? body
        let action = params["action"] as? String ?? ""

        WebBridgeLogger.shared.log(.info, "[WebSystemExtraHandler] Handling action: \(action)")

        switch action {
        case "setTorch":
            let enabled = params["enabled"] as? Bool ?? true
            setTorch(enabled: enabled, completion: completion)

        case "authenticate":
            let reason = params["reason"] as? String ?? "需要验证身份"
            authenticate(reason: reason, completion: completion)

        case "setBadge":
            let count = params["count"] as? Int ?? 0
            setBadge(count: count, completion: completion)

        default:
            self.reject(error: "Unsupported action: \(action)", code: 404, completion: completion)
        }
    }

    // MARK: - Actions

    /**
     * 控制手电筒
     * @param enabled 是否开启
     * @param completion 返回结果
     */
    private func setTorch(enabled: Bool, completion: @escaping (Any) -> Void) {
        runOnMainThread { [weak self] in
            guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else {
                self?.reject(error: "Torch not available", completion: completion)
                return
            }

            do {
                try device.lockForConfiguration()
                device.torchMode = enabled ? .on : .off
                device.unlockForConfiguration()
                self?.resolve(["enabled": enabled], completion: completion)
            } catch {
                self?.reject(error: "Torch control failed: \(error.localizedDescription)", completion: completion)
            }
        }
    }

    /**
     * 生物识别 (FaceID / TouchID)
     * @param reason 验证原因描述
     * @param completion 返回结果
     */
    private func authenticate(reason: String, completion: @escaping (Any) -> Void) {
        let context = LAContext()
        var error: NSError?

        // 预检查可用性
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            // 获取生物识别类型
            let type: String
            if #available(iOS 11.0, *) {
                switch context.biometryType {
                case .faceID:
                    type = "faceID"
                case .touchID:
                    type = "touchID"
                case .none:
                    type = "none"
                case .opticID:
                    // Iris recognition available in iOS 18+
                    if #available(iOS 18.0, *) {
                        type = "opticID"
                    } else {
                        type = "unknown"
                    }
                @unknown default:
                    // Handle any other future biometry types
                    type = "unknown"
                }
            } else {
                type = "touchID" // iOS 11 以下只有 TouchID
            }

            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { [weak self] success, evalError in
                self?.runOnMainThread {
                    if success {
                        WebBridgeLogger.shared.log(.info, "[WebSystemExtraHandler] Authentication successful (\(type))")
                        self?.resolve([
                            "authenticated": true,
                            "biometryType": type
                        ], completion: completion)
                    } else {
                        let errMsg = evalError?.localizedDescription ?? "Authentication failed"
                        WebBridgeLogger.shared.log(.error, "[WebSystemExtraHandler] Authentication failed: \(errMsg)")
                        self?.reject(error: errMsg, code: (evalError as NSError?)?.code, completion: completion)
                    }
                }
            }
        } else {
            let errMsg = error?.localizedDescription ?? "Biometrics not available"
            WebBridgeLogger.shared.log(.error, "[WebSystemExtraHandler] Biometrics unavailable: \(errMsg)")
            self.reject(error: errMsg, code: error?.code, completion: completion)
        }
    }

    /**
     * 设置桌面角标
     * @param count 数字
     * @param completion 返回结果
     */
    private func setBadge(count: Int, completion: @escaping (Any) -> Void) {
        runOnMainThread { [weak self] in
            // iOS 13+ 需要申请通知权限才能设置角标
            let center = UNUserNotificationCenter.current()
            center.requestAuthorization(options: [.badge]) { granted, _ in
                self?.runOnMainThread {
                    if granted {
                        UIApplication.shared.applicationIconBadgeNumber = count
                        WebBridgeLogger.shared.log(.info, "[WebSystemExtraHandler] Set badge: \(count)")
                        self?.resolve(["count": count], completion: completion)
                    } else {
                        self?.reject(error: "Badge permission denied", completion: completion)
                    }
                }
            }
        }
    }
}
