//
//  WebViewPool.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-15.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import WebKit

// Framework imports

/// WebView 实例池 - 支持 LRU 缓存策略
/// 负责预热、复用和管理 WebView 实例
public class WebViewPool {

    // MARK: - Singleton

    public static let shared = WebViewPool()

    private init() {
        observeMemoryWarning()
        observeEnterBackground()
        observeEnterForeground()
    }

    // MARK: - WebViewInstance

    /// WebView 实例包装
    public struct WebViewInstance {
        public let webView: WKWebView
        public let bridge: WebJavaScriptBridge
        public let createdAt: Date
        public var lastUsedAt: Date

        public init(webView: WKWebView, bridge: WebJavaScriptBridge) {
            self.webView = webView
            self.bridge = bridge
            self.createdAt = Date()
            self.lastUsedAt = Date()
        }
    }

    // MARK: - Properties

    /// 池配置
    private let maxPoolSize = 2
    private var pool: [WebViewInstance] = []

    /// 线程安全锁
    private let lock = NSLock()

    /// 性能监控
    private var hitCount = 0
    private var missCount = 0

    /// 是否已预热
    private var isWarmedUp = false

    // MARK: - 获取和回收

    /// 获取 WebView 实例
    /// - Returns: 池中的实例，如果池为空则返回 nil
    public func acquire() -> WebViewInstance? {
        lock.lock()
        defer { lock.unlock() }

        if let instance = pool.first {
            pool.removeFirst()
            hitCount += 1
            trackAccess(instance)
            WebBridgeLogger.shared.log(.info, "♻️ [WebViewPool] Acquired from pool (hit rate: \(hitRate)%, size: \(pool.count))")
            return instance
        }

        missCount += 1
        WebBridgeLogger.shared.log(.info, "🆕 [WebViewPool] Pool empty (hit rate: \(hitRate)%)")
        return nil
    }

    /// 回收 WebView 实例
    /// - Parameter instance: 要回收的实例
    public func recycle(_ instance: WebViewInstance) {
        lock.lock()
        defer { lock.unlock() }

        // 重置 WebView 状态
        resetWebView(instance.webView)

        // 检查池大小
        if pool.count < maxPoolSize {
            var mutableInstance = instance
            mutableInstance.lastUsedAt = Date()
            pool.append(mutableInstance)
            WebBridgeLogger.shared.log(.info, "♻️ [WebViewPool] Recycled to pool (size: \(pool.count))")
        } else {
            // 池已满，使用 LRU 替换最旧的实例
            if let oldestIndex = pool.indices.min(by: { pool[$0].lastUsedAt < pool[$1].lastUsedAt }) {
                pool.remove(at: oldestIndex)
                var mutableInstance = instance
                mutableInstance.lastUsedAt = Date()
                pool.append(mutableInstance)
                WebBridgeLogger.shared.log(.info, "♻️ [WebViewPool] Replaced oldest instance")
            }
        }
    }

    // MARK: - 预热

    /// 预热一个 WebView 实例（在应用启动时调用）
    /// - Parameter completion: 完成回调
    public func warmup(completion: (() -> Void)? = nil) {
        // 避免重复预热
        guard !isWarmedUp else {
            WebBridgeLogger.shared.log(.warning, "⚠️ [WebViewPool] Already warmed up")
            completion?()
            return
        }

        // 在主线程创建 WebView（UI 操作必须在主线程）
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                completion?()
                return
            }

            // 创建预热的 WebView
            let config = WebBridgePool.shared.acquireConfiguration()
            let webView = WKWebView(frame: .zero, configuration: config)

            // 注入 BarkBridge 脚本到预热的 WebView
            self.injectBridgeScript(to: webView)

            // 加载空白页触发引擎初始化
            webView.loadHTMLString("<html><body></body></html>", baseURL: nil)

            // 创建 Bridge
            let bridge = WebBridgePool.shared.acquireBridge()

            let instance = WebViewInstance(webView: webView, bridge: bridge)

            self.lock.lock()
            self.pool.append(instance)
            self.isWarmedUp = true
            self.lock.unlock()

            WebBridgeLogger.shared.log(.info, "✅ [WebViewPool] Warmed up 1 instance with bridge script")
            completion?()
        }
    }

    /// 注入 BarkBridge 脚本到 WebView
    private func injectBridgeScript(to webView: WKWebView) {
        let bridgeScript = """
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

                // 🔥 手势事件回调
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

        let script = WKUserScript(source: bridgeScript, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        webView.configuration.userContentController.addUserScript(script)
        WebBridgeLogger.shared.log(.info, "📝 [WebViewPool] Bridge script injected to pre-warmed WebView")
    }

    // MARK: - 内存管理

    /// 内存警告时清理
    @objc public func didReceiveMemoryWarning() {
        lock.lock()
        let count = pool.count
        pool.removeAll()
        isWarmedUp = false
        lock.unlock()

        WebBridgeLogger.shared.log(.warning, "🧹 [WebViewPool] Cleared \(count) instances due to memory warning")
    }

    /// 进入后台时清理
    @objc private func didEnterBackground() {
        lock.lock()
        // 后台时保留 1 个实例，其他的释放
        if pool.count > 1 {
            let removed = pool.count - 1
            pool = Array(pool.prefix(1))
            lock.unlock()
            WebBridgeLogger.shared.log(.info, "🧹 [WebViewPool] Reduced pool to 1 instance (removed \(removed))")
        } else {
            lock.unlock()
        }
    }

    /// 进入前台时检查是否需要重新预热
    @objc private func didEnterForeground() {
        lock.lock()
        let poolEmpty = pool.isEmpty
        lock.unlock()

        if poolEmpty && !isWarmedUp {
            WebBridgeLogger.shared.log(.info, "🔄 [WebViewPool] Pool empty after returning from foreground, warming up...")
            warmup()
        }
    }

    // MARK: - Observers

    private func observeMemoryWarning() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    private func observeEnterBackground() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    private func observeEnterForeground() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    // MARK: - Helper

    private func resetWebView(_ webView: WKWebView) {
        // 停止加载
        webView.stopLoading()

        // 清理导航历史
        if webView.canGoBack {
            webView.goBack()
        }

        // 重置缩放
        webView.scrollView.zoomScale = 1.0

        // 重置滚动位置
        webView.scrollView.setContentOffset(.zero, animated: false)
    }

    private func trackAccess(_ instance: WebViewInstance) {
        // 由于是 struct，这里仅作记录，实际修改在 recycle 中进行
        WebBridgeLogger.shared.log(.info, "📊 [WebViewPool] Instance accessed, age: \(Int(Date().timeIntervalSince(instance.createdAt)))s")
    }

    private var hitRate: Int {
        let total = hitCount + missCount
        return total > 0 ? (hitCount * 100) / total : 0
    }

    /// 获取池状态
    public func getPoolStatus() -> (size: Int, hitRate: Int, isWarmedUp: Bool) {
        lock.lock()
        let size = pool.count
        let warmed = isWarmedUp
        lock.unlock()
        return (size, hitRate, warmed)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
