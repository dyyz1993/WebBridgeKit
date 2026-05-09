//
//  WebViewController.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-14.
//

import UIKit
import WebKit
import RealmSwift

/// 统一的 Web 容器，支持横竖屏控制、全屏控制与 JSBridge
@MainActor
public class WebViewController: UIViewController, UINavigationControllerDelegate, WKScriptMessageHandler, WKNavigationDelegate {

    // MARK: - Properties

    public var webView: WKWebView!
    public var bridge: WebJavaScriptBridge!
    public var gestureInterceptor: WebGestureInterceptor?

    /// 当前加载的 URL
    public var url: URL?


    /// 标记是否从池中获取的实例（用于性能优化）
    private var isPooledInstance = false

    /// KVO observer for webView.isLoading property (for thumbnail generation)
    private var loadingObserver: NSKeyValueObservation?

    /// Track all registered script message handler names for proper cleanup
    private var registeredHandlerNames: [String] = []

    /// 是否隐藏状态栏
    public var isStatusBarHidden: Bool = false {
        didSet {
            setNeedsStatusBarAppearanceUpdate()
        }
    }

    /// 支持的方向
    public var supportedOrientations: UIInterfaceOrientationMask = .all {
        didSet {
            if #available(iOS 16.0, *) {
                setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        }
    }

    /// 浏览器配置
    public var browserConfig: WebBrowserParams?

    // 🔥 浏览器特性控制（默认全部禁用，通过 Bridge 按需开启）
    var bouncesEnabled = false
    var scrollIndicatorEnabled = false
    var backForwardGesturesEnabled = false

    // MARK: - Constants

    let customScheme = "custom"

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()

        // 尝试从池中获取实例（性能优化）
        if let instance = WebViewPool.shared.acquire() {
            // 使用池中的实例
            self.webView = instance.webView
            self.bridge = instance.bridge
            self.isPooledInstance = true

            // 添加到视图
            view.addSubview(webView)
            webView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }

            // 为当前 ViewController 添加 message handler (使用 weak wrapper 防止循环引用)
            // 注意：脚已在预热时注入，但 message handler 需要每个 VC 单独添加
            let weakHandler1 = WeakScriptMessageHandler(target: self)
            webView.configuration.userContentController.add(weakHandler1, name: "barkBridge")
            registeredHandlerNames.append("barkBridge")

            let weakHandler2 = WeakScriptMessageHandler(target: self)
            webView.configuration.userContentController.add(weakHandler2, name: "BarkBridge")
            registeredHandlerNames.append("BarkBridge")

            let weakHandler3 = WeakScriptMessageHandler(target: self)
            webView.configuration.userContentController.add(weakHandler3, name: "WebBridgeKit")
            registeredHandlerNames.append("WebBridgeKit")

            // 更新 bridge 的 webView 引用
            bridge.setWebView(webView)

            // 设置导航代理
            webView.navigationDelegate = self

            // 设置手势拦截器
            setupGestureInterceptor()

