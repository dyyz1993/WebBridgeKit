//
//  WebJavaScriptBridge.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-13.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import WebKit

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

    // MARK: - Command Trace History

    /// 命令执行历史记录（最多保留 100 条）
    private var commandHistory: [CommandTraceEntry] = []
    private let historyLock = NSLock()
    private let maxHistorySize = 100

    // MARK: - Security: Command Allowlist

    /// 允许的 JS Bridge 命令列表（安全边界）
    /// 在开发模式下可以放宽限制，但生产环境必须严格验证
    private static let ALLOWED_COMMANDS: Set<String> = [
        // 基础功能
        "share",
        "getLocation",
        "requestPermission",
        // 系统信息
        "getSystemInfo",
        "getNetworkInfo",
        // 交互反馈
        "haptic",
        "vibrate",
        // 剪贴板
        "clipboard",
        // 扫码
        "scan",
        // 相机
        "camera",
        // 视频流
        "videoStream",
        // 语音识别
        "speech",
        // 实时音频音量监控
        "audioLevel",
        // 通讯录
        "contacts",
        // 屏幕控制
        "screen",
        // 布局控制
        "layout",
        // 投屏控制
        "mirroring",
        // 传感器控制
        "sensors",
        // 媒体与文件
        "media",
        // 系统增强
        "systemExtra",
        // 语音合成
        "tts",
        // 蓝牙控制
        "bluetooth",
        // 文件选择
        "file",
        // 权限状态查询
        "getPermissionStatus",
        // 打开系统设置
        "openSettings",
        // 打开本地页面
        "openPage",
        // 关闭当前页面
        "closePage",
        // 获取导航历史
        "getHistory",
        // 获取透传参数
        "getPayload",
        // 后退
        "goBack",
        // 设置弹窗参数
        "setModal",
        // 手势监控
        "gesture",
        // 缓存调试
        "cacheDebug",
        // 页面缓存管理
        "page",
        // 本地通知（非 APNs）
        "showNotification",
        // 相册选择 (iOS 14+)
        "photo"
    ]

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
            sendErrorToJS("Invalid message format", callbackId: nil)
            return
        }

        // 🔒 Security: Validate command against allowlist
        guard Self.ALLOWED_COMMANDS.contains(action) else {
            let error = "Command not allowed: \(action)"
            Log.error(error, category: .general)
            WebBridgeLogger.shared.log(.error, "[JS Bridge] \(error)")
            StructuredLogger.shared.error("[FAIL] [JS Bridge] Blocked unknown command: \(action)", category: .bridge)

            // 添加到历史记录（标记为失败）
            let trace = CommandTraceEntry(
                action: action,
                input: body,
                timestamp: Date(),
                callbackId: body["callbackId"] as? String,
                status: .failed
            )
            addCommandToHistory(trace)

            sendErrorToJS(error, callbackId: body["callbackId"] as? String)
            return
        }

        // 获取 callbackId，避免并发时被覆盖
        let callbackId = body["callbackId"] as? String

        // 创建命令跟踪条目
        let trace = CommandTraceEntry(
            action: action,
            input: body,
            timestamp: Date(),
            callbackId: callbackId,
            status: .received
        )

        // 添加到历史记录
        addCommandToHistory(trace)

        guard let handler = getHandler(for: action) else {
            WebBridgeLogger.shared.error("Unsupported action: \(action)")
            sendErrorToJS("Unsupported action: \(action)", callbackId: callbackId)

            // 更新跟踪状态为失败
            updateCommandStatus(action: action, status: .failed, error: "Unsupported action")

            return
        }

        // 更新跟踪状态为执行中
        updateCommandStatus(action: action, status: .executing)

        // 异步处理，避免阻塞主线程
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            handler.handle(body: body) { [weak self] result in
                // 更新跟踪状态为成功
                self?.updateCommandStatus(action: action, status: .succeeded, result: result)

                self?.sendResultToJS(result, callbackId: callbackId)
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

        // 获取透传参数
        handlerFactories["getPayload"] = { WebPayloadHandler() }

        // 后退
        handlerFactories["goBack"] = { WebGoBackHandler() }

        // 设置弹窗参数
        handlerFactories["setModal"] = { WebSetModalHandler() }

        // 手势监控
        handlerFactories["gesture"] = { WebGestureHandler() }

        // 缓存调试
        handlerFactories["cacheDebug"] = { WebCacheDebugHandler() }

        // 页面缓存管理
        handlerFactories["page"] = { WebPageCacheHandler() }

        // 本地通知（非 APNs）
        handlerFactories["showNotification"] = { WebShowNotificationHandler() }

        StructuredLogger.shared.debug("[BRIDGE] [JS Bridge] 已注册 \(handlerFactories.count) 个 Handler 工厂（懒加载模式）", category: .handler)
        StructuredLogger.shared.debug("   工厂列表: \(Array(handlerFactories.keys).sorted())", category: .handler)
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
        if let baseHandler = handler as? BaseWebNativeHandler {
            if let webView = self.webView {
                baseHandler.webView = webView
            } else {
            }
        }

        StructuredLogger.shared.debug("[RECYCLE] [JS Bridge] 懒加载创建 Handler: \(action)", category: .handler)
        return handler
    }

    // MARK: - Send Result to JS

    public func sendResultToJS(_ result: Any, callbackId: String?) {
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

        // 设置 callbackId（关键！）
        if let callbackId = callbackId {
            resultDict["callbackId"] = callbackId
        } else {
        }

        let script: String
        if let jsonString = try? JSONSerialization.data(withJSONObject: resultDict, options: []),
           let jsonStr = String(data: jsonString, encoding: .utf8) {
            // 记录发送到 JS 的数据
            WebBridgeLogger.shared.log(.info, "[JS Bridge] Sending to JS: \(jsonStr.prefix(200))")
            script = "window.BarkBridge.receiveResult(\(jsonStr));"
        } else {
            // 如果 JSON 序列化失败，使用简单的字符串
            script = "window.BarkBridge.receiveResult({'success': false, 'error': 'JSON serialization failed'});"
        }

        DispatchQueue.main.async { [weak self] in
            guard let webView = self?.webView else {
                WebBridgeLogger.shared.error("[JS Bridge] Failed to send result: webView is nil")
                return
            }
            webView.evaluateJavaScript(script, completionHandler: { _, error in
                if let error = error {
                    WebBridgeLogger.shared.error("JavaScript execution failed: \(error.localizedDescription)")
                }
            })
        }
    }

    public func sendErrorToJS(_ error: String, callbackId: String?) {
        let result: [String: Any] = ["success": false, "error": error]
        sendResultToJS(result, callbackId: callbackId)
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
            self?.webView?.evaluateJavaScript(script, completionHandler: { _, error in
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

        StructuredLogger.shared.debug("[LINK] [JS Bridge] WebView 已设置，已创建 \(createdHandlers.count) 个 Handler", category: .handler)
    }

    // MARK: - Command Trace History Management

    /// 添加命令到历史记录
    /// - Parameter trace: 命令跟踪条目
    private func addCommandToHistory(_ trace: CommandTraceEntry) {
        historyLock.lock()
        defer { historyLock.unlock() }

        commandHistory.append(trace)

        // 限制历史记录大小（FIFO）
        if commandHistory.count > maxHistorySize {
            commandHistory.removeFirst()
        }

        NSLog("[NOTE] [JS Bridge] Added command to history: \(trace.action) (total: \(commandHistory.count))")
    }

    /// 更新命令状态
    /// - Parameters:
    ///   - action: 命令名称
    ///   - status: 新状态
    ///   - result: 成功结果（可选）
    ///   - error: 错误信息（可选）
    private func updateCommandStatus(action: String, status: CommandTraceEntry.Status, result: Any? = nil, error: String? = nil) {
        historyLock.lock()
        defer { historyLock.unlock() }

        // 查找并更新最新的同名命令
        if let index = commandHistory.lastIndex(where: { $0.action == action }) {
            var entry = commandHistory[index]
            entry.status = status
            entry.result = result
            entry.error = error
            entry.completedAt = status == .received ? nil : Date()
            commandHistory[index] = entry

            let logMessage: String
            switch status {
            case .succeeded:
                logMessage = "[OK] Command succeeded: \(action)"
            case .failed:
                logMessage = "[FAIL] Command failed: \(action) - \(error ?? "Unknown error")"
            case .executing:
                logMessage = "⏳ Command executing: \(action)"
            case .received:
                logMessage = "[RECV] Command received: \(action)"
            }

            NSLog(logMessage)
        }
    }

    /// 获取最近的命令历史记录
    /// - Parameter limit: 最大返回数量（默认 20）
    /// - Returns: 命令跟踪条目数组
    public func getCommandHistory(limit: Int = 20) -> [CommandTraceEntry] {
        historyLock.lock()
        defer { historyLock.unlock() }

        let count = min(limit, commandHistory.count)
        return Array(commandHistory.suffix(count))
    }

    /// 清空命令历史记录
    public func clearCommandHistory() {
        historyLock.lock()
        defer { historyLock.unlock() }

        commandHistory.removeAll()
        NSLog("[DEL] [JS Bridge] Cleared command history")
    }

    /// 按操作名称筛选命令历史
    /// - Parameter action: 操作名称
    /// - Returns: 匹配的命令历史记录
    public func getCommandsByAction(_ action: String) -> [CommandTraceEntry] {
        historyLock.lock()
        defer { historyLock.unlock() }

        return commandHistory.filter { $0.action == action }
    }
}

// MARK: - Command Trace Entry

/// 命令跟踪条目（用于调试和历史记录）
public struct CommandTraceEntry {
    /// 操作名称
    public let action: String

    /// 输入参数
    public let input: [String: Any]

    /// 时间戳
    public let timestamp: Date

    /// 回调 ID
    public let callbackId: String?

    /// 状态
    public var status: Status

    /// 执行结果
    public var result: Any?

    /// 错误信息
    public var error: String?

    /// 完成时间
    public var completedAt: Date?

    /// 命令执行状态
    public enum Status {
        case received      // 已接收
        case executing    // 执行中
        case succeeded    // 成功
        case failed       // 失败
    }

    /// 创建跟踪条目
    public init(action: String, input: [String: Any], timestamp: Date, callbackId: String?, status: Status) {
        self.action = action
        self.input = input
        self.timestamp = timestamp
        self.callbackId = callbackId
        self.status = status
        self.result = nil
        self.error = nil
        self.completedAt = nil
    }
}
