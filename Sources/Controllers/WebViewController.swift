//
//  WebViewController.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-14.
//

import UIKit
import WebKit

// Framework imports

/// 统一的 Web 容器，支持横竖屏控制、全屏控制与 JSBridge
public class WebViewController: UIViewController {

    // MARK: - Properties

    public var webView: WKWebView!
    public var bridge: WebJavaScriptBridge!
    public var gestureInterceptor: WebGestureInterceptor?


    /// 标记是否从池中获取的实例（用于性能优化）
    private var isPooledInstance = false

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
    private var bouncesEnabled = false
    private var scrollIndicatorEnabled = false
    private var backForwardGesturesEnabled = false

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

            // 为当前 ViewController 添加 message handler
            // 注意：脚已在预热时注入，但 message handler 需要每个 VC 单独添加
            webView.configuration.userContentController.add(self, name: "barkBridge")

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

        // 添加缓存调试按钮
        setupCacheDebugButton()

        #if DEBUG
        // Add cache debug floating button
        addCacheDebugButton(at: CGPoint(x: view.bounds.width - 70, y: 100))
        #endif
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
            webView.load(URLRequest(url: url))
            print("🌐 [BarkWebVC] Loading: \(url) (System URLCache will handle cache automatically)")

            // 🔥 页面加载完成后自动生成缩略图
            generateThumbnailAfterLoad(url: url)
        }
    }

    /// 页面加载完成后生成缩略图
    private func generateThumbnailAfterLoad(url: URL) {
        // 使用KVO监听loading属性
        let observation = webView.observe(\.isLoading, options: [.new]) { [weak self] webView, change in
            guard let self = self, let isLoading = change.newValue else { return }

            // 当loading变为false时，页面加载完成
            if !isLoading {
                // 延迟2秒等待页面渲染完成
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.captureThumbnail(for: url)
                }
            }
        }

        // 保存观察者以便后续清理
        objc_setAssociatedObject(self, &AssociatedKeys.loadingObserver, observation, .OBJC_ASSOCIATION_RETAIN)
    }

    /// 捕获缩略图并保存
    private func captureThumbnail(for url: URL) {
        // 只为外部URL生成缩略图
        guard url.scheme == "http" || url.scheme == "https" else {
            return
        }

        WebPageThumbnailGenerator.shared.generateThumbnail(for: webView, url: url) { [weak self] thumbnailData in
            guard let self = self, let thumbnailData = thumbnailData else {
                return
            }

            // 通过URL查找历史记录并更新缩略图
            if let history = WebPageHistoryManager.shared.findHistory(url: url) {
                // 使用 WebPageOfflineCacheManager 的 Realm 实例来更新
                // 因为它可能已经打开了 Realm
                if let realm = try? Realm(configuration: Realm.Configuration(
                    fileURL: Realm.Configuration.defaultConfiguration.fileURL?.deletingLastPathComponent().appendingPathComponent("pageHistory.realm"),
                    schemaVersion: 1
                )) {
                    try? realm.write {
                        if let cachedHistory = realm.object(ofType: WebPageHistory.self, forPrimaryKey: history.id) {
                            cachedHistory.thumbnail = thumbnailData
                            print("✅ [BarkWebVC] Thumbnail saved for: \(url)")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Associated Keys for KVO cleanup

    private struct AssociatedKeys {
        static var loadingObserver: UInt8 = 0
    }

    /// 安全地加载 URL（强制使用在线版本）
    /// - Parameter url: 要加载的 URL
    public func loadURLOnline(_ url: URL) {
        // 确保 view 已加载
        _ = view
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
                for (key, value) in payload {
                    // 避免重复添加
                    if !queryItems.contains(where: { $0.name == key }) {
                        queryItems.append(URLQueryItem(name: key, value: value))
                    }
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
        webView.configuration.userContentController.add(self, name: "barkBridge")

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
            if let hidden = notification.userInfo?["hidden"] as? Bool {
                self?.isStatusBarHidden = hidden
            }
        }

        // 监听方向切换
        NotificationCenter.default.addObserver(forName: NSNotification.Name("BarkOrientationChanged"), object: nil, queue: .main) { [weak self] notification in
            guard let self = self else { return }
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

        // 监听下拉刷新完成通知
        NotificationCenter.default.addObserver(forName: NSNotification.Name("BarkPullRefreshCompleted"), object: nil, queue: .main) { [weak self] _ in
            self?.gestureInterceptor?.stopLoading()
        }

        // 监听下拉刷新取消通知
        NotificationCenter.default.addObserver(forName: NSNotification.Name("BarkPullRefreshCancelled"), object: nil, queue: .main) { [weak self] _ in
            self?.gestureInterceptor?.stopLoading()
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
                windowScene.requestGeometryUpdate(geometryPreferences) { error in
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

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // 🔥 TabBar 恢复由系统自动处理
        // 当使用 hidesBottomBarWhenPushed 时，系统会在 pop 时自动恢复 TabBar
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        gestureInterceptor?.cleanup()
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "barkBridge")

        // 如果是从池中获取的，回收实例到池中（性能优化）
        if isPooledInstance {
            let instance = WebViewPool.WebViewInstance(
                webView: webView!,
                bridge: bridge!
            )
            WebViewPool.shared.recycle(instance)
            print("♻️ [BarkWebVC] Recycled instance to pool")
        } else {
            // 不是从池中获取的，尝试回收 Bridge
            WebBridgePool.shared.recycleBridge(bridge!)
            print("♻️ [BarkWebVC] Recycled bridge only")
        }

        print("🧹 [BarkWebVC] Cleaned up")
    }

    // MARK: - Constants

    private let customScheme = "custom"

    // MARK: - Manifest Cache Integration

    /// 下载并使用 Manifest
    /// - Parameters:
    ///   - manifestURL: manifest.json 的 URL
    ///   - pageURL: 页面 URL
    private func downloadAndUseManifest(from manifestURL: URL, pageURL: URL) {
        print("📥 [ManifestCache] Downloading manifest from: \(manifestURL.absoluteString)")

        let task = URLSession.shared.dataTask(with: manifestURL) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                print("❌ [ManifestCache] Failed to download manifest: \(error.localizedDescription)")
                // 回退到普通加载
                self.fallbackToNormalLoad(pageURL)
                return
            }

            guard let data = data else {
                print("❌ [ManifestCache] Manifest data is empty")
                self.fallbackToNormalLoad(pageURL)
                return
            }

            do {
                // 解析 manifest
                let manifest = try JSONDecoder().decode(PersistentManifestLoader.WebManifest.self, from: data)

                print("✅ [ManifestCache] Manifest downloaded successfully")
                print("   - Persistent: \(manifest.persistent)")
                print("   - Resources: \(manifest.resources.count)")
                print("   - Version: \(manifest.version ?? "N/A")")

                // 根据 persistent 字段选择加载策略
                DispatchQueue.main.async {
                    if manifest.persistent {
                        print("🔥 [ManifestCache] Using PERSISTENT mode (download all resources first)")
                        self.usePersistentMode(pageURL: pageURL, manifest: manifest)
                    } else {
                        print("⚡ [ManifestCache] Using LAZY mode (load HTML immediately, background download)")
                        self.useLazyMode(pageURL: pageURL, manifest: manifest)
                    }
                }

            } catch {
                print("❌ [ManifestCache] Failed to decode manifest: \(error.localizedDescription)")
                // 回退到普通加载
                self.fallbackToNormalLoad(pageURL)
            }
        }

        task.resume()
    }

    /// 使用持久化模式（下载所有资源后再加载）
    private func usePersistentMode(pageURL: URL, manifest: PersistentManifestLoader.WebManifest) {
        // 找到合适的 view controller 来显示进度弹窗
        let presentingViewController: UIViewController
        if let navController = self.navigationController,
           let topVC = navController.topViewController {
            presentingViewController = topVC
        } else if let parentVC = self.parent {
            presentingViewController = parentVC
        } else {
            presentingViewController = self
        }

        print("💾 [ManifestCache] Starting persistent mode download")

        PersistentManifestLoader.load(
            url: pageURL,
            in: webView,
            from: presentingViewController
        ) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success:
                print("✅ [ManifestCache] Persistent mode load completed successfully")
            case .failure(let error):
                print("❌ [ManifestCache] Persistent mode failed: \(error.localizedDescription)")
                // 回退到普通加载
                self.fallbackToNormalLoad(pageURL)
            }
        }
    }

    /// 使用懒加载模式（立即加载 HTML，后台下载资源）
    private func useLazyMode(pageURL: URL, manifest: PersistentManifestLoader.WebManifest) {
        print("⚡ [ManifestCache] Starting lazy mode load")

        // 将 WebManifest 转换为 LazyManifestLoader.WebManifest
        let lazyManifest = LazyManifestLoader.WebManifest(
            persistent: manifest.persistent,
            resources: manifest.resources,
            version: manifest.version,
            appid: manifest.appid,
            name: manifest.name,
            icon: manifest.icon
        )

        LazyManifestLoader.load(
            url: pageURL,
            in: webView
        ) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success:
                print("✅ [ManifestCache] Lazy mode load completed successfully")
            case .failure(let error):
                print("❌ [ManifestCache] Lazy mode failed: \(error.localizedDescription)")
                // 回退到普通加载
                self.fallbackToNormalLoad(pageURL)
            }
        }
    }

    /// 回退到普通加载模式
    private func fallbackToNormalLoad(_ url: URL) {
        print("⏭️ [ManifestCache] Falling back to normal load")

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.webView.load(URLRequest(url: url))
            print("🌐 [BarkWebVC] Loading: \(url) (fallback mode)")

            // 页面加载完成后自动生成缩略图
            self.generateThumbnailAfterLoad(url: url)
        }
    }

    // MARK: - Manifest Cache Helper Methods

    /// Load a local HTML file with manifest-based resource mapping
    /// - Parameters:
    ///   - htmlName: HTML file name (without extension)
    ///   - manifestName: Manifest JSON file name (without extension)
    public func loadLocalHTML(withManifest htmlName: String, manifestName: String = "manifest") {
        // Ensure view is loaded
        _ = view

        guard let htmlPath = Bundle.main.path(forResource: htmlName, ofType: "html") else {
            print("❌ [BarkWebVC] HTML file not found: \(htmlName).html")
            return
        }

        guard let manifestPath = Bundle.main.path(forResource: manifestName, ofType: "json") else {
            print("❌ [BarkWebVC] Manifest file not found: \(manifestName).json")
            return
        }

        do {
            let manifestData = try Data(contentsOf: URL(fileURLWithPath: manifestPath))
            let manifest = try JSONDecoder().decode([String: String].self, from: manifestData)

            // Register manifest with ManifestURLSchemeHandler
            if let handler = webView.configuration.urlSchemeHandler(forURLScheme: customScheme) as? ManifestURLSchemeHandler {
                handler.registerManifest(forPage: htmlName, manifest: manifest)
                print("✅ [BarkWebVC] Registered manifest for: \(htmlName)")
            } else {
                print("⚠️ [BarkWebVC] ManifestURLSchemeHandler not found")
            }

            // Load HTML with custom scheme
            let htmlURL = URL(string: "\(customScheme)://\(htmlName).html")!
            webView.load(URLRequest(url: htmlURL))
            print("✅ [BarkWebVC] Loaded HTML with manifest: \(htmlName).html")

        } catch {
            print("❌ [BarkWebVC] Failed to load manifest: \(error)")
        }
    }

    /// Load an HTML file from a custom URL with resource mapping
    /// - Parameter customURL: The custom:// URL to load
    public func loadCustomURL(_ customURL: URL) {
        // Ensure view is loaded
        _ = view

        guard customURL.scheme == customScheme else {
            print("❌ [BarkWebVC] Invalid custom scheme: \(customURL.scheme ?? "nil")")
            return
        }

        webView.load(URLRequest(url: customURL))
        print("✅ [BarkWebVC] Loading custom URL: \(customURL)")
    }

    /// Register a resource manifest for a specific page
    /// - Parameters:
    ///   - pageName: The page name (e.g., "test_page")
    ///   - manifest: Dictionary mapping relative paths to network URLs
    public func registerResourceManifest(forPage pageName: String, manifest: [String: String]) {
        if let handler = webView.configuration.urlSchemeHandler(forURLScheme: customScheme) as? ManifestURLSchemeHandler {
            handler.registerManifest(forPage: pageName, manifest: manifest)
            print("✅ [BarkWebVC] Registered manifest for page: \(pageName)")
        } else {
            print("❌ [BarkWebVC] ManifestURLSchemeHandler not available")
        }
    }

    /// Clear cached resources for a specific page
    /// - Parameter pageName: The page name to clear cache for
    public func clearResourceCache(forPage pageName: String) {
        if let handler = webView.configuration.urlSchemeHandler(forURLScheme: customScheme) as? ManifestURLSchemeHandler {
            handler.unregisterManifest(forPage: pageName)
            print("✅ [BarkWebVC] Cleared cache for page: \(pageName)")
        }
    }

    // MARK: - Cache Debug Methods

    /// 设置缓存调试按钮
    private func setupCacheDebugButton() {
        let debugButton = UIBarButtonItem(
            title: "🔍 Cache",
            style: .plain,
            target: self,
            action: #selector(showCacheDebugInfo)
        )
        navigationItem.rightBarButtonItem = debugButton
        print("✅ [BarkWebVC] Cache debug button added")
    }

    /// 显示缓存调试信息
    @objc private func showCacheDebugInfo() {
        // 获取当前页面 URL
        let currentURL = webView.url?.absoluteString ?? "No URL loaded"

        // 收集缓存信息
        var debugInfo = """
        🔍 WebBridgeKit Cache Debug Info
        =================================

        📍 Current Page URL:
        \(currentURL)

        🌐 System URLCache Info:
        """

        // 获取系统 URLCache 信息
        let urlCache = URLCache.shared
        let currentMemoryUsage = urlCache.currentMemoryUsage
        let currentDiskUsage = urlCache.currentDiskUsage
        debugInfo += """
        - Memory Usage: \(ByteCountFormatter.string(fromByteCount: Int64(currentMemoryUsage), countStyle: .memory))
        - Disk Usage: \(ByteCountFormatter.string(fromByteCount: Int64(currentDiskUsage), countStyle: .file))
        - Memory Capacity: \(ByteCountFormatter.string(fromByteCount: Int64(urlCache.memoryCapacity), countStyle: .memory))
        - Disk Capacity: \(ByteCountFormatter.string(fromByteCount: Int64(urlCache.diskCapacity), countStyle: .file))

        📦 Compressed Cache Info:
        """

        // 获取压缩缓存信息
        let compressedCacheInfo = WebCompressedCacheStore.shared.getMemoryInfo()
        debugInfo += """
        - Total Entries: \(compressedCacheInfo.totalEntries)
        - Original Size: \(compressedCacheInfo.formattedTotalOriginalSize)
        - Compressed Size: \(compressedCacheInfo.formattedTotalCompressedSize)
        - Compression Ratio: \(compressedCacheInfo.formattedCompressionRatio)
        - Saved Space: \(compressedCacheInfo.formattedSavedSpace)

        📋 Cached Resources Summary:
        """

        // 获取缓存条目统计
        let entries = WebCompressedCacheStore.shared.getAllEntries()
        let domainGroups = Dictionary(grouping: entries) { $0.domain }
        debugInfo += "\n- Total Cached Resources: \(entries.count)"
        debugInfo += "\n- Cached Domains: \(domainGroups.count)"

        // 显示前 5 个域名
        let topDomains = domainGroups.sorted { $0.value.count > $1.value.count }.prefix(5)
        for (domain, resources) in topDomains {
            debugInfo += "\n  • \(domain): \(resources.count) resources"
        }

        debugInfo += """

        📄 Page Cache Info:
        """

        // 获取页面缓存信息
        let cachedPages = WebPageOfflineCacheManager.shared.getCachedPages()
        debugInfo += "\n- Cached Pages: \(cachedPages.count)"

        // 显示前 3 个已缓存页面
        let topPages = cachedPages.prefix(3)
        for page in topPages {
            debugInfo += "\n  • \(page.title): \(ByteCountFormatter.string(fromByteCount: page.totalSize, countStyle: .file))"
        }

        debugInfo += """

        📂 Cache Directory Path:
        """

        // 获取缓存目录路径
        let cachePath = WebCompressedCacheStore.shared.getCacheDirectory()
        debugInfo += "\n\(cachePath.path)"

        // 打印到控制台
        print(debugInfo)

        // 显示 Alert
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(
                title: "🔍 Cache Debug Info",
                message: debugInfo,
                preferredStyle: .actionSheet
            )

            alert.addAction(UIAlertAction(
                title: "Copy to Clipboard",
                style: .default
            ) { _ in
                UIPasteboard.general.string = debugInfo
                self?.showToast(message: "Debug info copied to clipboard")
            })

            alert.addAction(UIAlertAction(
                title: "Clear All Cache",
                style: .destructive
            ) { _ in
                self?.clearAllCache()
            })

            alert.addAction(UIAlertAction(
                title: "Close",
                style: .cancel
            ))

            // 对于 iPad 支持
            if let popoverController = alert.popoverPresentationController {
                if let barButton = self?.navigationItem.rightBarButtonItem {
                    popoverController.barButtonItem = barButton
                }
            }

            self?.present(alert, animated: true)
        }
    }

    /// 清除所有缓存
    private func clearAllCache() {
        // 清除压缩缓存
        WebCompressedCacheStore.shared.clearAll()

        // 清除系统 URLCache
        URLCache.shared.removeAllCachedResponses()

        // 清除 WKWebsiteDataStore
        let dataStore = WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        let from = Date.distantPast
        dataStore.removeData(ofTypes: dataTypes, modifiedSince: from) {
            DispatchQueue.main.async { [weak self] in
                self?.showToast(message: "All cache cleared successfully")
                print("✅ [BarkWebVC] All cache cleared")
            }
        }
    }

    /// 显示 Toast 提示
    private func showToast(message: String) {
        let alert = UIAlertController(
            title: nil,
            message: message,
            preferredStyle: .alert
        )
        present(alert, animated: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            alert.dismiss(animated: true)
        }
    }
}