            print("♻️ [BarkWebVC] Using pooled instance with message handler")
        } else {
            // 创建新实例
            setupUI()
            setupBridge()
            print("🆕 [BarkWebVC] Created new instance")
        }

        setupNotifications()

        // 默认禁用所有浏览器特性
        applyBrowserFeatures()

        // 设置自定义 User-Agent
        setupUserAgent()

        // 添加缓存调试按钮
        setupCacheDebugButton()
    }

    /// 设置自定义 User-Agent，包含版本号、屏幕尺寸和倍率
    private func setupUserAgent() {
        // 获取原始 UA 并追加自定义信息
        _ = webView.evaluateJavaScript("navigator.userAgent") { [weak self] (result, _) in
            guard let self = self, let baseUA = result as? String else { return }

            let info = Bundle.main.infoDictionary
            let appVersion = info?["CFBundleShortVersionString"] as? String ?? "1.0.0"
            let buildNumber = info?["CFBundleVersion"] as? String ?? "1"

            let screenSize = UIScreen.main.bounds.size
            let screenScale = UIScreen.main.scale

            // 格式: BaseUA WebBridgeKit/Version (Build; Screen/WxH; Ratio/R)
            let customUA = "\(baseUA) WebBridgeKit/\(appVersion) (\(buildNumber); Screen/\(Int(screenSize.width))x\(Int(screenSize.height)); Ratio/\(screenScale))"

            self.webView.customUserAgent = customUA
            print("📱 [BarkWebVC] Custom UA configured: \(customUA)")
        }
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // 🔥 在 viewWillAppear 中再次确保侧滑手势被禁用
        if let config = browserConfig, config.disableSwipeBack {
            navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        }

        // 🔥 强制横屏：在 viewWillAppear 时再次强制旋转到目标方向
        if let config = browserConfig {
            if config.orientation == .landscapeLeft {
                rotateTo(.landscapeLeft)
                print("✅ [BarkWebVC] viewWillAppear - Forcing landscapeLeft orientation")
            } else if config.orientation == .landscapeRight {
                rotateTo(.landscapeRight)
                print("✅ [BarkWebVC] viewWillAppear - Forcing landscapeRight orientation")
            } else if config.orientation == .landscape {
                rotateTo(.landscapeLeft)  // .landscape 默认向左
                print("✅ [BarkWebVC] viewWillAppear - Forcing landscape (left) orientation")
            } else if config.orientation == .portrait {
                rotateTo(.portrait)
                print("✅ [BarkWebVC] viewWillAppear - Forcing portrait orientation")
            }
        }
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // 🔥 强制横屏：在 viewDidAppear 时最后确认一次方向（防止用户快速旋转设备）
        if let config = browserConfig {
            if config.orientation == .landscapeLeft {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.rotateTo(.landscapeLeft)
                    print("✅ [BarkWebVC] viewDidAppear - Final forcing landscapeLeft orientation")
                }
            } else if config.orientation == .landscapeRight {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.rotateTo(.landscapeRight)
                    print("✅ [BarkWebVC] viewDidAppear - Final forcing landscapeRight orientation")
                }
            } else if config.orientation == .landscape {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.rotateTo(.landscapeLeft)  // 默认向左
                    print("✅ [BarkWebVC] viewDidAppear - Final forcing landscape (left) orientation")
                }
            } else if config.orientation == .portrait {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.rotateTo(.portrait)
                    print("✅ [BarkWebVC] viewDidAppear - Final forcing portrait orientation")
                }
            }
        }
    }

    // MARK: - Public Methods

    /// 安全地加载本地 HTML 文件
    /// - Parameter htmlName: HTML 文件名（不含扩展名）
    public func loadLocalHTML(named htmlName: String) {
        // 确保 view 已加载，从而 webView 已初始化
        _ = view

        // 🔒 Input validation: Validate HTML name to prevent path traversal attacks
        do {
            _ = try InputValidator.validateHTMLName(htmlName)
        } catch {
            print("❌ [BarkWebVC] Invalid HTML name: \(htmlName)")
            print("   - Error: \(error.localizedDescription)")
            return
        }

        if let htmlPath = Bundle.main.path(forResource: htmlName, ofType: "html") {
            let htmlURL = URL(fileURLWithPath: htmlPath)
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
            print("✅ [BarkWebVC] Loaded HTML: \(htmlName).html")
        } else {
            print("❌ [BarkWebVC] HTML file not found: \(htmlName).html")
            // 尝试列出所有可用的 HTML 文件
            let bundlePath = Bundle.main.bundlePath
            let resourcesPath = bundlePath + "/Resources"
            print("📁 [BarkWebVC] Bundle path: \(resourcesPath)")
            if let files = try? FileManager.default.contentsOfDirectory(atPath: resourcesPath) {
                let htmlFiles = files.filter { $0.hasSuffix(".html") }
                print("📄 [BarkWebVC] Available HTML files: \(htmlFiles.joined(separator: ", "))")
            }
        }
    }

    /// 安全地加载 URL
    /// - Parameter url: 要加载的 URL
    public func loadURL(_ url: URL) {
        // 确保 view 已加载
        _ = view

        // 🔒 Input validation: Validate URL scheme to prevent loading dangerous URLs
        let allowedSchemes: Set<String> = ["http", "https", "file", "custom"]
        do {
            _ = try InputValidator.validateURLScheme(url, allowedSchemes: allowedSchemes)
        } catch {
            print("❌ [BarkWebVC] Invalid URL scheme: \(url.absoluteString)")
            print("   - Error: \(error.localizedDescription)")
            return
        }

        self.url = url

        print("🧪 [ManifestCache] Attempting to match URL: \(url.absoluteString)")

        // 🔥 检查 URL 是否匹配缓存规则
        if let matchResult = URLRuleMatcher.shared.match(url: url) {
            print("✅ [ManifestCache] Rule matched!")
            print("   - Rule ID: \(matchResult.ruleId)")
            print("   - Match Type: \(matchResult.matchType)")
            print("   - Manifest URL: \(matchResult.manifestURL.absoluteString)")

            // 尝试下载 manifest
            downloadAndUseManifest(from: matchResult.manifestURL, pageURL: url)
        } else {
            print("⏭️ [ManifestCache] No rule matched, using normal load")

            // 🔥 新方案：使用系统 URLCache，无需 HTML 修改或 JS 注入
            // WKWebView 会自动使用 URLCache.shared 处理缓存
            // 基于 HTTP 缓存头，自动回退到网络
            if url.isFileURL {
                webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
            } else {
                webView.load(URLRequest(url: url))
            }
            print("🌐 [BarkWebVC] Loading: \(url) (System URLCache will handle cache automatically)")

            // 🔥 页面加载完成后自动生成缩略图
            generateThumbnailAfterLoad(url: url)
        }
    }

    /// 页面加载完成后生成缩略图
    func generateThumbnailAfterLoad(url: URL) {
        // 🔒 Clean up any existing observer before creating a new one
        loadingObserver?.invalidate()
        loadingObserver = nil

        // 使用KVO监听loading属性
        let observation = webView.observe(\.isLoading, options: [.new]) { [weak self] _, change in
            guard let self = self, let isLoading = change.newValue else { return }

            // 当loading变为false时，页面加载完成
            if !isLoading {
                // 延迟2秒等待页面渲染完成
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.captureThumbnail(for: url)
                    // 🔒 Clean up observer after use
                    self?.loadingObserver?.invalidate()
                    self?.loadingObserver = nil
                }
            }
        }

        // 保存观察者以便后续清理
        loadingObserver = observation
    }

    /// 捕获缩略图并保存
    private func captureThumbnail(for url: URL) {
        // 只为外部URL生成缩略图
        guard url.scheme == "http" || url.scheme == "https" else {
            return
        }

        WebPageThumbnailGenerator.shared.generateThumbnail(for: webView, url: url) { [weak self] thumbnailData in
            Task { @MainActor in
                guard let thumbnailData else {
                    return
                }

                // 通过URL查找历史记录并更新缩略图
                if let history = WebPageHistoryManager.shared.findHistory(url: url) {
                    // 使用 WebPageOfflineCacheManager 的 Realm 实例来更新
                    // 因为它可能已经打开了 Realm
                    do {
                        let realm = try Realm(configuration: WebPageHistoryManager.shared.realmConfiguration)
                        try realm.write {
                            if let cachedHistory = realm.object(ofType: WebPageHistory.self, forPrimaryKey: history.id) {
                                cachedHistory.thumbnail = thumbnailData
                                print(" [BarkWebVC] Thumbnail saved for: \(url)")
                            }
                        }
                    } catch {
                        // 🔒 Proper error handling with logging
                        print(" [BarkWebVC] Failed to save thumbnail for: \(url)")
                        print("   - Error: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    /// 安全地加载 URL（强制使用在线版本）
    /// - Parameter url: 要加载的 URL
    public func loadURLOnline(_ url: URL) {
        // 确保 view 已加载
        _ = view
        self.url = url
        webView.load(URLRequest(url: url))
        print("🌐 [BarkWebVC] Loading from network (forced): \(url)")
    }

    /// 配置浏览器参数
    public func configure(with params: WebBrowserParams) {
        browserConfig = params
        supportedOrientations = params.orientation
        isStatusBarHidden = params.hideStatusBar

        // 🔥 处理标题
        if let title = params.customTitle {
            self.title = title
        }

        // 🔥 隐藏导航栏（如果要完全沉浸式）
        if params.hideNavigationBar || params.displayMode == .immersive {
            navigationController?.setNavigationBarHidden(true, animated: false)
        } else {
            navigationController?.setNavigationBarHidden(false, animated: false)
        }

        // 🔥 TabBar 隐藏由系统的 hidesBottomBarWhenPushed 属性自动处理
        // 当 hideTabBar = true 时，系统会在 push 时自动隐藏 TabBar
        // 在 WebBrowserManager 创建 VC 时已设置 hidesBottomBarWhenPushed

        // 🔥 禁用侧滑返回手势
        if params.disableSwipeBack {
            self.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
            // 🔥 同时设置 delegate 以防止被重新启用
            self.navigationController?.delegate = self
        } else {
            self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            self.navigationController?.delegate = nil
        }

        // 🔥 沉浸式模式：移除安全区域
        if params.displayMode == .immersive {
            webView.scrollView.contentInsetAdjustmentBehavior = .never
        } else {
            webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        }

        // 根据显示模式调整体验
        configureBrowserFeatures(params: params)

        // 🔥 注入 payload 参数
        if let payload = params.payload {
            if let payloadData = try? JSONSerialization.data(withJSONObject: payload),
               let payloadString = String(data: payloadData, encoding: .utf8) {
                let scriptSource = "window.SuperCachePayload = \(payloadString);"
                let userScript = WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: true)
                webView.configuration.userContentController.addUserScript(userScript)
                print("🚀 [WebViewController] Injected payload: \(payloadString)")
            }

            // 将 payload 转换为 URL Query 参数
            if let url = webView.url ?? self.url,
               var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                var queryItems = components.queryItems ?? []
                for (key, value) in payload where !queryItems.contains(where: { $0.name == key }) {
                    queryItems.append(URLQueryItem(name: key, value: value))
                }
                components.queryItems = queryItems
                if let newURL = components.url {
                    self.url = newURL // 更新初始加载 URL
                    print("🔗 [WebViewController] Appended payload to URL: \(newURL.absoluteString)")
                }
            }
        }

        // 🔥 主动触发屏幕旋转
        if params.orientation == .landscapeLeft {
            rotateTo(.landscapeLeft)
            print("✅ [BarkWebVC] Forcing landscapeLeft orientation")
        } else if params.orientation == .landscapeRight {
            rotateTo(.landscapeRight)
            print("✅ [BarkWebVC] Forcing landscapeRight orientation")
        } else if params.orientation == .landscape {
            rotateTo(.landscapeLeft)  // 默认向左
            print("✅ [BarkWebVC] Forcing landscape (left) orientation")
        } else if params.orientation == .portrait {
            rotateTo(.portrait)
            print("✅ [BarkWebVC] Forcing portrait orientation")
        }

        print("✅ [BarkWebVC] Configured with mode: \(params.displayMode), hideTabBar: \(params.hideTabBar), disableSwipeBack: \(params.disableSwipeBack)")
    }

    /// 🔥 通过 Bridge 开启/关闭浏览器特性
    public func setBrowserFeature(_ feature: String, enabled: Bool) {
        switch feature {
        case "bounces":
            bouncesEnabled = enabled
            webView.scrollView.bounces = enabled
            webView.scrollView.alwaysBounceVertical = enabled
            webView.scrollView.alwaysBounceHorizontal = enabled

        case "scrollIndicator":
            scrollIndicatorEnabled = enabled
            webView.scrollView.showsVerticalScrollIndicator = enabled
            webView.scrollView.showsHorizontalScrollIndicator = enabled

        case "backForwardGestures":
            backForwardGesturesEnabled = enabled
            webView.allowsBackForwardNavigationGestures = enabled

        case "scrollEnabled":
            webView.scrollView.isScrollEnabled = enabled

        default:
            print("⚠️ [BarkWebVC] Unknown feature: \(feature)")
        }

        print("🔧 [BarkWebVC] Browser feature '\(feature)' set to \(enabled)")
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground

        let config = WKWebViewConfiguration()
        // 允许内联播放视频
        config.allowsInlineMediaPlayback = true

        // 禁用智能链接检测（电话、地址、日期等自动高亮）
        config.dataDetectorTypes = []

        // 🔥 注册 wb-resource:// URLSchemeHandler
        // 用于拦截资源请求并从 manifest 缓存中提供资源
        ManifestURLSchemeHandler.register(to: config, scheme: "wb-resource")
        print("✅ [ManifestCache] Registered wb-resource:// URLSchemeHandler")

        webView = WKWebView(frame: .zero, configuration: config)

        // 设置导航代理
        webView.navigationDelegate = self

        // 设置内容 inset 适应安全区域（默认）
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic

        view.addSubview(webView)
        webView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        print("✅ [BarkWebVC] WebView initialized with Manifest cache support")
    }

    private func setupBridge() {
        // 从预热池获取 Bridge（性能优化）
        bridge = WebBridgePool.shared.acquireBridge()
        bridge.setWebView(webView)

        // 注入桥接脚本
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
                    // 触发全局 CustomEvent
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

        // 使用 weak wrapper 防止循环引用
        let weakHandler = WeakScriptMessageHandler(target: self)
        webView.configuration.userContentController.add(weakHandler, name: "barkBridge")
        registeredHandlerNames.append("barkBridge")

        // 设置手势拦截器
        setupGestureInterceptor()
    }

    private func setupGestureInterceptor() {
        // 使用 getHandler 方法支持懒加载
        guard let gestureHandler = bridge.getHandler(for: "gesture") as? WebGestureHandler else {
            print("⚠️ [BarkWebVC] WebGestureHandler not found, gesture interceptor not setup")
            return
        }

        gestureHandler.setCurrentWebView(webView)
        gestureInterceptor = WebGestureInterceptor(webView: webView, gestureHandler: gestureHandler)

        print("✅ [BarkWebVC] Gesture interceptor setup completed")
    }


    /// 🔥 默认禁用所有浏览器特性
    private func applyBrowserFeatures() {
        webView.scrollView.bounces = bouncesEnabled
        webView.scrollView.alwaysBounceVertical = bouncesEnabled
        webView.scrollView.alwaysBounceHorizontal = bouncesEnabled

        webView.scrollView.showsVerticalScrollIndicator = scrollIndicatorEnabled
        webView.scrollView.showsHorizontalScrollIndicator = scrollIndicatorEnabled

        webView.allowsBackForwardNavigationGestures = backForwardGesturesEnabled

        print("🔒 [BarkWebVC] Browser features applied (all disabled by default)")
    }

    private func configureBrowserFeatures(params: WebBrowserParams) {
        // 根据显示模式进一步优化体验
        switch params.displayMode {
        case .immersive:
            // 🔥 沉浸式模式：彻底禁用滚动，移除安全区域
            webView.scrollView.isScrollEnabled = false
            webView.scrollView.contentInsetAdjustmentBehavior = .never

        case .modal:
            // 弹窗模式：保持默认（全部禁用）
            break

        case .normal:
            // 标准模式：保持默认（全部禁用）
            break
        }

        // 根据手势配置更新拦截器
        if let interceptor = gestureInterceptor {
            // 使用默认配置
            let config = WebGestureConfig.default
            interceptor.updateConfig(config)
        }
    }

    private func setupNotifications() {
        // 监听全屏切换
        NotificationCenter.default.addObserver(forName: NSNotification.Name("BarkStatusBarVisibilityChanged"), object: nil, queue: .main) { [weak self] notification in
            Task { @MainActor [weak self] in
                if let hidden = notification.userInfo?["hidden"] as? Bool {
                    self?.isStatusBarHidden = hidden
                }
            }
        }

        // 监听方向切换
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

        // 监听下拉刷新完成通知
        NotificationCenter.default.addObserver(forName: NSNotification.Name("BarkPullRefreshCompleted"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.gestureInterceptor?.stopLoading()
            }
        }

        // 监听下拉刷新取消通知
        NotificationCenter.default.addObserver(forName: NSNotification.Name("BarkPullRefreshCancelled"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.gestureInterceptor?.stopLoading()
            }
        }
    }

    private func rotateTo(_ orientation: UIInterfaceOrientation) {
        print("🔄 [BarkWebVC] Attempting to rotate to: \(orientation.rawValue)")

        // 方法1：使用 UIDevice setValue（私有 API，但在 iOS 16 之前有效）
        UIDevice.current.setValue(orientation.rawValue, forKey: "orientation")

        // 方法2：尝试旋转到设备方向
        UIViewController.attemptRotationToDeviceOrientation()

        // 方法3：iOS 16+ 使用新的 API
        if #available(iOS 16.0, *) {
            // 获取当前的 window scene
            for scene in UIApplication.shared.connectedScenes {
                guard let windowScene = scene as? UIWindowScene else { continue }

                // 根据目标方向设置遮罩
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

                // 使用新的 Geometry 更新 API
                let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: targetMask)
                _ = windowScene.requestGeometryUpdate(geometryPreferences) { error in
                    print("⚠️ [BarkWebVC] Geometry update error: \(error.localizedDescription)")
                }
                print("✅ [BarkWebVC] Geometry update requested (iOS 16+)")
                break
            }
        }
    }

    // MARK: - Overrides

    public override var prefersStatusBarHidden: Bool {
        return isStatusBarHidden
    }

    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return supportedOrientations
    }

    public override var shouldAutorotate: Bool {
        return true
    }

    deinit {
        // 🔒 Clean up KVO observer
        loadingObserver?.invalidate()
        loadingObserver = nil

        // Store references to clean up outside of actor context
        let handlerNames = registeredHandlerNames
        let webViewInstance = webView
        let interceptor = gestureInterceptor
        let pooled = isPooledInstance
        let bridgeInstance = bridge
        let webViewForPool = pooled ? webView : nil
        let bridgeForPool = pooled ? bridge : nil

        Task { @MainActor in
            // 🔒 Remove all script message handlers to prevent memory leaks
            // WKUserContentController.add(_:name:) creates strong references
            for handlerName in handlerNames {
                webViewInstance?.configuration.userContentController.removeScriptMessageHandler(forName: handlerName)
            }

            // 🔒 Clear delegates to break strong reference cycles
            webViewInstance?.navigationDelegate = nil
            webViewInstance?.uiDelegate = nil

            // 如果是从池中获取的，回收实例到池中（性能优化）
            if pooled, let webView = webViewForPool, let bridge = bridgeForPool {
                let instance = WebViewPool.WebViewInstance(
                    webView: webView,
                    bridge: bridge
                )
                WebViewPool.shared.recycle(instance)
                print(" [BarkWebVC] Recycled instance to pool")
            } else if let bridge = bridgeInstance {
                // 不是从池中获取的，尝试回收 Bridge
                WebBridgePool.shared.recycleBridge(bridge)
                print(" [BarkWebVC] Recycled bridge only")
            }
        }

        NotificationCenter.default.removeObserver(self)
        interceptor?.cleanup()
        registeredHandlerNames.removeAll()

        print(" [BarkWebVC] Cleaned up with proper memory management")
    }
}
