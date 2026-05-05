//
//  BaseWebNativeHandler.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-14.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import WebKit
import UIKit

// Framework imports

/// 原生能力接口协议
public protocol WebNativeAPI {
    /**
     * 处理 JS 请求的主入口
     * - Parameters:
     *   - body: JS 传来的原始参数
     *   - completion: 异步结果回调
     */
    func handle(body: [String: Any], completion: @escaping (Any) -> Void)
}

/// WebBridge 统一响应模型
public struct WebBridgeResponse {
    public let success: Bool
    public let data: Any?
    public let error: String?
    public let errorCode: Int?

    public init(success: Bool, data: Any? = nil, error: String? = nil, errorCode: Int? = nil) {
        self.success = success
        self.data = data
        self.error = error
        self.errorCode = errorCode
    }

    /// 创建成功响应
    public static func success(data: Any? = nil) -> WebBridgeResponse {
        return WebBridgeResponse(success: true, data: data)
    }

    /// 创建错误响应（带错误码）
    public static func error(code: Int, message: String) -> WebBridgeResponse {
        return WebBridgeResponse(success: false, error: message, errorCode: code)
    }

    /// 创建错误响应（不带错误码，默认500）
    public static func error(message: String) -> WebBridgeResponse {
        return WebBridgeResponse(success: false, error: message, errorCode: 500)
    }

    /// 转换为 JS 层期待的字典格式
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["success": success]
        if let data = data {
            dict["data"] = data
        }
        if let error = error {
            dict["error"] = error
        }
        if let errorCode = errorCode {
            dict["code"] = errorCode
        }
        return dict
    }
}

/// 原生能力处理器基类
@objc open class BaseWebNativeHandler: NSObject, WebNativeAPI {

    /// 当前关联的 WebView 引用
    public weak var webView: WKWebView?

    /// 当前请求的 Token（用于自动日志）
    private var currentToken: WebBridgeLogToken?

    /// Handler 名称（用于日志模块标识）
    public var handlerName: String {
        String(describing: type(of: self))
            .replacingOccurrences(of: "Web", with: "")
            .replacingOccurrences(of: "Handler", with: "")
    }

    public override init() {
        super.init()
    }

