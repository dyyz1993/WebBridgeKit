//
//  WebJavaScriptBridge.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-13.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import WebKit
import UIKit

// Framework imports

/// JS-OC 通信桥接核心类
public class WebJavaScriptBridge: NSObject, WKScriptMessageHandler {

    // MARK: - Properties

    public var nativeHandlers: [String: WebNativeAPI] = [:]  // 改为 public，供 WebTestViewController 访问
    private var handlerFactories: [String: () -> WebNativeAPI] = [:]  // Handler 工厂方法，用于懒加载
    private weak var webView: WKWebView?
    public var currentCallbackId: String?  // 改为 public，供 WebTestViewController 访问
    private let handlersLock = NSLock()  // 线程安全锁

    // 活跃的请求 Token（用于自动日志）
    private var activeTokens: [String: WebBridgeLogToken] = [:]
    private let tokensLock = NSLock()

    // MARK: - Initialization

    public override init() {
        super.init()
        registerHandlerFactories()  // 只注册工厂方法，不创建实例
    }
    
    // MARK: - WKScriptMessageHandler

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let action = body["action"] as? String else {
            WebBridgeLogger.shared.error("Invalid message format")
            sendErrorToJS("Invalid message format")
            return
        }

        // 保存 callbackId
        currentCallbackId = body["callbackId"] as? String

        // 自动记录请求日志（使用 Token 机制）
        let token = WebBridgeLogToken(
            action: action,
            input: body,
            module: "JSBridge"
        )

        // 保存 Token
        tokensLock.lock()
        activeTokens[action] = token
        tokensLock.unlock()

        // 输出到控制台
        #if DEBUG
        print("🌉 [JS Bridge] Received action: \(action), callbackId: \(currentCallbackId ?? "nil")")
        #endif

        // 使用 getHandler 实现懒加载
        guard let handler = getHandler(for: action) else {
            WebBridgeLogger.shared.error("Unsupported action: \(action)")
            sendErrorToJS("Unsupported action: \(action)")

            // 记录错误响应
            WebBridgeLogger.shared.logResponse(
                token: token,
                result: nil,
                error: NSError(domain: "JSBridge", code: 404, userInfo: [NSLocalizedDescriptionKey: "Unsupported action"])
            )

            // 清理 Token
            tokensLock.lock()
            activeTokens.removeValue(forKey: action)
            tokensLock.unlock()

            return
        }

        // 设置 Handler 的 Token（用于自动日志）
        if let baseHandler = handler as? BaseWebNativeHandler {
            // 使用关联对象或者直接设置内部属性
            // 这里通过反射或者添加公共方法来设置 token
            // 由于 currentToken 是私有的，我们在 handler 内部处理
        }

