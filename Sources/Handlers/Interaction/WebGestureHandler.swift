//
//  WebGestureHandler.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-15.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import WebKit

// Framework imports

/// 手势配置
public struct WebGestureConfig {

    // MARK: - Gesture Types

    public enum GestureType: String {
        case pull           // 下拉
        case swipeLeft      // 左滑
        case swipeRight     // 右滑
        case swipeUp        // 上滑
        case swipeDown      // 下滑
        case longPress      // 长按
        case doubleTap      // 双击
        case pinch          // 缩放

        public static func from(string: String) -> GestureType? {
            return GestureType(rawValue: string)
        }
    }

    // MARK: - Pull States

    public enum PullState: String {
        case idle           // 空闲
        case pulling        // 拖动中
        case triggered      // 触发（达到阈值）
        case loading        // 加载中
        case completed      // 完成
        case cancelled      // 取消

        public static func from(string: String) -> PullState? {
            return PullState(rawValue: string)
        }
    }

    // MARK: - Properties

    /// 是否启用手势监控
    public var enabled: Bool

    /// 启用的手势类型
    public var enabledGestures: Set<GestureType>

    // 下拉相关配置
    /// 下拉触发阈值（屏幕高度百分比，0-1）
    public var pullThreshold: CGFloat

    /// 下拉最大距离（屏幕高度百分比，0-1）
    public var pullMaxDistance: CGFloat

    /// 是否显示视觉反馈
    public var showVisualFeedback: Bool

    /// 是否自动回弹
    public var autoBounceBack: Bool

    // MARK: - Initialization

    public init(
        enabled: Bool = true,
        enabledGestures: Set<GestureType> = [.pull],
        pullThreshold: CGFloat = 0.15,      // 15% 屏幕高度
        pullMaxDistance: CGFloat = 0.25,    // 25% 屏幕高度
        showVisualFeedback: Bool = true,
        autoBounceBack: Bool = true
    ) {
        self.enabled = enabled
        self.enabledGestures = enabledGestures
        self.pullThreshold = pullThreshold
        self.pullMaxDistance = pullMaxDistance
        self.showVisualFeedback = showVisualFeedback
        self.autoBounceBack = autoBounceBack
    }

    /// 从字典创建配置
    public static func from(dict: [String: Any]) -> WebGestureConfig {
        let enabled = dict["enabled"] as? Bool ?? true

        var enabledGestures: Set<GestureType> = []
        if let gestures = dict["gestures"] as? [String] {
            for gesture in gestures {
                if let type = GestureType.from(string: gesture) {
                    enabledGestures.insert(type)
                }
            }
        }
        if enabledGestures.isEmpty {
            enabledGestures = [.pull]
        }

        let pullThreshold = (dict["pullThreshold"] as? CGFloat ?? 0.15)
        let pullMaxDistance = (dict["pullMaxDistance"] as? CGFloat ?? 0.25)
        let showVisualFeedback = dict["showVisualFeedback"] as? Bool ?? true
        let autoBounceBack = dict["autoBounceBack"] as? Bool ?? true

        return WebGestureConfig(
            enabled: enabled,
            enabledGestures: enabledGestures,
            pullThreshold: pullThreshold,
            pullMaxDistance: pullMaxDistance,
            showVisualFeedback: showVisualFeedback,
            autoBounceBack: autoBounceBack
        )
    }

    /// 默认配置
    public static let `default` = WebGestureConfig()

    /// 禁用所有手势
    public static let disabled = WebGestureConfig(enabled: false, enabledGestures: [])
}

/// 手势事件处理器
public class WebGestureHandler: BaseWebNativeHandler {

    // MARK: - Properties

    private var config: WebGestureConfig = .default
    private weak var currentWebView: WKWebView?

    // 下拉状态
    private var pullState: WebGestureConfig.PullState = .idle
    private var pullStartY: CGFloat = 0
    private var currentPullDistance: CGFloat = 0

    // MARK: - Handle

    public override func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
        let params = body["params"] as? [String: Any] ?? body
        let action = params["action"] as? String ?? ""

        WebBridgeLogger.shared.log(.info, "[WebGestureHandler] Handling action: \(action)")

        // 如果没有指定子操作，返回手势配置状态
        if action.isEmpty {
            getConfigStatus(completion: completion)
            return
        }