// MARK: - UINavigationControllerDelegate

extension WebViewController: UINavigationControllerDelegate {
    public func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        // 🔥 确保侧滑手势始终被禁用（如果配置要求）
        if let config = browserConfig, config.disableSwipeBack {
            navigationController.interactivePopGestureRecognizer?.isEnabled = false
        }
    }
}

extension WebViewController: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let action = body["action"] as? String else {
            return
        }

        print("🎮 [BarkWebVC] Received action: \(action)")

        // 设置当前 callbackId
        let callbackId = body["callbackId"] as? String
        bridge.currentCallbackId = callbackId

        // 特殊处理浏览器特性设置
        if action == "browser" {
            handleBrowserAction(body: body)
            return
        }

        // 使用 getHandler 方法支持懒加载
        guard let handler = bridge.getHandler(for: action) else {
            print("❌ [BarkWebVC] No handler for: \(action)")
            bridge.sendErrorToJS("Unsupported action: \(action)")
            return
        }

        handler.handle(body: body) { [weak self] result in
            self?.bridge.sendResultToJS(result)
        }
    }

    /// 🔥 处理浏览器特性相关的 Bridge 调用
    private func handleBrowserAction(body: [String: Any]) {
        guard let params = body["params"] as? [String: Any],
              let action = params["action"] as? String else {
            bridge.sendErrorToJS("Missing action parameter")
            return
        }

        switch action {
        case "setFeature":
            if let feature = params["feature"] as? String,
               let enabled = params["enabled"] as? Bool {
                setBrowserFeature(feature, enabled: enabled)
                bridge.sendResultToJS([
                    "success": true,
                    "feature": feature,
                    "enabled": enabled
                ])
            } else {
                bridge.sendErrorToJS("Missing feature or enabled parameter")
            }

        case "getFeatures":
            bridge.sendResultToJS([
                "success": true,
                "features": [
                    "bounces": bouncesEnabled,
                    "scrollIndicator": scrollIndicatorEnabled,
                    "backForwardGestures": backForwardGesturesEnabled
                ]
            ])

        default:
            bridge.sendErrorToJS("Unknown browser action: \(action)")
        }
    }
}