        // 异步处理，避免阻塞主线程
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            handler.handle(body: body) { [weak self] result in
                // 自动记录响应日志
                WebBridgeLogger.shared.logResponse(token: token, result: result, error: nil)

                // 清理 Token
                self?.tokensLock.lock()
                self?.activeTokens.removeValue(forKey: action)
                self?.tokensLock.unlock()

                self?.sendResultToJS(result)
            }
        }
    }

    // MARK: - Register Handlers

    /// 注册 Handler 工厂方法（懒加载优化）
    /// 只注册工厂方法，不立即创建 Handler 实例
    private func registerHandlerFactories() {
        // 基础功能
        handlerFactories["share"] = { WebShareHandler() }
        handlerFactories["getLocation"] = { WebLocationHandler() }
        handlerFactories["requestPermission"] = { WebPermissionHandler() }

        // 系统信息
        handlerFactories["getSystemInfo"] = { WebSystemInfoHandler() }
        handlerFactories["getNetworkInfo"] = { WebNetworkHandler() }

        // 交互反馈
        handlerFactories["haptic"] = { WebHapticHandler() }
        handlerFactories["vibrate"] = { WebVibrateHandler() }

        // 剪贴板
        handlerFactories["clipboard"] = { WebClipboardHandler() }

        // 扫码
        handlerFactories["scan"] = { WebScanHandler() }

        // 相机
        handlerFactories["camera"] = { WebCameraHandler() }

        // 视频流
        handlerFactories["videoStream"] = { WebVideoHandler() }

        // 语音识别
        handlerFactories["speech"] = { WebSpeechHandler() }

        // 实时音频音量监控
        handlerFactories["audioLevel"] = { WebAudioLevelHandler() }

        // 通讯录
        handlerFactories["contacts"] = { WebContactsHandler() }

        // 屏幕控制
        handlerFactories["screen"] = { WebScreenHandler() }

        // 布局控制
        handlerFactories["layout"] = { WebLayoutHandler() }

        // 投屏控制
        handlerFactories["mirroring"] = { WebMirroringHandler() }

        // 传感器控制
        handlerFactories["sensors"] = { WebSensorsHandler() }

        // 媒体与文件
        handlerFactories["media"] = { WebMediaHandler() }

        // 系统增强
        handlerFactories["systemExtra"] = { WebSystemExtraHandler() }

        // 语音合成
        handlerFactories["tts"] = { WebSpeechSynthesisHandler() }

        // 蓝牙控制
        handlerFactories["bluetooth"] = { WebBluetoothHandler() }

        // 文件选择
        handlerFactories["file"] = { WebFileHandler() }

        // 相册选择 (iOS 14+)
        if #available(iOS 14, *) {
            handlerFactories["photo"] = { WebPhotoHandler() }
        }

        // 权限状态查询
        handlerFactories["getPermissionStatus"] = { WebPermissionStatusHandler() }

        // 打开系统设置
        handlerFactories["openSettings"] = { WebOpenSettingsHandler() }

        // 打开本地页面
        handlerFactories["openPage"] = { WebOpenPageHandler() }

        // 关闭当前页面
        handlerFactories["closePage"] = { WebClosePageHandler() }

        // 获取导航历史
        handlerFactories["getHistory"] = { WebGetHistoryHandler() }

        // 后退
        handlerFactories["goBack"] = { WebGoBackHandler() }

        // 设置弹窗参数
        handlerFactories["setModal"] = { WebSetModalHandler() }

        // 手势监控
        handlerFactories["gesture"] = { WebGestureHandler() }

        // 缓存调试
        handlerFactories["cacheDebug"] = { WebCacheDebugHandler() }

        print("🌉 [JS Bridge] 已注册 \(handlerFactories.count) 个 Handler 工厂（懒加载模式）")
        print("   工厂列表: \(Array(handlerFactories.keys).sorted())")
    }

    // MARK: - Get Handler (Lazy Loading)

    /// 获取 Handler 实例（懒加载）
    /// 如果实例已存在，直接返回；否则通过工厂方法创建
    /// - Parameter action: Handler 对应的 action 名称
    /// - Returns: Handler 实例，如果不存在则返回 nil
    public func getHandler(for action: String) -> WebNativeAPI? {
        handlersLock.lock()
        defer { handlersLock.unlock() }

        // 如果已创建，直接返回
        if let handler = nativeHandlers[action] {
            return handler
        }

        // 如果未创建，通过工厂方法创建
        guard let factory = handlerFactories[action] else {
            return nil
        }

        // 创建 Handler 实例
        let handler = factory()
        nativeHandlers[action] = handler

        // 设置 WebView 引用
        if let baseHandler = handler as? BaseWebNativeHandler,
           let webView = self.webView {
            baseHandler.webView = webView
        }

        print("♻️ [JS Bridge] 懒加载创建 Handler: \(action)")
        return handler
    }

    // MARK: - Send Result to JS
    
    public func sendResultToJS(_ result: Any) {
        var resultDict: [String: Any] = [:]

        // 处理不同的结果类型
        if let response = result as? WebBridgeResponse {
            // 如果是统一响应模型，转换为字典
            resultDict = response.toDictionary()
        } else if let dict = result as? [String: Any] {
            // 如果已经是字典，直接使用
            resultDict = dict
        } else {
            // 否则包装成 data 字段
            resultDict = ["data": result]
        }

        // 添加 callbackId（关键！）
        if let callbackId = currentCallbackId {
            resultDict["callbackId"] = callbackId
        }

        let script: String
        if let jsonString = try? JSONSerialization.data(withJSONObject: resultDict, options: []),
           let jsonString = String(data: jsonString, encoding: .utf8) {
            script = "window.BarkBridge.receiveResult(\(jsonString));"
        } else {
            // 如果 JSON 序列化失败，使用简单的字符串
            script = "window.BarkBridge.receiveResult({'success': false, 'error': 'JSON serialization failed'});"
        }

        WebBridgeLogger.shared.log(.info, "[JS Bridge] Sending to JS: \(script.prefix(200))")

        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(script, completionHandler: { jsResult, error in
                if let error = error {
                    WebBridgeLogger.shared.error("JavaScript execution failed: \(error.localizedDescription)")
                }
            })
        }
    }

    public func sendErrorToJS(_ error: String) {
        let result: [String: Any] = ["success": false, "error": error]
        sendResultToJS(result)
    }

    // MARK: - Send Event to JS

    /**
     * 向 JS 发送主动推送事件（自动记录日志）
     * @param event 事件名称
     * @param data 事件携带的数据
     */
    public func sendEventToJS(event: String, data: Any) {
        // 自动记录事件日志
        WebBridgeLogger.shared.logEvent(event: event, data: data, module: "JSBridge")

        let script: String
        let resultDict: [String: Any] = ["event": event, "data": data]

        if let jsonString = try? JSONSerialization.data(withJSONObject: resultDict, options: []),
           let jsonString = String(data: jsonString, encoding: .utf8) {
            script = "window.BarkBridge.receiveEvent('\(event)', \(jsonString).data);"
        } else {
            // 如果 JSON 序列化失败，直接传递原始值（如果是简单类型）
            if let strData = data as? String {
                script = "window.BarkBridge.receiveEvent('\(event)', '\(strData)');"
            } else {
                script = "window.BarkBridge.receiveEvent('\(event)', \(data));"
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(script, completionHandler: { jsResult, error in
                if let error = error {
                    WebBridgeLogger.shared.error("Event delivery failed: \(error.localizedDescription)")
                }
            })
        }
    }

    // MARK: - Set WebView

    public func setWebView(_ webView: WKWebView) {
        self.webView = webView
        // 为已创建的 Handler 设置 webView（懒加载模式下，Handler 在 getHandler 时自动设置）
        handlersLock.lock()
        let createdHandlers = Array(nativeHandlers.values)
        handlersLock.unlock()

        for handler in createdHandlers {
            if let baseHandler = handler as? BaseWebNativeHandler {
                baseHandler.webView = webView
            }
        }

        print("🔗 [JS Bridge] WebView 已设置，已创建 \(createdHandlers.count) 个 Handler")
    }
}


