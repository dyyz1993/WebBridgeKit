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
    private var managedAppID: String?
    private var managedDocumentURL: URL?
    public weak var permissionConsentPresenter: HTMLAppPermissionConsentPresenting?
    private let trustRegistry: HTMLAppTrustRegistry
    private let permissionLedger: HTMLAppPermissionLedger
    private let capabilityGateway: HTMLAppCapabilityGateway
    private struct PendingAuthorization {
        let appID: String
        let documentURL: URL
        let request: HTMLAppCapabilityRequest
        let completion: (AuthorizationDecision) -> Void
    }
    private let pendingAuthorizationsLock = NSLock()
    private var pendingAuthorizations: [String: PendingAuthorization] = [:]
    private var permissionRevocationObserver: NSObjectProtocol?
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

    public override convenience init() {
        self.init(
            trustRegistry: HTMLAppTrustRegistry(),
            permissionLedger: .shared,
            nativeAuthorizationProvider: HTMLAppSystemAuthorizationProvider()
        )
    }

    public init(
        trustRegistry: HTMLAppTrustRegistry,
        permissionLedger: HTMLAppPermissionLedger,
        nativeAuthorizationProvider: HTMLAppNativeAuthorizationProviding
    ) {
        self.trustRegistry = trustRegistry
        self.permissionLedger = permissionLedger
        capabilityGateway = HTMLAppCapabilityGateway(
            trustRegistry: trustRegistry,
            permissionLedger: permissionLedger,
            nativeAuthorizationProvider: nativeAuthorizationProvider
        )
        super.init()
        permissionConsentPresenter = HTMLAppPermissionPromptPresenter.shared
        permissionRevocationObserver = NotificationCenter.default.addObserver(
            forName: .htmlAppPermissionDidRevoke,
            object: permissionLedger,
            queue: nil
        ) { [weak self] notification in
            self?.handlePermissionRevocation(notification)
        }
        registerHandlerFactories()  // 只注册工厂方法，不创建实例
    }

    deinit {
        endManagedHTMLAppSession()
        if let permissionRevocationObserver {
            NotificationCenter.default.removeObserver(permissionRevocationObserver)
        }
    }

    // MARK: - WKScriptMessageHandler

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any] else {
            WebBridgeLogger.shared.error("Invalid message format")
            sendErrorToJS("Invalid message format", callbackId: nil)
            return
        }
        handle(body: body) { [weak self] result, callbackID in
            self?.sendResultToJS(result, callbackId: callbackID)
        }
    }

    public func configureManagedHTMLApp(appID: String?, documentURL: URL?) {
        let previousAppID = managedAppID
        let previousURL = managedDocumentURL
        let previousOrigin = previousURL.flatMap(HTMLAppOrigin.canonicalOrigin(forDocumentURL:))
        let nextOrigin = documentURL.flatMap(HTMLAppOrigin.canonicalOrigin(forDocumentURL:))
        if let previousAppID,
           previousAppID != appID || previousOrigin != nextOrigin {
            endManagedHTMLAppSession(appID: previousAppID, documentURL: previousURL)
        }
        managedAppID = appID
        managedDocumentURL = documentURL
    }

    public func updateManagedHTMLAppDocumentURL(_ documentURL: URL?) {
        configureManagedHTMLApp(appID: managedAppID, documentURL: documentURL)
    }

    public func endManagedHTMLAppSession() {
        endManagedHTMLAppSession(appID: managedAppID, documentURL: managedDocumentURL ?? webView?.url)
        managedAppID = nil
        managedDocumentURL = nil
    }

    private func endManagedHTMLAppSession(appID: String?, documentURL: URL?) {
        guard let appID else { return }
        cancelPendingAuthorizations(appID: appID)
        guard let documentURL,
              let origin = HTMLAppOrigin.canonicalOrigin(forDocumentURL: documentURL) else { return }
        permissionLedger.revokeSessionGrants(appID: appID, origin: origin)
    }

    private func handlePermissionRevocation(_ notification: Notification) {
        guard let revocation = notification.userInfo?[HTMLAppPermissionRevocationNotification.payloadKey]
                as? HTMLAppPermissionRevocation,
              revocation.appID == managedAppID else {
            return
        }
        let documentURL = webView?.url ?? managedDocumentURL
        guard let documentURL,
              HTMLAppOrigin.canonicalOrigin(forDocumentURL: documentURL) == revocation.origin else {
            return
        }

        handlersLock.lock()
        let handlers = nativeHandlers.compactMap { action, handler -> HTMLAppCapabilityRevocationHandling? in
            guard HTMLAppBridgeCapabilityPolicy.capability(for: action, body: [:]) == revocation.capability else {
                return nil
            }
            return handler as? HTMLAppCapabilityRevocationHandling
        }
        handlersLock.unlock()

        DispatchQueue.main.async {
            handlers.forEach { $0.htmlAppCapabilityDidRevoke() }
        }
    }

    /// Shared dispatch path for WKScriptMessageHandler and host containers that
    /// proxy script messages through their own navigation controller.
    public func handle(
        body: [String: Any],
        completion: @escaping (_ result: Any, _ callbackID: String?) -> Void
    ) {
        guard let action = body["action"] as? String else {
            completion(WebBridgeResponse.error(code: 400, message: "Invalid message format"), nil)
            return
        }

        //  Security: Validate command against allowlist
        guard Self.ALLOWED_COMMANDS.contains(action) else {
            let error = "Command not allowed: \(action)"
            Log.error(error, category: .general)
            WebBridgeLogger.shared.log(.error, "[JS Bridge] \(error)")
            StructuredLogger.shared.error("[FAIL] [JS Bridge] Blocked unknown command: \(action)", category: .bridge)

            // 添加到历史记录（标记为失败）
            let callbackId = body["callbackId"] as? String ?? body["messageId"] as? String
            let trace = CommandTraceEntry(
                action: action,
                input: body,
                timestamp: Date(),
                callbackId: callbackId,
                status: .failed
            )
            addCommandToHistory(trace)

            completion(WebBridgeResponse.error(code: 403, message: error), callbackId)
            return
        }

        // 获取 callbackId，避免并发时被覆盖。旧版 WebBridge.js 使用 messageId，
        // 这里保留兼容，避免真实 WKWebView Promise 回调无法 resolve。
        let callbackId = body["callbackId"] as? String ?? body["messageId"] as? String

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
            completion(WebBridgeResponse.error(code: 404, message: "Unsupported action: \(action)"), callbackId)

            // 更新跟踪状态为失败
            updateCommandStatus(action: action, status: .failed, error: "Unsupported action")

            return
        }

        authorizeIfNeeded(action: action, body: body) { [weak self] authorization in
            guard let self else {
                completion(Self.authorizationError(
                    capability: HTMLAppBridgeCapabilityPolicy.capability(for: action, body: body) ?? .deviceControl,
                    status: .denied,
                    message: "PWA 容器已关闭"
                ), callbackId)
                return
            }
            switch authorization {
            case .allowed:
                self.updateCommandStatus(action: action, status: .executing)
                DispatchQueue.global(qos: .userInitiated).async {
                    handler.handle(body: body) { [weak self] result in
                        self?.updateCommandStatus(action: action, status: .succeeded, result: result)
                        completion(result, callbackId)
                    }
                }
            case .denied(let result):
                self.updateCommandStatus(action: action, status: .failed, error: result["error"] as? String)
                completion(result, callbackId)
            }
        }
    }

    private enum AuthorizationDecision {
        case allowed
        case denied([String: Any])
    }

    private func authorizeIfNeeded(
        action: String,
        body: [String: Any],
        completion: @escaping (AuthorizationDecision) -> Void
    ) {
        guard let capability = HTMLAppBridgeCapabilityPolicy.capability(for: action, body: body) else {
            completion(.allowed)
            return
        }
        let liveURL = webView?.url.flatMap {
            HTMLAppOrigin.canonicalOrigin(forDocumentURL: $0) == nil ? nil : $0
        }
        guard let appID = managedAppID,
              let documentURL = liveURL ?? managedDocumentURL,
              let manifest = trustRegistry.manifest(for: appID) else {
            completion(.denied(Self.authorizationError(
                capability: capability,
                status: .denied,
                message: "该页面不是已验证的 PWA，不能调用受保护的原生能力"
            )))
            return
        }
        let params = body["params"] as? [String: Any] ?? body
        let requestID = UUID().uuidString
        let reason = (params["reason"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = HTMLAppCapabilityRequest(
            id: requestID,
            capability: capability,
            reason: reason?.isEmpty == false ? reason! : "使用\(capability.displayName)完成当前操作",
            scope: .once
        )
        let result = capabilityGateway.requestAuthorization(appID: appID, documentURL: documentURL, request: request)
        switch (result.status, result.authorizationLayer) {
        case (.granted, _), (.notDetermined, .nativeSystem):
            completion(.allowed)
        case (.notDetermined, .htmlApp):
            guard let origin = HTMLAppOrigin.canonicalOrigin(forDocumentURL: documentURL),
                  let presenter = permissionConsentPresenter else {
                capabilityGateway.cancelAuthorization(appID: appID, requestID: request.id)
                completion(.denied(Self.authorizationError(
                    capability: capability,
                    status: .denied,
                    message: "无法显示 PWA 权限确认"
                )))
                return
            }
            storePendingAuthorization(PendingAuthorization(
                appID: appID,
                documentURL: documentURL,
                request: request,
                completion: completion
            ))
            presenter.requestConsent(HTMLAppPermissionConsentRequest(
                application: .init(id: appID, name: manifest.name),
                requestID: request.id,
                origin: origin,
                capability: capability,
                reason: request.reason
            )) { [weak self] selectedScope in
                self?.finishPendingAuthorization(requestID: request.id, selectedScope: selectedScope)
            }
        default:
            completion(.denied(Self.authorizationError(
                capability: capability,
                status: result.status,
                message: result.status == .requiresSettings
                    ? "iOS 系统权限已关闭，请前往系统设置开启"
                    : "PWA 未获得该原生能力授权"
            )))
        }
    }

    private func storePendingAuthorization(_ pending: PendingAuthorization) {
        pendingAuthorizationsLock.lock()
        pendingAuthorizations[pending.request.id] = pending
        pendingAuthorizationsLock.unlock()
    }

    private func takePendingAuthorization(requestID: String) -> PendingAuthorization? {
        pendingAuthorizationsLock.lock()
        let pending = pendingAuthorizations.removeValue(forKey: requestID)
        pendingAuthorizationsLock.unlock()
        return pending
    }

    private func finishPendingAuthorization(
        requestID: String,
        selectedScope: HTMLAppPermissionScope?
    ) {
        guard let pending = takePendingAuthorization(requestID: requestID) else { return }
        guard let selectedScope else {
            capabilityGateway.cancelAuthorization(appID: pending.appID, requestID: requestID)
            pending.completion(.denied(Self.authorizationError(
                capability: pending.request.capability,
                status: .denied,
                message: "用户已取消授权"
            )))
            return
        }

        let selectedRequest = HTMLAppCapabilityRequest(
            id: pending.request.id,
            capability: pending.request.capability,
            reason: pending.request.reason,
            scope: selectedScope
        )
        let resolved = capabilityGateway.resolveUserConsent(
            appID: pending.appID,
            documentURL: pending.documentURL,
            request: selectedRequest,
            granted: true
        )
        if resolved.status == .granted ||
            (resolved.status == .notDetermined && resolved.authorizationLayer == .nativeSystem) {
            pending.completion(.allowed)
        } else {
            pending.completion(.denied(Self.authorizationError(
                capability: pending.request.capability,
                status: resolved.status,
                message: resolved.status == .requiresSettings
                    ? "iOS 系统权限已关闭，请前往系统设置开启"
                    : "原生能力授权失败"
            )))
        }
    }

    private func cancelPendingAuthorizations(appID: String) {
        pendingAuthorizationsLock.lock()
        let cancelled = pendingAuthorizations.values.filter { $0.appID == appID }
        cancelled.forEach { pendingAuthorizations.removeValue(forKey: $0.request.id) }
        pendingAuthorizationsLock.unlock()

        cancelled.forEach { pending in
            capabilityGateway.cancelAuthorization(appID: pending.appID, requestID: pending.request.id)
            permissionConsentPresenter?.cancelConsent(
                appID: pending.appID,
                requestID: pending.request.id
            )
            pending.completion(.denied(Self.authorizationError(
                capability: pending.request.capability,
                status: .denied,
                message: "PWA 已关闭或页面来源已变更"
            )))
        }
    }

    private static func authorizationError(
        capability: HTMLAppCapability,
        status: HTMLAppCapabilityResult.Status,
        message: String
    ) -> [String: Any] {
        [
            "success": false,
            "error": message,
            "code": "PWA_CAPABILITY_DENIED",
            "capability": capability.rawValue,
            "status": status.rawValue
        ]
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
            resultDict["messageId"] = callbackId
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