// MARK: - WKNavigationDelegate

extension WebViewController: WKNavigationDelegate {

    /// 页面开始加载 - 更新缓存状态为下载中
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        #if DEBUG
        if let url = webView.url {
            updateCacheDebugStatus(
                url: url.absoluteString,
                status: .downloading,
                resourceCount: 0,
                cacheSize: 0
            )
        }
        #endif
    }

    /// 页面内容开始提交 - 检查缓存状态
    public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        #if DEBUG
        guard let url = webView.url else { return }

        // 检查是否在缓存中
        let entries = WebCompressedCacheStore.shared.getAllEntries()
        let isCached = entries.contains { $0.url == url.absoluteString }
        let cacheStatus: WebCacheDebugFloatingButton.CacheStatus = isCached ? .hit : .noCache

        // 获取缓存统计
        let cacheInfo = WebCompressedCacheStore.shared.getMemoryInfo()

        // 计算当前域名的缓存资源数量
        let domainResources = entries.filter { $0.domain == url.host ?? "" }
        let resourceCount = domainResources.count

        updateCacheDebugStatus(
            url: url.absoluteString,
            status: cacheStatus,
            resourceCount: resourceCount,
            cacheSize: Int64(cacheInfo.totalCompressedSize)
        )

        print("🔍 [CacheDebug] Navigation committed - URL: \(url.absoluteString)")
        print("   - Cache Status: \(cacheStatus.description)")
        print("   - Cached Resources: \(resourceCount)")
        #endif
    }

    /// 页面加载完成
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        #if DEBUG
        if let url = webView.url {
            print("✅ [CacheDebug] Page loaded: \(url.absoluteString)")
        }
        #endif
    }

    /// 页面加载失败
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        #if DEBUG
        if let url = webView.url {
            updateCacheDebugStatus(
                url: url.absoluteString,
                status: .error,
                resourceCount: 0,
                cacheSize: 0
            )
            print("❌ [CacheDebug] Navigation failed: \(url.absoluteString)")
            print("   - Error: \(error.localizedDescription)")
        }
        #endif
    }

    /// 页面内容加载失败
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        #if DEBUG
        if let url = webView.url {
            updateCacheDebugStatus(
                url: url.absoluteString,
                status: .error,
                resourceCount: 0,
                cacheSize: 0
            )
            print("❌ [CacheDebug] Provisional navigation failed: \(url.absoluteString)")
            print("   - Error: \(error.localizedDescription)")
        }
        #endif
    }
}
