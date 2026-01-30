//
//  WebBridgePool.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-15.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import WebKit

// Framework imports

/// Bridge 预热池 - 单例模式
/// 负责 Bridge 实例和 Configuration 的预热与复用
public class WebBridgePool {

    // MARK: - Singleton

    public static let shared = WebBridgePool()

    private init() {
        setupWarmConfiguration()
    }

    // MARK: - Properties

    /// 预热的 Bridge 实例
    private var warmBridge: WebJavaScriptBridge?

    /// 预热的 Configuration
    private var warmConfiguration: WKWebViewConfiguration?

    /// 预热的 Bridge 脚本
    private var preheatedUserScript: WKUserScript?

    /// 线程安全锁
    private let lock = NSLock()

    // MARK: - 预热

    /// 预热 Bridge（在应用启动时调用）
    /// - Parameter completion: 完成回调
    public func warmup(completion: (() -> Void)? = nil) {
        // 在后台线程预热
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else {
                completion?()
                return
            }

            // 1. 创建 Bridge 实例
            let bridge = WebJavaScriptBridge()

            // 2. 预创建常用 Handler
            let commonHandlers = [
                "getSystemInfo", "share", "clipboard",
                "haptic", "vibrate", "getNetworkInfo",
                "openPage", "closePage"
            ]

            for handlerName in commonHandlers {
                _ = bridge.getHandler(for: handlerName)
            }

            self.lock.lock()
            self.warmBridge = bridge
            self.lock.unlock()

            WebBridgeLogger.shared.log(.info, "✅ [WebBridgePool] Bridge warmed up with \(commonHandlers.count) common handlers")
            completion?()
        }
    }

    /// 预热 Configuration
    private func setupWarmConfiguration() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.dataDetectorTypes = []

        // 注册自定义 URL Scheme Handler 用于离线缓存
        let schemeHandler = CacheURLSchemeHandler()
        config.setURLSchemeHandler(schemeHandler, forURLScheme: "bark-cache")

        // 预注入 Bridge 脚本
        let bridgeScript = getBridgeScript()
        let script = WKUserScript(
            source: bridgeScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(script)

        self.preheatedUserScript = script
        self.warmConfiguration = config

        WebBridgeLogger.shared.log(.info, "✅ [WebBridgePool] Configuration warmed up with bark-cache:// scheme")
    }

    // MARK: - 获取和回收

    /// 获取 Bridge 实例
    /// - Returns: 预热的 Bridge 实例或新创建的实例
    public func acquireBridge() -> WebJavaScriptBridge {
        lock.lock()
        let bridge = warmBridge
        warmBridge = nil
        lock.unlock()

        if let bridge = bridge {
            WebBridgeLogger.shared.log(.info, "♻️ [WebBridgePool] Acquired warm bridge")
            return bridge
        }

        WebBridgeLogger.shared.log(.info, "🆕 [WebBridgePool] Created new bridge")
        return WebJavaScriptBridge()
    }

    /// 回收 Bridge 实例
    /// - Parameter bridge: 要回收的 Bridge 实例
    public func recycleBridge(_ bridge: WebJavaScriptBridge) {
        lock.lock()
        // 只保留一个预热实例
        if warmBridge == nil {
            warmBridge = bridge
            WebBridgeLogger.shared.log(.info, "♻️ [WebBridgePool] Recycled bridge")
        } else {
            WebBridgeLogger.shared.log(.warning, "⚠️ [WebBridgePool] Pool full, bridge not recycled")
        }
        lock.unlock()
    }

    /// 获取预热的 Configuration
    /// - Returns: 预热的 Configuration 或新的 Configuration
    public func acquireConfiguration() -> WKWebViewConfiguration {
        lock.lock()
        let config = warmConfiguration
        lock.unlock()

        return config ?? WKWebViewConfiguration()
    }

    // MARK: - 内存管理

    /// 内存警告时清理
    public func didReceiveMemoryWarning() {
        lock.lock()
        warmBridge = nil
        lock.unlock()
        WebBridgeLogger.shared.log(.warning, "🧹 [WebBridgePool] Cleared warm bridge due to memory warning")
    }

    /// 清空所有缓存
    public func clearCache() {
        lock.lock()
        warmBridge = nil
        warmConfiguration = nil
        preheatedUserScript = nil
        lock.unlock()
        WebBridgeLogger.shared.log(.info, "🧹 [WebBridgePool] All cache cleared")
    }

    // MARK: - Helper

    /// 获取 Bridge 脚本
    private func getBridgeScript() -> String {
        return """
        window.BarkBridge = {
            callNative: function(action, params) {
                console.log('📤 [Bark] callNative:', action, params);
                return new Promise((resolve, reject) => {
                    const id = ++window.BarkBridge._callbackId;
                    window.BarkBridge._callbacks[id] = { resolve, reject };
                    const message = {
                        action: action,
                        params: params || {},
                        callbackId: String(id)
                    };
                    try {
                        window.webkit.messageHandlers.barkBridge.postMessage(message);
                    } catch (error) {
                        console.error('❌ [Bark] Failed:', error);
                        reject(error);
                    }
                });
            },
            _callbackId: 0,
            _callbacks: {},
            receiveResult: function(result) {
                console.log('📥 [Bark] Received result:', result);
                const id = result.callbackId;
                let callback = this._callbacks[id];
                if (callback) {
                    if (result.success !== false) {
                        callback.resolve(result);
                    } else {
                        callback.reject(new Error(result.error || 'Unknown error'));
                    }
                    delete this._callbacks[id];
                }
            },
            receiveEvent: function(event, data) {
                console.log('🔔 [Bark] Received event:', event, data);

                // 兼容旧的音频回调
                if (event === 'onAudioLevelChange' || event === 'onAudioLevel') {
                    if (window.onAudioLevel) window.onAudioLevel(data.level !== undefined ? data.level : data);
                    if (window.onAudioLevelChange) window.onAudioLevelChange(data.level !== undefined ? data.level : data);
                }

                // 手势事件回调
                if (event === 'onGesture') {
                    if (window.onGesture) window.onGesture(data);
                    const customEvent = new CustomEvent('bark_gesture', { detail: data });
                    window.dispatchEvent(customEvent);
                }

                // 触发全局 CustomEvent
                const customEvent = new CustomEvent('bark_' + event, { detail: data });
                window.dispatchEvent(customEvent);
            }
        };
        console.log('✅ [Bark] BarkBridge initialized');
        """
    }
}