        switch action {
        case "config":
            configure(params, completion: completion)

        case "enable":
            let gestures = params["gestures"] as? [String]
            enableGestures(gestures, completion: completion)

        case "disable":
            let gestures = params["gestures"] as? [String]
            disableGestures(gestures, completion: completion)

        case "setPullThreshold":
            let threshold = params["threshold"] as? CGFloat ?? 0.15
            setPullThreshold(threshold, completion: completion)

        case "startPullRefresh":
            // JS 通知开始加载
            startPullRefresh(completion: completion)

        case "stopPullRefresh":
            // JS 通知加载完成
            stopPullRefresh(completion: completion)

        case "cancelPullRefresh":
            // JS 通知取消加载
            cancelPullRefresh(completion: completion)

        default:
            self.reject(error: "Unsupported action: \(action)", code: 404, completion: completion)
        }
    }

    /// 获取手势配置状态
    private func getConfigStatus(completion: @escaping (Any) -> Void) {
        self.resolve([
            "enabled": config.enabled,
            "enabledGestures": config.enabledGestures.map { $0.rawValue },
            "pullThreshold": config.pullThreshold,
            "pullMaxDistance": config.pullMaxDistance,
            "showVisualFeedback": config.showVisualFeedback,
            "autoBounceBack": config.autoBounceBack
        ], completion: completion)
    }

    // MARK: - Actions

    private func configure(_ params: [String: Any], completion: @escaping (Any) -> Void) {
        let newConfig = WebGestureConfig.from(dict: params)
        self.config = newConfig

        WebBridgeLogger.shared.log(.info, "[WebGestureHandler] Config updated: \(params)")

        // 通知 WebView 更新手势配置
        runOnMainThread { [weak self] in
            self?.notifyConfigUpdate()
            self?.resolve([
                "success": true,
                "config": [
                    "enabled": newConfig.enabled,
                    "gestures": newConfig.enabledGestures.map { $0.rawValue },
                    "pullThreshold": newConfig.pullThreshold
                ]
            ], completion: completion)
        }
    }

    private func enableGestures(_ gestures: [String]?, completion: @escaping (Any) -> Void) {
        if let gestures = gestures {
            for gesture in gestures {
                if let type = WebGestureConfig.GestureType.from(string: gesture) {
                    config.enabledGestures.insert(type)
                }
            }
        } else {
            config.enabled = true
        }

        runOnMainThread { [weak self] in
            self?.notifyConfigUpdate()
            self?.resolve([
                "success": true,
                "enabledGestures": self?.config.enabledGestures.map { $0.rawValue } ?? []
            ], completion: completion)
        }
    }

    private func disableGestures(_ gestures: [String]?, completion: @escaping (Any) -> Void) {
        if let gestures = gestures {
            for gesture in gestures {
                if let type = WebGestureConfig.GestureType.from(string: gesture) {
                    config.enabledGestures.remove(type)
                }
            }
        } else {
            config.enabled = false
        }

        runOnMainThread { [weak self] in
            self?.notifyConfigUpdate()
            self?.resolve([
                "success": true,
                "enabledGestures": self?.config.enabledGestures.map { $0.rawValue } ?? []
            ], completion: completion)
        }
    }

    private func setPullThreshold(_ threshold: CGFloat, completion: @escaping (Any) -> Void) {
        config = WebGestureConfig(
            enabled: config.enabled,
            enabledGestures: config.enabledGestures,
            pullThreshold: threshold,
            pullMaxDistance: config.pullMaxDistance,
            showVisualFeedback: config.showVisualFeedback,
            autoBounceBack: config.autoBounceBack
        )

        runOnMainThread { [weak self] in
            self?.notifyConfigUpdate()
            self?.resolve([
                "success": true,
                "pullThreshold": threshold
            ], completion: completion)
        }
    }

    private func startPullRefresh(completion: @escaping (Any) -> Void) {
        pullState = .loading

        runOnMainThread { [weak self] in
            // 通知 WebView 进入加载状态
            self?.sendGestureEvent(
                type: "pull",
                event: "loading",
                data: ["state": "loading"]
            )
            self?.resolve(["success": true, "state": "loading"], completion: completion)
        }
    }

    private func stopPullRefresh(completion: @escaping (Any) -> Void) {
        pullState = .completed

        runOnMainThread { [weak self] in
            self?.sendGestureEvent(
                type: "pull",
                event: "completed",
                data: ["state": "completed"]
            )
            self?.resolve(["success": true, "state": "completed"], completion: completion)
        }
    }

    private func cancelPullRefresh(completion: @escaping (Any) -> Void) {
        pullState = .cancelled

        runOnMainThread { [weak self] in
            self?.sendGestureEvent(
                type: "pull",
                event: "cancelled",
                data: ["state": "cancelled"]
            )
            self?.resolve(["success": true, "state": "cancelled"], completion: completion)
        }
    }

    // MARK: - Public Methods for Gesture Interceptor

    /// 设置当前 WebView（由 WebViewController 调用）
    public func setCurrentWebView(_ webView: WKWebView) {
        self.currentWebView = webView
        self.webView = webView
    }

    /// 获取当前配置
    public func getConfig() -> WebGestureConfig {
        return config
    }

    /// 处理下拉开始
    public func handlePullStart(at startY: CGFloat) {
        guard config.enabled && config.enabledGestures.contains(.pull) else { return }
        guard pullState == .idle || pullState == .cancelled || pullState == .completed else { return }

        pullState = .pulling
        pullStartY = startY
        currentPullDistance = 0

        sendGestureEvent(
            type: "pull",
            event: "start",
            data: [
                "startY": startY,
                "state": "pulling"
            ]
        )

        WebBridgeLogger.shared.log(.info, "[WebGestureHandler] Pull started at: \(startY)")
    }

    /// 处理下拉移动
    public func handlePullMove(distance: CGFloat, threshold: CGFloat, maxDistance: CGFloat) {
        guard config.enabled && config.enabledGestures.contains(.pull) else { return }
        guard pullState == .pulling || pullState == .triggered else { return }

        currentPullDistance = distance

        // 计算进度（0-1）
        let progress = min(max(distance / threshold, 0), 1)

        // 检查是否达到触发阈值
        let wasTriggered = pullState == .triggered
        let isTriggered = distance >= threshold

        if isTriggered && !wasTriggered {
            pullState = .triggered
            sendGestureEvent(
                type: "pull",
                event: "triggered",
                data: [
                    "distance": distance,
                    "progress": progress,
                    "state": "triggered"
                ]
            )
        } else {
            sendGestureEvent(
                type: "pull",
                event: "move",
                data: [
                    "distance": distance,
                    "progress": progress,
                    "threshold": threshold,
                    "maxDistance": maxDistance,
                    "state": pullState.rawValue
                ]
            )
        }
    }

    /// 处理下拉释放
    public func handlePullRelease(threshold: CGFloat) {
        guard config.enabled && config.enabledGestures.contains(.pull) else { return }

        let wasTriggered = pullState == .triggered

        if wasTriggered {
            // 达到阈值，触发刷新
            pullState = .loading
            sendGestureEvent(
                type: "pull",
                event: "release",
                data: [
                    "triggered": true,
                    "distance": currentPullDistance,
                    "state": "loading"
                ]
            )
        } else {
            // 未达到阈值，取消
            pullState = .cancelled
            sendGestureEvent(
                type: "pull",
                event: "release",
                data: [
                    "triggered": false,
                    "distance": currentPullDistance,
                    "state": "cancelled"
                ]
            )
        }

        currentPullDistance = 0
    }

    /// 处理下拉取消
    public func handlePullCancel() {
        guard pullState == .pulling || pullState == .triggered else { return }

        pullState = .cancelled
        currentPullDistance = 0

        sendGestureEvent(
            type: "pull",
            event: "cancel",
            data: ["state": "cancelled"]
        )
    }

    // MARK: - Private Methods

    private func notifyConfigUpdate() {
        sendGestureEvent(
            type: "config",
            event: "updated",
            data: [
                "enabled": config.enabled,
                "gestures": Array(config.enabledGestures.map { $0.rawValue }),
                "pullThreshold": config.pullThreshold
            ]
        )
    }

    // MARK: - Send Gesture Event (Internal for Interceptor)

    func sendGestureEvent(type: String, event: String, data: [String: Any]) {
        let eventData: [String: Any] = [
            "gestureType": type,
            "event": event,
            "data": data
        ]

        runOnMainThread { [weak self] in
            self?.sendEventToJS(event: "onGesture", data: eventData)
        }
    }
}

// MARK: - Gesture State Struct

public extension WebGestureHandler {

    /// 手势状态信息
    struct GestureState {
        public let type: String
        public let event: String
        public let data: [String: Any]
        public let timestamp: Date

        public init(type: String, event: String, data: [String: Any]) {
            self.type = type
            self.event = event
            self.data = data
            self.timestamp = Date()
        }
    }
}