    /**
     * 处理 JS 请求的主入口 (子类需重写)
     * - Parameters:
     *   - body: JS 传来的原始参数
     *   - completion: 异步结果回调
     */
    open func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
        // 子类应实现具体逻辑
        reject(error: "Method not implemented", completion: completion)
    }

    /**
     * 处理 JS 请求（带自动日志）
     * 子类可以调用此方法来获得自动日志记录
     * - Parameters:
     *   - body: JS 传来的原始参数
     *   - action: 动作名称
     *   - completion: 异步结果回调
     *   - handler: 实际处理逻辑
     */
    public func handleWithAutoLog(
        body: [String: Any],
        action: String,
        completion: @escaping (Any) -> Void,
        handler: () throws -> Void
    ) {
        // 创建请求 Token
        currentToken = WebBridgeLogger.shared.logRequest(
            action: action,
            params: body,
            module: handlerName
        )

        do {
            try handler()
        } catch {
            self.reject(error: error.localizedDescription, completion: completion)
        }
    }

    // MARK: - Helper Methods (Promise Style)

    /**
     * 成功回调（自动记录日志）
     * - Parameters:
     *   - data: 返回给 JS 的数据内容
     *   - completion: 原始回调函数
     */
    public func resolve(_ data: Any? = nil, completion: @escaping (Any) -> Void) {
        let response = WebBridgeResponse(success: true, data: data)

        // 自动记录响应日志
        if let token = currentToken {
            WebBridgeLogger.shared.logResponse(token: token, result: response.toDictionary(), error: nil)
            currentToken = nil
        }

        completion(response.toDictionary())
    }

    /**
     * 失败回调（自动记录日志）
     * - Parameters:
     *   - error: 错误描述
     *   - code: 错误码 (可选)
     *   - completion: 原始回调函数
     */
    public func reject(error: String, code: Int? = nil, completion: @escaping (Any) -> Void) {
        let response = WebBridgeResponse(success: false, error: error, errorCode: code)

        // 自动记录错误日志
        if let token = currentToken {
            WebBridgeLogger.shared.logResponse(token: token, result: response.toDictionary(), error: NSError(domain: handlerName, code: code ?? 500, userInfo: [NSLocalizedDescriptionKey: error]))
            currentToken = nil
        }

        completion(response.toDictionary())
    }

    /**
     * 向 JS 发送主动事件（自动记录日志）
     * @param event 事件名
     * @param data 数据
     */
    public func sendEventToJS(event: String, data: Any) {
        // 自动记录事件日志
        WebBridgeLogger.shared.logEvent(event: event, data: data, module: handlerName)

        let script: String
        if let jsonString = try? JSONSerialization.data(withJSONObject: ["data": data], options: []),
           let jsonString = String(data: jsonString, encoding: .utf8) {
            script = "if(window.BarkBridge) { window.BarkBridge.receiveEvent('\(event)', \(jsonString).data); }"
        } else {
            script = "if(window.BarkBridge) { window.BarkBridge.receiveEvent('\(event)', \(data)); }"
        }

        runOnMainThread { [weak self] in
            self?.webView?.evaluateJavaScript(script)
        }
    }

    // MARK: - UI & Context Helpers

    /// 获取当前顶层的 ViewController
    public var topViewController: UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              let rootViewController = window.rootViewController else {
            return nil
        }

        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }
        return topController
    }

    // MARK: - Permission Handling

    /// 权限类型枚举
    public enum PermissionType: String {
        case camera
        case microphone
        case location
        case contacts
        case photos
        case speech
        case notification
        case sensors
        case bluetooth
        case unknown

        public var displayName: String {
            switch self {
            case .camera: return "相机"
            case .microphone: return "麦克风"
            case .location: return "位置"
            case .contacts: return "通讯录"
            case .photos: return "相册"
            case .speech: return "语音识别"
            case .notification: return "通知"
            case .sensors: return "传感器"
            case .bluetooth: return "蓝牙"
            case .unknown: return "未知"
            }
        }
    }

    /// 权限状态枚举
    public enum PermissionStatus: String {
        case notDetermined
        case denied
        case restricted
        case authorized
        case unknown
    }

    /// 统一的权限拒绝响应
    /// - Parameters:
    ///   - type: 权限类型
    ///   - status: 权限状态
    ///   - showNativeAlert: 是否显示原生引导 Alert（默认 true）
    ///   - completion: 结果回调
    public func rejectPermissionDenied(
        type: PermissionType,
        status: PermissionStatus,
        showNativeAlert: Bool = true,
        completion: @escaping (Any) -> Void
    ) {
        let canOpenSettings = (status == .denied || status == .restricted)
        let message = "请在设置中允许\(type.displayName)权限"

        let response: [String: Any] = [
            "success": false,
            "error": "\(type.displayName)权限被拒绝 (状态: \(status.rawValue))",
            "code": 403,
            "permissionType": type.rawValue,
            "permissionStatus": status.rawValue,
            "canOpenSettings": canOpenSettings,
            "message": message
        ]

        // 显示原生引导 Alert
        if showNativeAlert, let topVC = topViewController {
            showPermissionGuideAlert(
                permissionType: type,
                canOpenSettings: canOpenSettings,
                topVC: topVC
            )
        }

        // 返回响应给 JS
        resolve(response, completion: completion)
    }

    /// 显示原生权限引导 Alert
    private func showPermissionGuideAlert(
        permissionType: PermissionType,
        canOpenSettings: Bool,
        topVC: UIViewController
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let alert = UIAlertController(
                title: "需要权限",
                message: "请在设置中允许\(permissionType.displayName)权限，以使用此功能。",
                preferredStyle: .alert
            )

            if canOpenSettings {
                alert.addAction(UIAlertAction(
                    title: "去设置",
                    style: .default
                ) { [weak self] _ in
                    self?.openSystemSettings()
                })
            }

            alert.addAction(UIAlertAction(
                title: "取消",
                style: .cancel
            ))

            topVC.present(alert, animated: true)
        }
    }

    /// 打开系统设置
    private func openSystemSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }

    /**
     * 确保在主线程执行操作
     * - Parameter block: 待执行的代码块
     */
    public func runOnMainThread(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }
}
