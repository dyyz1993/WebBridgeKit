//
//  WebMirroringHandler.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-14.
//

import UIKit
import WebKit

// Framework imports

/// 投屏与外部显示控制 Handler
/// 支持：投屏状态检测、全屏模式控制、投屏变化监听
public class WebMirroringHandler: BaseWebNativeHandler {

    // MARK: - Properties

    private var isObserving = false

    // MARK: - Handle

    /**
     * 处理 JS 调用
     * @param body 调用参数
     * @param completion 处理完成后的回调
     */
    public override func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
        let params = body["params"] as? [String: Any] ?? body
        let action = params["action"] as? String ?? ""

        WebBridgeLogger.shared.log(.info, "[WebMirroringHandler] Handling action: \(action)")

        // 如果没有指定子操作，返回投屏状态
        if action.isEmpty {
            getStatus(completion: completion)
            return
        }

        switch action {
        case "getStatus":
            getStatus(completion: completion)

        case "startObserve":
            startObserve(completion: completion)

        case "stopObserve":
            stopObserve(completion: completion)

        default:
            self.reject(error: "Unsupported action: \(action)", code: 404, completion: completion)
        }
    }

    // MARK: - Actions

    /**
     * 获取当前投屏状态
     * @param completion 返回结果
     */
    private func getStatus(completion: @escaping (Any) -> Void) {
        runOnMainThread { [weak self] in
            // iOS 中多于一个屏幕通常意味着正在投屏（AirPlay 或 HDMI）
            let mirroring = UIScreen.screens.count > 1
            self?.resolve([
                "isMirroring": mirroring,
                "screenCount": UIScreen.screens.count
            ], completion: completion)
        }
    }

    /**
     * 开始监听投屏变化
     * @param completion 返回结果
     */
    private func startObserve(completion: @escaping (Any) -> Void) {
        runOnMainThread { [weak self] in
            guard let self = self else { return }
            if !self.isObserving {
                NotificationCenter.default.addObserver(self, selector: #selector(self.screenDidConnect), name: UIScreen.didConnectNotification, object: nil)
                NotificationCenter.default.addObserver(self, selector: #selector(self.screenDidDisconnect), name: UIScreen.didDisconnectNotification, object: nil)
                self.isObserving = true
            }
            self.resolve(["status": "observing"], completion: completion)
        }
    }

    /**
     * 停止监听投屏变化
     * @param completion 返回结果
     */
    private func stopObserve(completion: @escaping (Any) -> Void) {
        runOnMainThread { [weak self] in
            guard let self = self else { return }
            self.isObserving = false
            self.resolve(["status": "stopped"], completion: completion)
        }
    }

    // MARK: - Notifications

    @objc private func screenDidConnect() {
        WebBridgeLogger.shared.log(.info, "[WebMirroringHandler] Screen connected")
        notifyJS(isMirroring: true)
    }

    @objc private func screenDidDisconnect() {
        WebBridgeLogger.shared.log(.info, "[WebMirroringHandler] Screen disconnected")
        notifyJS(isMirroring: false)
    }

    private func notifyJS(isMirroring: Bool) {
        let data: [String: Any] = [
            "isMirroring": isMirroring,
            "timestamp": Date().timeIntervalSince1970
        ]
        sendEventToJS(event: "onMirroringChange", data: data)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

fileprivate extension Dictionary {
    var jsonString: String? {
        guard let data = try? JSONSerialization.data(withJSONObject: self, options: []) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
