//
//  WebViewController+Delegates.swift
//  WebBridgeKit
//
//  Extracted from WebViewController.swift
//

import SnapKit
import UIKit
import WebKit

@MainActor
extension WebViewController {

    func setupUI() {
        view.backgroundColor = ThemeTokens.Color.background

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.dataDetectorTypes = []

        ManifestURLSchemeHandler.register(to: config, scheme: "wb-resource")
        print("✅ [ManifestCache] Registered wb-resource:// URLSchemeHandler")

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic

        view.addSubview(webView)
        webView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        print("✅ [BarkWebVC] WebView initialized with Manifest cache support")
    }

    func setupBridge() {
        bridge = WebBridgePool.shared.acquireBridge()
        bridge.setWebView(webView)

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
                if (event === 'onAudioLevelChange' || event === 'onAudioLevel') {
                    if (window.onAudioLevel) window.onAudioLevel(data.level !== undefined ? data.level : data);
                    if (window.onAudioLevelChange) window.onAudioLevelChange(data.level !== undefined ? data.level : data);
                }

                if (event === 'onGesture') {
                    if (window.onGesture) window.onGesture(data);
                    const customEvent = new CustomEvent('bark_gesture', { detail: data });
                    window.dispatchEvent(customEvent);
                }

                const customEvent = new CustomEvent('bark_' + event, { detail: data });
                window.dispatchEvent(customEvent);
            }
        };
        console.log('✅ [Bark] BarkBridge initialized');
        """

        let script = WKUserScript(source: bridgeScript, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        webView.configuration.userContentController.addUserScript(script)

        let weakHandler = WeakScriptMessageHandler(target: self)
        webView.configuration.userContentController.add(weakHandler, name: "barkBridge")
        registeredHandlerNames.append("barkBridge")

        setupGestureInterceptor()
    }

    func setupGestureInterceptor() {
        guard let gestureHandler = bridge.getHandler(for: "gesture") as? WebGestureHandler else {
            print("⚠️ [BarkWebVC] WebGestureHandler not found, gesture interceptor not setup")
            return
        }

        gestureHandler.setCurrentWebView(webView)
        gestureInterceptor = WebGestureInterceptor(webView: webView, gestureHandler: gestureHandler)

        print("✅ [BarkWebVC] Gesture interceptor setup completed")
    }

    func applyBrowserFeatures() {
        webView.scrollView.bounces = bouncesEnabled
        webView.scrollView.alwaysBounceVertical = bouncesEnabled
        webView.scrollView.alwaysBounceHorizontal = bouncesEnabled

        webView.scrollView.showsVerticalScrollIndicator = scrollIndicatorEnabled
        webView.scrollView.showsHorizontalScrollIndicator = scrollIndicatorEnabled

        webView.allowsBackForwardNavigationGestures = backForwardGesturesEnabled

        print("🔒 [BarkWebVC] Browser features applied (all disabled by default)")
    }

    func configureBrowserFeatures(params: WebBrowserParams) {
        switch params.displayMode {
        case .immersive:
            webView.scrollView.isScrollEnabled = false
            webView.scrollView.contentInsetAdjustmentBehavior = .never

        case .modal:
            break

        case .normal:
            break
        }

        if let interceptor = gestureInterceptor {
            let config = WebGestureConfig.default
            interceptor.updateConfig(config)
        }
    }

    func setupNotifications() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name("BarkStatusBarVisibilityChanged"), object: nil, queue: .main) { [weak self] notification in
            Task { @MainActor [weak self] in
                if let hidden = notification.userInfo?["hidden"] as? Bool {
                    self?.isStatusBarHidden = hidden
                }
            }
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name("BarkOrientationChanged"), object: nil, queue: .main) { [weak self] notification in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let orientation = notification.userInfo?["orientation"] as? String {
                    switch orientation {
                    case "landscape":
                        self.supportedOrientations = .landscape
                        self.rotateTo(.landscapeLeft)
                    case "portrait":
                        self.supportedOrientations = .portrait
                        self.rotateTo(.portrait)
                    default:
                        self.supportedOrientations = .all
                    }
                }
            }
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name("BarkPullRefreshCompleted"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.gestureInterceptor?.stopLoading()
            }
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name("BarkPullRefreshCancelled"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.gestureInterceptor?.stopLoading()
            }
        }
    }

    func rotateTo(_ orientation: UIInterfaceOrientation) {
        print("🔄 [BarkWebVC] Attempting to rotate to: \(orientation.rawValue)")

        UIDevice.current.setValue(orientation.rawValue, forKey: "orientation")
        UIViewController.attemptRotationToDeviceOrientation()

        if #available(iOS 16.0, *) {
            for scene in UIApplication.shared.connectedScenes {
                guard let windowScene = scene as? UIWindowScene else { continue }

                var targetMask: UIInterfaceOrientationMask
                switch orientation {
                case .portrait:
                    targetMask = .portrait
                case .landscapeLeft:
                    targetMask = .landscapeLeft
                case .landscapeRight:
                    targetMask = .landscapeRight
                case .portraitUpsideDown:
                    targetMask = .portraitUpsideDown
                default:
                    targetMask = .all
                }

                let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: targetMask)
                _ = windowScene.requestGeometryUpdate(geometryPreferences) { error in
                    print("⚠️ [BarkWebVC] Geometry update error: \(error.localizedDescription)")
                }
                print("✅ [BarkWebVC] Geometry update requested (iOS 16+)")
                break
            }
        }
    }
}
