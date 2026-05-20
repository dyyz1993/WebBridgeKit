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
    var registeredHandlerNames: [String] = []

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

            StructuredLogger.shared.debug("Using pooled WebView instance", category: .lifecycle)
        } else {
            setupUI()
            setupBridge()
            StructuredLogger.shared.debug("Created new WebView instance", category: .lifecycle)
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
        webView.evaluateJavaScript("navigator.userAgent") { [weak self] (result, _) in
            guard let self = self, let baseUA = result as? String else { return }

            let info = Bundle.main.infoDictionary
            let appVersion = info?["CFBundleShortVersionString"] as? String ?? "1.0.0"
            let buildNumber = info?["CFBundleVersion"] as? String ?? "1"

            let screenSize = UIScreen.main.bounds.size
            let screenScale = UIScreen.main.scale

            // 格式: BaseUA WebBridgeKit/Version (Build; Screen/WxH; Ratio/R)
            let customUA = "\(baseUA) WebBridgeKit/\(appVersion) (\(buildNumber); Screen/\(Int(screenSize.width))x\(Int(screenSize.height)); Ratio/\(screenScale))"

            self.webView.customUserAgent = customUA
            StructuredLogger.shared.debug("Custom UA configured: \(customUA)", category: .ui)
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
                StructuredLogger.shared.debug("viewWillAppear - Forcing landscapeLeft orientation", category: .ui)
            } else if config.orientation == .landscapeRight {
                rotateTo(.landscapeRight)
                StructuredLogger.shared.debug("viewWillAppear - Forcing landscapeRight orientation", category: .ui)
            } else if config.orientation == .landscape {
                rotateTo(.landscapeLeft)
                StructuredLogger.shared.debug("viewWillAppear - Forcing landscape (left) orientation", category: .ui)
            } else if config.orientation == .portrait {
                rotateTo(.portrait)
                StructuredLogger.shared.debug("viewWillAppear - Forcing portrait orientation", category: .ui)
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
                    StructuredLogger.shared.debug("viewDidAppear - Final forcing landscapeLeft orientation", category: .ui)
                }
            } else if config.orientation == .landscapeRight {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.rotateTo(.landscapeRight)
                    StructuredLogger.shared.debug("viewDidAppear - Final forcing landscapeRight orientation", category: .ui)
                }
            } else if config.orientation == .landscape {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.rotateTo(.landscapeLeft)
                    StructuredLogger.shared.debug("viewDidAppear - Final forcing landscape (left) orientation", category: .ui)
                }
            } else if config.orientation == .portrait {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.rotateTo(.portrait)
                    StructuredLogger.shared.debug("viewDidAppear - Final forcing portrait orientation", category: .ui)
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
            StructuredLogger.shared.error("Invalid HTML name: \(htmlName) - \(error.localizedDescription)", category: .ui)
            return
        }

        if let htmlPath = Bundle.main.path(forResource: htmlName, ofType: "html") {
            let htmlURL = URL(fileURLWithPath: htmlPath)
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
            StructuredLogger.shared.debug("Loaded HTML: \(htmlName).html", category: .ui)
        } else {
            StructuredLogger.shared.error("HTML file not found: \(htmlName).html", category: .ui)
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
            Log.error("Invalid URL scheme blocked: \(url.absoluteString) - \(error.localizedDescription)", category: .general)
            StructuredLogger.shared.error("Invalid URL scheme: \(url.absoluteString) - \(error.localizedDescription)", category: .ui)
            return
        }

        let blockedSchemes: Set<String> = ["javascript", "data", "vbscript", "file"]
        if let scheme = url.scheme?.lowercased(), blockedSchemes.contains(scheme) {
            Log.error("Blocked dangerous URL scheme: \(scheme) - \(url.absoluteString)", category: .general)
            StructuredLogger.shared.error("Blocked dangerous URL scheme: \(scheme)", category: .ui)
            return
        }

        self.url = url

        StructuredLogger.shared.debug("Attempting to match URL: \(url.absoluteString)", category: .cache)

        if let matchResult = URLRuleMatcher.shared.match(url: url) {
            StructuredLogger.shared.info("Rule matched - Rule ID: \(matchResult.ruleId), Match Type: \(matchResult.matchType), Manifest URL: \(matchResult.manifestURL.absoluteString)", category: .cache)

            downloadAndUseManifest(from: matchResult.manifestURL, pageURL: url)
        } else {
            StructuredLogger.shared.debug("No cache rule matched, using normal load", category: .cache)

            if url.isFileURL {
                webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
            } else {
                webView.load(URLRequest(url: url))
            }
            StructuredLogger.shared.debug("Loading: \(url) (System URLCache)", category: .navigation)

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

        WebPageThumbnailGenerator.shared.generateThumbnail(for: webView, url: url) { thumbnailData in
            Task {
                guard let thumbnailData else {
                    return
                }

                if let history = try? await WebPageHistoryManager.shared.findHistory(url: url) {
                    await MainActor.run {
                        do {
                            let realm = try Realm(configuration: WebPageHistoryManager.shared.realmConfiguration)
                            try realm.write {
                                if let cachedHistory = realm.object(ofType: WebPageHistory.self, forPrimaryKey: history.id) {
                                    cachedHistory.thumbnail = thumbnailData
                                }
                            }
                        } catch {
                            StructuredLogger.shared.error("Failed to save thumbnail for: \(url)", category: .storage)
                        }
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
        StructuredLogger.shared.debug("Loading from network (forced): \(url)", category: .navigation)
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
                StructuredLogger.shared.debug("Injected payload: \(payloadString)", category: .bridge)
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
                    StructuredLogger.shared.debug("Appended payload to URL: \(newURL.absoluteString)", category: .bridge)
                }
            }
        }

        // 🔥 主动触发屏幕旋转
        if params.orientation == .landscapeLeft {
            rotateTo(.landscapeLeft)
            StructuredLogger.shared.debug("Forcing landscapeLeft orientation", category: .ui)
        } else if params.orientation == .landscapeRight {
            rotateTo(.landscapeRight)
            StructuredLogger.shared.debug("Forcing landscapeRight orientation", category: .ui)
        } else if params.orientation == .landscape {
            rotateTo(.landscapeLeft)
            StructuredLogger.shared.debug("Forcing landscape (left) orientation", category: .ui)
        } else if params.orientation == .portrait {
            rotateTo(.portrait)
            StructuredLogger.shared.debug("Forcing portrait orientation", category: .ui)
        }

        StructuredLogger.shared.debug("Configured with mode: \(params.displayMode), hideTabBar: \(params.hideTabBar), disableSwipeBack: \(params.disableSwipeBack)", category: .ui)
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
            StructuredLogger.shared.warning("Unknown browser feature: \(feature)", category: .ui)
        }

        StructuredLogger.shared.debug("Browser feature '\(feature)' set to \(enabled)", category: .ui)
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
                StructuredLogger.shared.debug("Recycled instance to pool", category: .lifecycle)
            } else if let bridge = bridgeInstance {
                WebBridgePool.shared.recycleBridge(bridge)
                StructuredLogger.shared.debug("Recycled bridge only", category: .lifecycle)
            }
        }

        NotificationCenter.default.removeObserver(self)
        interceptor?.cleanup()
        registeredHandlerNames.removeAll()

        StructuredLogger.shared.debug("Cleaned up with proper memory management", category: .lifecycle)
    }
}
