//
//  WebBrowserViewController.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-13.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import RxCocoa
import RxSwift
import SnapKit
import UIKit
import WebKit

// Framework imports

/// 浏览器主页面 - 全屏沉浸式
public class WebBrowserViewController: BaseViewController<WebBrowserViewModel> {

    // MARK: - UI Components

    private lazy var webView: WKWebView = {
        return viewModel.getWebView()
    }()

    private let progressView: UIProgressView = {
        let progressView = UIProgressView(progressViewStyle: .default)
        progressView.tintColor = WKColor.grey.base
        progressView.trackTintColor = WKColor.grey.lighten2
        return progressView
    }()

    /// 缓存状态标签
    private let cacheStatusLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = WKColor.grey.base.withAlphaComponent(0.6)
        label.layer.cornerRadius = 4
        label.clipsToBounds = true
        label.text = "LIVE"
        label.isHidden = false // 🔥 Make it visible by default for better visibility
        return label
    }()

    /// 标题容器
    private let titleContainerView: UIView = {
        let view = UIView()
        return view
    }()

    /// 标题标签
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = WKColor.grey.base
        label.textAlignment = .center
        label.numberOfLines = 1
        label.accessibilityIdentifier = "browserManager.titleLabel"
        return label
    }()

    /// 关闭/后退按钮
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let image = UIImage(systemName: "xmark", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = WKColor.grey.base
        button.accessibilityIdentifier = "browserManager.closeButton"
        return button
    }()

    /// 后退按钮（当有历史时显示）
    private let backButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let image = UIImage(systemName: "chevron.left", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = WKColor.grey.base
        button.accessibilityIdentifier = "browserManager.backButton"
        return button
    }()

    /// 更多菜单按钮
    private let menuButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        let image = UIImage(systemName: "ellipsis.circle", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = WKColor.grey.base
        button.accessibilityIdentifier = "browserManager.menuButton"
        return button
    }()

    /// 手势 - 点击底部区域关闭（当导航栏隐藏时）
    private var tapGesture: UITapGestureRecognizer?

    // MARK: - Bar Buttons

    private var backBarButton: UIBarButtonItem?
    private var closeBarButton: UIBarButtonItem?
    private var menuBarButton: UIBarButtonItem?

    // MARK: - Properties

    /// 是否隐藏导航栏
    private var hideNavBar = false

    /// 是否隐藏状态栏
    private var isStatusBarHidden: Bool = false {
        didSet {
            setNeedsStatusBarAppearanceUpdate()
        }
    }

    /// 当前 URL
    private var currentURL: URL?

    /// 当前缓存来源标识
    private var currentCacheSource: String = "LIVE"

    /// Track all registered script message handler names for proper cleanup
    private var registeredHandlerNames: [String] = []

    // MARK: - Initialization

    override init(viewModel: WebBrowserViewModel) {
        super.init(viewModel: viewModel)
        // 全屏显示，隐藏 TabBar
        hidesBottomBarWhenPushed = true
        WebBridgeLogger.shared.info("🔧 WebBrowserViewController init")
    }

    /// 便捷初始化 - 支持加载 URL
    convenience init(url: URL) {
        self.init(viewModel: WebBrowserViewModel(url: url))
        // 立即设置 navigationDelegate，确保不会错过任何导航事件
        webView.navigationDelegate = self
        print("🔧 WebBrowserViewController init - URL: \(url.absoluteString)")
        print("🔧 navigationDelegate set")
        WebBridgeLogger.shared.info("🔧 WebBrowserViewController convenience init - navigationDelegate set")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup UI

    public override func makeUI() {
        print("🔧 [WebBrowserVC] makeUI called")
        view.backgroundColor = WKColor.background.primary

        // 🔥 Configure system navigation bar instead of custom one
        configureNavigationBar()

        // 添加进度条
        view.addSubview(progressView)

        // 添加 WebView
        view.addSubview(webView)

        setupConstraints()
        setupActions()
        setupGestures()

        // 初始显示关闭按钮，隐藏后退按钮
        backButton.isHidden = true
        closeButton.isHidden = false

        // 设置通知监听 - 支持通过 JavaScript Bridge 动态切换状态栏
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("BarkStatusBarVisibilityChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let hidden = notification.userInfo?["hidden"] as? Bool {
                self?.setStatusBarHidden(hidden)
            }
        }

        // 设置通知监听 - 缓存命中通知 (InterceptiveCacheManager 已删除)
        // NotificationCenter.default.addObserver(
        //     forName: InterceptiveCacheManager.cacheHitNotification,
        //     object: nil,
        //     queue: .main
        // ) { [weak self] notification in
        //     self?.updateCacheStatus(source: "INTERCEPT")
        // }

        NotificationCenter.default.addObserver(
            forName: ManifestCacheManager.cacheHitNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let source = notification.userInfo?["source"] as? String ?? "MANIFEST"
            self?.updateCacheStatus(source: source)
        }

        // 加载初始内容
        if let initialURL = viewModel.initialURL {
            loadURLWithCache(initialURL, forceRefresh: false)  // 🔥 Will check params in viewWillAppear
        } else {
            loadWelcomePage()
        }
    }

    /// 配置系统的导航栏
    private func configureNavigationBar() {
        // 🔥 禁用大标题，确保浏览器界面整洁
        navigationItem.largeTitleDisplayMode = .never
        
        // 设置标题视图容器
        // 🔥 给容器一个初始 frame 或 size，否则在某些 iOS 版本下不显示
        titleContainerView.frame = CGRect(x: 0, y: 0, width: 200, height: 44)
        titleContainerView.addSubview(titleLabel)
        titleContainerView.addSubview(cacheStatusLabel)

        titleLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.centerX.equalToSuperview().offset(-20) // 给右侧的 label 留一点空间
            make.left.greaterThanOrEqualToSuperview()
        }

        cacheStatusLabel.snp.makeConstraints { make in
            make.left.equalTo(titleLabel.snp.right).offset(6)
            make.centerY.equalTo(titleLabel)
            make.width.equalTo(60) // 增加宽度以适应较长的文本
            make.height.equalTo(18)
        }

        navigationItem.titleView = titleContainerView

        // 🔥 使用更现代的图标和布局
        let closeBtn = UIBarButtonItem(
            image: UIImage(systemName: "xmark"), // 使用标准 xmark
            style: .plain,
            target: self,
            action: #selector(closeButtonTapped)
        )
        closeBtn.tintColor = .label
        closeBtn.accessibilityIdentifier = "browserManager.closeButton"
        self.closeBarButton = closeBtn

        // 更多按钮使用标准的三点图标
        let menuBtn = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis"), 
            style: .plain,
            target: self,
            action: #selector(menuButtonTapped)
        )
        menuBtn.tintColor = .label
        menuBtn.accessibilityIdentifier = "browserManager.menuButton"
        self.menuBarButton = menuBtn

        // 后退按钮
        let backBtn = UIBarButtonItem(
            image: UIImage(systemName: "chevron.backward"),
            style: .plain,
            target: self,
            action: #selector(backButtonTapped)
        )
        backBtn.tintColor = .label
        backBtn.accessibilityIdentifier = "browserManager.backButton"
        self.backBarButton = backBtn

        // 设置左侧按钮组：初始只显示关闭
        navigationItem.leftBarButtonItems = [closeBtn]
        navigationItem.rightBarButtonItem = menuBtn

        // 初始状态下隐藏后退按钮
        backBtn.isEnabled = false
        backBtn.tintColor = .clear
    }

    @objc private func closeButtonTapped() {
        dismissOrPop()
    }

    @objc private func backButtonTapped() {
        webView.goBack()
    }

    @objc private func menuButtonTapped() {
        showMenu()
    }

    private func setupConstraints() {
        // 🔥 WebView starts from system navigation bar bottom
        // Use guideLayout for system navigation bar
        let safeAreaLayoutGuide = view.safeAreaLayoutGuide

        webView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide.snp.top)
            make.left.right.bottom.equalToSuperview()
        }

        // Note: Buttons (closeButton, backButton, menuButton) and titleLabel are now
        // managed by UIBarButtonItem in the system navigation bar, so they don't need
        // manual SnapKit constraints.

        progressView.snp.makeConstraints { make in
            // 🔥 Progress bar starts from system navigation bar bottom
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.left.right.equalToSuperview()
            make.height.equalTo(2)
        }
    }

    private func setupActions() {
        // 🔥 Buttons now use target-action pattern in configureNavigationBar()
        // No need for RxSwift binding
    }

    private func setupGestures() {
        // 添加点击手势 - 当导航栏隐藏时，点击底部区域可以关闭
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.delegate = self
        view.addGestureRecognizer(tap)
        tapGesture = tap
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        // 只在导航栏隐藏时响应
        guard hideNavBar else { return }

        let location = gesture.location(in: view)
        // 点击底部 100 像素区域时关闭
        if location.y > view.bounds.height - 100 {
            dismissOrPop()
        }
    }

    // MARK: - Lifecycle

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // 🔥 Auto-hide TabBar whenever entering webview (regardless of URL parameters)
        // This ensures cleaner browsing experience
        if let tabBarController = self.tabBarController {
            tabBarController.tabBar.isHidden = true
            tabBarController.view.setNeedsLayout()
            tabBarController.view.layoutIfNeeded()
            print("✅ [Browser] TabBar auto-hidden on webview entry")
        }
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // 🔥 Always restore TabBar when leaving webview
        // This ensures TabBar is visible when returning to main app screens
        restoreUIState()
    }

    /// 还原系统 NavigationBar
    private func restoreUIState() {
        print("🔄 [Browser] Restoring UI state...")
        
        // 恢复屏幕方向
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        UIViewController.attemptRotationToDeviceOrientation()

        // 还原 TabBar
        if let tabBarController = self.tabBarController {
            tabBarController.tabBar.isHidden = false
            tabBarController.view.setNeedsLayout()
            tabBarController.view.layoutIfNeeded()
            print("✅ [Browser] TabBar restored")
        }

        // 还原系统 NavigationBar
        if let navigationController = self.navigationController {
            navigationController.navigationBar.isHidden = false
            navigationController.setNavigationBarHidden(false, animated: false)
            print("✅ [Browser] NavigationBar restored")
        }

        // 还原背景色
        view.backgroundColor = WKColor.background.primary

        // 重置状态标志
        hideNavBar = false

        print("✅ [Browser] UI state fully restored")
    }

    // MARK: - URL Loading

    /// 加载 URL 并检查参数
    private func loadURL(_ url: URL, checkParams: Bool = true) {
        currentURL = url

        if checkParams {
            // 检查 URL 参数
            checkURLParameters(url)
        }

        if url.isFileURL {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            let request = URLRequest(url: url)
            webView.load(request)
        }

        print("🌐 [Browser] 加载 URL: \(url.absoluteString)")
    }

    /// 检查 URL 参数
    private func checkURLParameters(_ url: URL) {
        print("🔍 [WebBrowserVC] checkURLParameters called: \(url.absoluteString)")

        // 重置缓存状态为 LIVE
        updateCacheStatus(source: "LIVE")

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            print("⚠️ [WebBrowserVC] No query items found - resetting UI state")
            // 🔥 如果没有查询参数，重置UI状态
            resetUIState()
            return
        }

        print("✅ [WebBrowserVC] Found \(queryItems.count) query items")

        // 🔥 先重置UI状态，然后根据参数设置
        var shouldHideNavBar = false
        var shouldHideStatusBar = false
        var targetOrientation: UIInterfaceOrientation? = nil

        for item in queryItems {
            print("🔍 [WebBrowserVC] Processing query item: \(item.name) = \(item.value ?? "nil")")

            switch item.name.lowercased() {
            case "hidenavbar":
                if let value = item.value, value == "1" || value.lowercased() == "true" {
                    print("✅ [WebBrowserVC] Hiding navigation bar (hidenavbar)")
                    shouldHideNavBar = true
                }
            case "hidestatusbar":
                if let value = item.value, value == "1" || value.lowercased() == "true" {
                    print("✅ [WebBrowserVC] Hiding status bar (hidestatusbar)")
                    shouldHideStatusBar = true
                }
            case "hidetabbar":
                // 🔥 TabBar is now auto-hidden, no need to handle this parameter
                print("⚠️ [WebBrowserVC] hidetabbar parameter ignored (TabBar auto-hidden)")
            case "mode":
                // 🔥 支持沉浸式模式
                if let value = item.value, value.lowercased() == "immersive" {
                    print("✅ [WebBrowserVC] Activating immersive mode (mode=immersive)")
                    shouldHideNavBar = true
                    shouldHideStatusBar = true
                    // Note: TabBar is already auto-hidden, no need to call setTabBarHidden
                }
            case "orientation":
                // 🔥 支持强制横屏
                if let value = item.value, value.lowercased() == "landscape" {
                    print("✅ [WebBrowserVC] Forcing landscape orientation")
                    targetOrientation = .landscapeRight
                } else if let value = item.value, value.lowercased() == "portrait" {
                    print("✅ [WebBrowserVC] Forcing portrait orientation")
                    targetOrientation = .portrait
                }
            default:
                break
            }
        }

        // 应用UI状态
        if shouldHideNavBar {
            setNavigationBarHidden(true)
        }
        if shouldHideStatusBar {
            setStatusBarHidden(true)
        }
        if let orientation = targetOrientation {
            updateOrientation(orientation)
        }

        print("✅ [WebBrowserVC] checkURLParameters completed")
    }

    /// 重置UI状态（当URL没有参数时调用）
    private func resetUIState() {
        print("🔄 [Browser] Resetting UI state to default...")
        
        // 显示导航栏和状态栏
        setNavigationBarHidden(false)
        setStatusBarHidden(false)
        
        // 恢复竖屏方向
        updateOrientation(.portrait)
        
        print("✅ [Browser] UI state reset to default")
    }

    /// 更新屏幕方向
    private func updateOrientation(_ orientation: UIInterfaceOrientation) {
        UIDevice.current.setValue(orientation.rawValue, forKey: "orientation")
        UIViewController.attemptRotationToDeviceOrientation()
    }

    /// 设置 TabBar 隐藏状态（动态）
    private func setTabBarHidden(_ hidden: Bool) {
        guard let tabBarController = self.tabBarController else {
            print("⚠️ [Browser] No TabBarController found")
            return
        }

        print("🎛️ [Browser] setTabBarHidden called: hidden=\(hidden)")

        // 隐藏/显示 TabBar
        tabBarController.tabBar.isHidden = hidden

        // 🔥 关键：强制 TabBarController 更新布局
        tabBarController.view.setNeedsLayout()
        tabBarController.view.layoutIfNeeded()

        print("🎛️ [Browser] TabBar isHidden: \(tabBarController.tabBar.isHidden)")
        print("🎛️ [Browser] TabBar frame: \(tabBarController.tabBar.frame)")
        print("🎛️ [Browser] ViewController frame: \(self.view.frame)")
    }

    /// 设置导航栏隐藏状态
    private func setNavigationBarHidden(_ hidden: Bool) {
        hideNavBar = hidden

        // 🔥 Only control the system navigation bar now
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Hide/show the system navigation bar
            self.navigationController?.navigationBar.isHidden = hidden
            self.navigationController?.setNavigationBarHidden(hidden, animated: false)

            // 如果显示导航栏，确保按钮状态正确
            if !hidden {
                let canGoBack = self.webView.canGoBack
                if canGoBack {
                    self.navigationItem.leftBarButtonItems = [self.backBarButton!, self.closeBarButton!]
                } else {
                    self.navigationItem.leftBarButtonItems = [self.closeBarButton!]
                }
            }

            // 🔥 Update webView constraints based on navigation bar visibility
            self.webView.snp.remakeConstraints { make in
                make.left.right.equalToSuperview()

                if hidden {
                    // 全屏模式：约束到屏幕边缘，不留白色空白
                    make.top.equalTo(self.view.snp.top)
                    make.bottom.equalTo(self.view.snp.bottom)
                } else {
                    // 普通模式：约束到 safe area top（under system navigation bar）
                    make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top)
                    make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottom)
                }
            }

            // 🔥 Prevent webView from automatically adjusting content insets
            self.webView.scrollView.contentInsetAdjustmentBehavior = .never

            // 🔥 Set view background to black in fullscreen mode to avoid white edges
            if hidden {
                self.view.backgroundColor = .black
                self.webView.backgroundColor = .clear
                self.webView.scrollView.backgroundColor = .clear
            } else {
                self.view.backgroundColor = WKColor.background.primary
                self.webView.backgroundColor = .clear
                self.webView.scrollView.backgroundColor = .clear
            }

            self.view.layoutIfNeeded()

            print("🎛️ [Browser] System NavigationBar: \(hidden ? "隐藏" : "显示")")
        }
    }

    /// 设置状态栏隐藏状态
    private func setStatusBarHidden(_ hidden: Bool) {
        isStatusBarHidden = hidden

        // 🔥 Hide/show system status bar
        // Set prefersStatusBarHidden property
        setNeedsStatusBarAppearanceUpdate()

        print("📱 [Browser] 状态栏: \(hidden ? "隐藏" : "显示")")
    }

    private func dismissOrPop() {
        if let navigationController = navigationController, navigationController.viewControllers.count > 1 {
            // 在导航栈中，弹出当前页面
            navigationController.popViewController(animated: true)
        } else if presentingViewController != nil {
            // 被 present 出来的，dismiss
            dismiss(animated: true)
        } else if let tabBarController = tabBarController {
            // 如果是 TabBar 的根页面且没有上一级，切换到第一个 Tab
            tabBarController.selectedIndex = 0
        }
    }

    // MARK: - Bind ViewModel

    public override func bindViewModel() {
        // 设置导航代理（用于自动缓存）- 确保在 viewDidLoad 时也被设置
        webView.navigationDelegate = self
        WebBridgeLogger.shared.info("🔧 bindViewModel - navigationDelegate set")

        let output = viewModel.transform(input: WebBrowserViewModel.Input(
            loadURL: .empty(),
            goBack: backButton.rx.tap.asDriver(),
            goForward: .empty(),
            reload: .empty(),
            stopLoading: .empty(),
            bookmarkToggle: .empty(),
            menuTap: menuButton.rx.tap.asDriver()
        ))

        // 绑定标题
        output.title
            .drive(onNext: { [weak self] title in
                // 如果标题是 localhost，则不显示，保持界面简洁
                if title == "localhost" {
                    self?.titleLabel.text = ""
                } else {
                    self?.titleLabel.text = title ?? NSLocalizedString("Browser", comment: "")
                }
            })
            .disposed(by: rx)

    /// 绑定后退状态 - 控制后退按钮显示
    output.canGoBack
        .drive(onNext: { [weak self] canGoBack in
            guard let self = self else { return }
            
            if canGoBack {
                self.backBarButton?.isEnabled = true
                self.backBarButton?.tintColor = .label
            } else {
                self.backBarButton?.isEnabled = false
                self.backBarButton?.tintColor = .clear
            }
            
            // 🔥 根据是否可以后退来动态调整左侧按钮
            if self.hideNavBar == false {
                if canGoBack {
                    self.navigationItem.leftBarButtonItems = [self.backBarButton!, self.closeBarButton!]
                } else {
                    self.navigationItem.leftBarButtonItems = [self.closeBarButton!]
                }
            }
        })
        .disposed(by: rx)

        // 绑定加载进度
        output.estimatedProgress
            .drive(onNext: { [weak self] progress in
                self?.progressView.setProgress(Float(progress), animated: true)
                self?.progressView.isHidden = progress >= 1.0
            })
            .disposed(by: rx)

        // 菜单
        output.showMenu
            .drive(onNext: { [weak self] in
                self?.showMenu()
            })
            .disposed(by: rx)

        // 监听 URL 变化
        output.url
            .drive(onNext: { [weak self] url in
                self?.currentURL = url
            })
            .disposed(by: rx)
        
        // 设置自定义 User-Agent
        setupUserAgent()
    }

    /// 设置自定义 User-Agent，包含版本号、屏幕尺寸和倍率
    private func setupUserAgent() {
        // 获取原始 UA 并追加自定义信息
        webView.evaluateJavaScript("navigator.userAgent") { [weak self] (result, error) in
            guard let self = self, let baseUA = result as? String else { return }
            
            let info = Bundle.main.infoDictionary
            let appVersion = info?["CFBundleShortVersionString"] as? String ?? "1.0.0"
            let buildNumber = info?["CFBundleVersion"] as? String ?? "1"
            
            let screenSize = UIScreen.main.bounds.size
            let screenScale = UIScreen.main.scale
            
            // 格式: BaseUA WebBridgeKit/Version (Build; Screen/WxH; Ratio/R)
            let customUA = "\(baseUA) WebBridgeKit/\(appVersion) (\(buildNumber); Screen/\(Int(screenSize.width))x\(Int(screenSize.height)); Ratio/\(screenScale))"
            
            self.webView.customUserAgent = customUA
            print("📱 [WebBrowserVC] Custom UA configured: \(customUA)")
        }
    }

    // MARK: - Welcome Page

    private func loadWelcomePage() {
        let welcomeHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Bark 浏览器</title>
            <style>
                * { box-sizing: border-box; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    margin: 0;
                    padding: 16px;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    min-height: 100vh;
                }
                .container {
                    max-width: 600px;
                    margin: 0 auto;
                    background: white;
                    border-radius: 20px;
                    padding: 24px;
                    box-shadow: 0 20px 60px rgba(0,0,0,0.3);
                }
                h1 {
                    color: #667eea;
                    text-align: center;
                    margin-bottom: 8px;
                    font-size: 28px;
                }
                .subtitle {
                    text-align: center;
                    color: #666;
                    margin-bottom: 24px;
                    font-size: 14px;
                }
                .section {
                    margin: 24px 0;
                }
                .section-title {
                    font-size: 16px;
                    font-weight: 600;
                    color: #333;
                    margin-bottom: 12px;
                    border-bottom: 2px solid #667eea;
                    padding-bottom: 6px;
                }
                .link-list {
                    list-style: none;
                    padding: 0;
                    margin: 0;
                }
                .link-list li {
                    margin: 8px 0;
                }
                .link-list a {
                    display: block;
                    padding: 14px 16px;
                    background: #f7f7f7;
                    border-radius: 10px;
                    text-decoration: none;
                    color: #333;
                    transition: all 0.2s;
                    font-size: 14px;
                }
                .link-list a:active {
                    background: #667eea;
                    color: white;
                    transform: scale(0.98);
                }
                .feature-list {
                    display: grid;
                    grid-template-columns: 1fr 1fr;
                    gap: 10px;
                }
                .feature-item {
                    background: #f7f7f7;
                    padding: 16px;
                    border-radius: 10px;
                    text-align: center;
                }
                .feature-icon {
                    font-size: 28px;
                    margin-bottom: 6px;
                }
                .feature-text {
                    font-size: 13px;
                    color: #666;
                }
                .debug-btn {
                    background: #ff6b6b;
                    color: white;
                    border: none;
                    padding: 14px 24px;
                    border-radius: 10px;
                    font-size: 15px;
                    width: 100%;
                    margin-top: 16px;
                }
                #debugInfo {
                    display:none;
                    margin-top:16px;
                    padding:14px;
                    background:#f0f0f0;
                    border-radius:10px;
                    font-family:monospace;
                    font-size:11px;
                    line-height:1.6;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>🌐 Bark 浏览器</h1>
                <p class="subtitle">沉浸式全屏浏览 - 快速、简洁、智能</p>

                <div class="section">
                    <div class="section-title">📚 快速访问</div>
                    <ul class="link-list">
                        <li><a href="https://www.baidu.com">🔍 百度 - 搜索引擎</a></li>
                        <li><a href="https://github.com">🐙 GitHub - 代码托管</a></li>
                        <li><a href="https://www.apple.com">🍎 Apple - 官方网站</a></li>
                    </ul>
                </div>

                <div class="section">
                    <div class="section-title">✨ 功能特性</div>
                    <div class="feature-list">
                        <div class="feature-item">
                            <div class="feature-icon">📱</div>
                            <div class="feature-text">全屏沉浸</div>
                        </div>
                        <div class="feature-item">
                            <div class="feature-icon">⚡</div>
                            <div class="feature-text">快速加载</div>
                        </div>
                        <div class="feature-item">
                            <div class="feature-icon">🔖</div>
                            <div class="feature-text">收藏管理</div>
                        </div>
                        <div class="feature-item">
                            <div class="feature-icon">🔒</div>
                            <div class="feature-text">安全浏览</div>
                        </div>
                    </div>
                </div>

                <div class="section">
                    <div class="section-title">🔧 调试工具</div>
                    <button class="debug-btn" onclick="showDebugInfo()">查看调试信息</button>
                    <div id="debugInfo"></div>
                </div>

                <div class="section">
                    <div class="section-title">🎛️ URL 参数测试</div>
                    <ul class="link-list">
                        <li><a href="https://www.baidu.com?hideNavBar=1">隐藏导航栏打开百度</a></li>
                        <li><a href="https://www.baidu.com?hideStatusBar=1">隐藏状态栏打开百度</a></li>
                        <li><a href="https://www.baidu.com?hideNavBar=1&hideStatusBar=1">完全全屏打开百度</a></li>
                    </ul>
                </div>
            </div>

            <script>
                function showDebugInfo() {
                    const debugDiv = document.getElementById('debugInfo');
                    const info = {
                        'User Agent': navigator.userAgent.substring(0, 50) + '...',
                        'Platform': navigator.platform,
                        'Language': navigator.language,
                        'Screen': `${screen.width}x${screen.height}`,
                        'Viewport': `${window.innerWidth}x${window.innerHeight}`,
                        'Touch Support': 'ontouchstart' in window ? 'Yes' : 'No',
                        'JS Bridge': typeof window.webkit !== 'undefined' && typeof window.webkit.messageHandlers !== 'undefined' ? 'Available' : 'Not Available'
                    };

                    let html = '<strong>🔍 浏览器状态</strong><br><br>';
                    for (const [key, value] of Object.entries(info)) {
                        html += `<div style='margin:4px 0;'><strong>${key}:</strong> ${value}</div>`;
                    }
                    html += '<br><strong>✅ 页面加载完成</strong>';

                    debugDiv.innerHTML = html;
                    debugDiv.style.display = 'block';
                }
            </script>
        </body>
        </html>
        """

        webView.loadHTMLString(welcomeHTML, baseURL: Bundle.main.bundleURL)
    }

    // MARK: - JS Bridge Test Page

    private func loadJSBridgeTestPage() {
        let testHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
                body { font-family: -apple-system, sans-serif; padding: 16px; background: #f5f5f5; margin: 0; }
                h1 { color: #333; margin: 0 0 16px 0; }
                .status-bar { background: white; padding: 12px; border-radius: 8px; margin-bottom: 16px; }
                .status-bar.ok { background: #d4edda; color: #155724; }
                .status-bar.error { background: #f8d7da; color: #721c24; }
                .test-section { background: white; padding: 16px; border-radius: 8px; margin-bottom: 12px; }
                .test-section h3 { margin: 0 0 12px 0; }
                .btn-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
                button { padding: 10px; border: none; border-radius: 6px; color: white; font-size: 14px; cursor: pointer; width: 100%; }
                button:active { opacity: 0.7; }
                .btn-share { background: #667eea; }
                .btn-location { background: #f093fb; }
                .btn-system { background: #4facfe; }
                .btn-network { background: #00f2fe; }
                .btn-haptic { background: #fa709a; }
                .btn-vibrate { background: #fee140; color: #333; }
                .log-section { background: #1e1e1e; color: #f0f0f0; padding: 12px; border-radius: 8px; font-family: monospace; font-size: 11px; max-height: 250px; overflow-y: auto; }
                .log-entry { padding: 4px 0; border-bottom: 1px solid #333; }
                .log-success { color: #4ade80; }
                .log-error { color: #f87171; }
                .log-info { color: #60a5fa; }
            </style>
        </head>
        <body>
            <h1>🌉 Bark JS Bridge</h1>
            <div id="statusBar" class="status-bar">检测中...</div>

            <div class="test-section">
                <h3>📤 基础功能</h3>
                <button class="btn-share" onclick="callNative('share', {text: '来自 Bark 的分享', url: 'https://github.com/Finb/Bark'})">分享</button>
                <button class="btn-location" onclick="callNative('getLocation')">获取位置</button>
            </div>

            <div class="test-section">
                <h3>📱 系统信息</h3>
                <div class="btn-grid">
                    <button class="btn-system" onclick="callNative('getSystemInfo')">系统信息</button>
                    <button class="btn-network" onclick="callNative('getNetworkInfo')">网络状态</button>
                </div>
            </div>

            <div class="test-section">
                <h3>🎨 交互反馈</h3>
                <div class="btn-grid">
                    <button class="btn-haptic" onclick="callNative('haptic')">触觉反馈</button>
                    <button class="btn-vibrate" onclick="callNative('vibrate')">震动</button>
                </div>
            </div>

            <div class="log-section">
                <div id="logContainer"></div>
            </div>

            <script>
                function addLog(type, message, data) {
                    var logContainer = document.getElementById('logContainer');
                    var time = new Date().toLocaleTimeString();
                    var logClass = type === 'success' ? 'log-success' : type === 'error' ? 'log-error' : 'log-info';
                    var div = document.createElement('div');
                    div.className = 'log-entry';
                    div.innerHTML = '[' + time + '] [' + type.toUpperCase() + '] ' + message + (data ? ' ' + JSON.stringify(data) : '');
                    logContainer.insertBefore(div, logContainer.firstChild);
                    if (logContainer.children.length > 50) {
                        logContainer.removeChild(logContainer.lastChild);
                    }
                }

                function checkBridge() {
                    var hasBridge = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.BarkBridge;
                    var statusBar = document.getElementById('statusBar');
                    if (hasBridge) {
                        statusBar.className = 'status-bar ok';
                        statusBar.textContent = '✅ JS Bridge 可用';
                        addLog('success', 'JS Bridge 检测成功');
                    } else {
                        statusBar.className = 'status-bar error';
                        statusBar.textContent = '❌ JS Bridge 不可用';
                        addLog('error', 'JS Bridge 不可用');
                    }
                    return hasBridge;
                }

                function callNative(action, params) {
                    if (!checkBridge()) return;
                    addLog('info', '调用: ' + action, params);
                    try {
                        window.webkit.messageHandlers.BarkBridge.postMessage({ action: action, params: params || {} });
                        addLog('info', '请求已发送');
                    } catch (e) {
                        addLog('error', '调用失败: ' + e.message);
                    }
                }

                window.BarkBridge = window.BarkBridge || {};
                window.BarkBridge.receiveResult = function(result) {
                    if (result.success) {
                        addLog('success', '成功', result.data);
                    } else {
                        addLog('error', '失败: ' + (result.error || 'Unknown'));
                    }
                };

                setTimeout(checkBridge, 100);
            </script>
        </body>
        </html>
        """

        webView.loadHTMLString(testHTML, baseURL: nil)
        print("🌉 [Browser] 加载 JS 桥接测试页面")
    }

    // MARK: - Permissions Page

    private func loadPermissionsPage() {
        let permissionsHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
                body { font-family: -apple-system, sans-serif; padding: 16px; background: #f5f5f5; margin: 0; }
                h1 { color: #333; margin: 0 0 16px 0; }
                .summary-card { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 12px; margin-bottom: 20px; }
                .summary-title { font-size: 14px; opacity: 0.9; margin-bottom: 8px; }
                .summary-stats { display: flex; justify-content: space-around; }
                .stat-item { text-align: center; }
                .stat-value { font-size: 28px; font-weight: bold; }
                .stat-label { font-size: 11px; opacity: 0.8; }
                .permission-list { background: white; border-radius: 12px; overflow: hidden; }
                .permission-item { display: flex; align-items: center; padding: 16px; border-bottom: 1px solid #f0f0f0; }
                .permission-item:last-child { border-bottom: none; }
                .permission-icon { font-size: 28px; margin-right: 12px; }
                .permission-info { flex: 1; }
                .permission-name { font-size: 16px; font-weight: 600; color: #333; margin-bottom: 4px; }
                .permission-status { font-size: 13px; color: #666; }
                .status-badge { padding: 4px 10px; border-radius: 12px; font-size: 12px; font-weight: 600; }
                .status-authorized { background: #d4edda; color: #155724; }
                .status-denied { background: #f8d7da; color: #721c24; }
                .status-notDetermined { background: #fff3cd; color: #856404; }
                .status-limited { background: #d1ecf1; color: #0c5460; }
                .btn-settings { display: block; width: 100%; padding: 14px; background: #667eea; color: white; border: none; border-radius: 12px; font-size: 16px; font-weight: 600; margin-top: 16px; cursor: pointer; }
                .btn-settings:active { opacity: 0.8; }
                .loading { text-align: center; padding: 40px; color: #666; }
            </style>
        </head>
        <body>
            <h1>🔐 权限管理</h1>

            <div id="loading" class="loading">正在检测权限状态...</div>

            <div id="content" style="display: none;">
                <div class="summary-card">
                    <div class="summary-title">权限概览</div>
                    <div class="summary-stats">
                        <div class="stat-item">
                            <div class="stat-value" id="total">0</div>
                            <div class="stat-label">总计</div>
                        </div>
                        <div class="stat-item">
                            <div class="stat-value" id="granted">0</div>
                            <div class="stat-label">已授权</div>
                        </div>
                        <div class="stat-item">
                            <div class="stat-value" id="denied">0</div>
                            <div class="stat-label">已拒绝</div>
                        </div>
                    </div>
                </div>

                <div class="permission-list" id="permissionList"></div>

                <button class="btn-settings" onclick="openSettings()">打开系统设置</button>
            </div>

            <script>
                function callNative(action, params) {
                    try {
                        window.webkit.messageHandlers.BarkBridge.postMessage({ action: action, params: params || {} });
                    } catch (e) {
                        console.error('Native call failed:', e);
                    }
                }

                function openSettings() {
                    callNative('openSettings');
                }

                function getStatusBadge(status) {
                    switch(status) {
                        case 'authorized':
                            return '<span class="status-badge status-authorized">✅ 已授权</span>';
                        case 'denied':
                            return '<span class="status-badge status-denied">❌ 已拒绝</span>';
                        case 'notDetermined':
                            return '<span class="status-badge status-notDetermined">⚠️ 未请求</span>';
                        case 'limited':
                            return '<span class="status-badge status-limited">⚡️ 部分授权</span>';
                        default:
                            return '<span class="status-badge status-notDetermined">❓ 未知</span>';
                    }
                }

                function renderPermissions(data) {
                    var permissions = data.permissions;
                    var summary = data.summary;

                    // 更新概览
                    document.getElementById('total').textContent = summary.total;
                    document.getElementById('granted').textContent = summary.granted;
                    document.getElementById('denied').textContent = summary.denied;

                    // 渲染权限列表
                    var listHTML = '';
                    for (var i = 0; i < permissions.length; i++) {
                        var perm = permissions[i];
                        listHTML += '<div class="permission-item">';
                        listHTML += '<div class="permission-icon">' + perm.icon + '</div>';
                        listHTML += '<div class="permission-info">';
                        listHTML += '<div class="permission-name">' + perm.displayName + '</div>';
                        listHTML += '<div class="permission-status">' + getStatusBadge(perm.status) + '</div>';
                        listHTML += '</div>';
                        listHTML += '</div>';
                    }

                    document.getElementById('permissionList').innerHTML = listHTML;
                    document.getElementById('loading').style.display = 'none';
                    document.getElementById('content').style.display = 'block';
                }

                // 页面加载时获取权限状态
                setTimeout(function() {
                    callNative('getPermissionStatus');
                }, 100);

                // 接收权限数据
                window.BarkBridge = window.BarkBridge || {};
                window.BarkBridge.receiveResult = function(result) {
                    if (result.success && result.data && result.data.permissions) {
                        renderPermissions(result.data);
                    }
                };
            </script>
        </body>
        </html>
        """

        webView.loadHTMLString(permissionsHTML, baseURL: nil)
        print("🔐 [Browser] 加载权限管理页面")
    }

    // MARK: - Voice Jump Game

    private func loadGamePage() {
        // 从 bundle 加载游戏文件
        if let htmlPath = Bundle.main.path(forResource: "game", ofType: "html") {
            do {
                let htmlHTML = try String(contentsOfFile: htmlPath)
                webView.loadHTMLString(htmlHTML, baseURL: Bundle.main.bundleURL)
                print("🎮 [Browser] 加载语音控制游戏页面")
            } catch {
                print("❌ [Browser] 游戏文件加载失败: \(error)")
                showErrorPage(message: "游戏文件加载失败")
            }
        } else {
            print("❌ [Browser] 未找到游戏文件")
            showErrorPage(message: "未找到游戏文件")
        }
    }

    private func showErrorPage(message: String = "加载失败") {
        let errorHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body { font-family: -apple-system, sans-serif; padding: 40px 20px; text-align: center; background: #1a1a2e; }
                h1 { color: #ff3b30; margin-bottom: 20px; }
                p { color: #aaa; font-size: 16px; }
            </style>
        </head>
        <body>
            <h1>😕 加载失败</h1>
            <p>\(message)</p>
        </body>
        </html>
        """
        webView.loadHTMLString(errorHTML, baseURL: nil)
    }

    // MARK: - Menu

    private func showMenu() {
        let alertController = UIAlertController(
            title: NSLocalizedString("Browser Menu", comment: ""),
            message: nil,
            preferredStyle: .actionSheet
        )

        // 刷新页面
        alertController.addAction(UIAlertAction(title: NSLocalizedString("🔄 Refresh", comment: ""), style: .default) { [weak self] _ in
            self?.webView.reload()
        })

        // 切换导航栏显示/隐藏
        let toggleTitle = hideNavBar ? "📌 显示导航栏" : "🎯 隐藏导航栏"
        alertController.addAction(UIAlertAction(title: NSLocalizedString(toggleTitle, comment: ""), style: .default) { [weak self] _ in
            self?.setNavigationBarHidden(!(self?.hideNavBar ?? false))
        })

        // 切换状态栏显示/隐藏
        let statusBarToggleTitle = isStatusBarHidden ? "📊 显示状态栏" : "📱 隐藏状态栏"
        alertController.addAction(UIAlertAction(title: NSLocalizedString(statusBarToggleTitle, comment: ""), style: .default) { [weak self] _ in
            self?.setStatusBarHidden(!(self?.isStatusBarHidden ?? false))
        })

        // 收藏/取消收藏
        if let url = webView.url {
            let favoriteService = ServiceLocator.favorite
            let isFavorited = favoriteService.findFavorite(url: url) != nil
            let favoriteTitle = isFavorited ? "⭐ 取消收藏" : "☆ 收藏页面"
            
            alertController.addAction(UIAlertAction(title: NSLocalizedString(favoriteTitle, comment: ""), style: .default) { [weak self] _ in
                guard let self = self else { return }
                if isFavorited {
                    favoriteService.deleteFavorite(url: url)
                } else {
                    self.fetchFavicon { data in
                        favoriteService.addFavorite(url: url, title: self.webView.title, favicon: data)
                    }
                }
            })
        }

        // 查看收藏
        alertController.addAction(UIAlertAction(title: NSLocalizedString("📚 Bookmarks", comment: ""), style: .default) { [weak self] _ in
            self?.showBookmarks()
        })

        // JS 桥接测试
        alertController.addAction(UIAlertAction(title: NSLocalizedString("🌉 JS Bridge Test", comment: ""), style: .default) { [weak self] _ in
            self?.loadJSBridgeTestPage()
        })

        // 语音控制游戏
        alertController.addAction(UIAlertAction(title: NSLocalizedString("🎮 Voice Game", comment: ""), style: .default) { [weak self] _ in
            self?.loadGamePage()
        })

        // 权限管理
        alertController.addAction(UIAlertAction(title: NSLocalizedString("🔐 Permissions", comment: ""), style: .default) { [weak self] _ in
            self?.loadPermissionsPage()
        })

        // 查看缓存统计
        alertController.addAction(UIAlertAction(title: NSLocalizedString("💾 Cache Statistics", comment: ""), style: .default) { [weak self] _ in
            self?.showCacheStatistics()
        })

        // 缓存调试面板
        alertController.addAction(UIAlertAction(title: NSLocalizedString("🗂️ Cache Debug", comment: ""), style: .default) { [weak self] _ in
            self?.showCacheDebugPanel()
        })

        // 查看性能信息
        alertController.addAction(UIAlertAction(title: NSLocalizedString("📊 Performance Info", comment: ""), style: .default) { [weak self] _ in
            self?.showPerformanceInfo()
        })

        // 调试信息
        alertController.addAction(UIAlertAction(title: NSLocalizedString("🔍 Debug Info", comment: ""), style: .default) { [weak self] _ in
            self?.showDebugInfo()
        })

        // 返回欢迎页
        alertController.addAction(UIAlertAction(title: NSLocalizedString("🏠 Welcome Page", comment: ""), style: .default) { [weak self] _ in
            self?.loadWelcomePage()
        })

        alertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))

        present(alertController, animated: true)
    }

    private func showBookmarks() {
        let bookmarksVC = WebBookmarkViewController(viewModel: WebBookmarkViewModel())
        navigationController?.pushViewController(bookmarksVC, animated: true)
    }

    private func showCacheStatistics() {
        WebCacheManager.shared.fetchCacheStatistics()
            .subscribe(onNext: { stats in
                let message = stats.map { stat in
                    "\(stat.domain): \(ByteCountFormatter.string(fromByteCount: stat.totalSize, countStyle: .file))"
                }.joined(separator: "\n")

                let alert = UIAlertController(
                    title: NSLocalizedString("Cache Statistics", comment: ""),
                    message: message.isEmpty ? "No cache data" : message,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default))
                self.present(alert, animated: true)
            })
            .disposed(by: rx)
    }

    private func showCacheDebugPanel() {
        let debugPanel = WebCacheDebugPanelViewController()
        let navController = UINavigationController(rootViewController: debugPanel)
        present(navController, animated: true)
    }

    private func showPerformanceInfo() {
        guard let currentURL = webView.url else {
            let alert = UIAlertController(
                title: "Performance Info",
                message: "No page loaded",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        let domain = currentURL.host ?? "unknown"
        let report = WebViewPerformanceMonitor.shared.generateReport()

        let alert = UIAlertController(
            title: "Performance Info (\(domain))",
            message: report,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func showDebugInfo() {
        let info = [
            "📱 当前 URL": webView.url?.absoluteString ?? "None",
            "📄 页面标题": webView.title ?? "None",
            "⬅️ 可以后退": webView.canGoBack ? "是" : "否",
            "➡️ 可以前进": webView.canGoForward ? "是" : "否",
            "🔄 加载中": webView.isLoading ? "是" : "否",
            "📊 加载进度": String(format: "%.1f%%", webView.estimatedProgress * 100),
            "🎛️ 导航栏": hideNavBar ? "隐藏" : "显示",
            "📊 状态栏": isStatusBarHidden ? "隐藏" : "显示"
        ]

        let message = info.map { "\($0.key): \($0.value)" }.joined(separator: "\n")

        let alert = UIAlertController(
            title: "🔍 调试信息",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    /// 获取页面图标
    /// - Parameter completion: 完成回调，返回图标数据
    private func fetchFavicon(completion: @escaping (Data?) -> Void) {
        // 1. 尝试从网页中提取 favicon URL
        let script = """
        (function() {
            function getIcon(rel) {
                var links = document.getElementsByTagName('link');
                for (var i = 0; i < links.length; i++) {
                    var r = links[i].getAttribute('rel');
                    if (r && r.toLowerCase() === rel.toLowerCase()) {
                        return links[i].href;
                    }
                }
                return null;
            }
            
            // 优先级：apple-touch-icon > icon > shortcut icon
            var icon = getIcon('apple-touch-icon') || 
                       getIcon('icon') || 
                       getIcon('shortcut icon');
            
            if (icon) return icon;
            
            // 搜索包含 icon 的 rel
            var links = document.getElementsByTagName('link');
            for (var i = 0; i < links.length; i++) {
                var r = links[i].getAttribute('rel');
                if (r && r.toLowerCase().indexOf('icon') !== -1) {
                    return links[i].href;
                }
            }
            
            return window.location.origin + '/favicon.ico';
        })()
        """
        
        webView.evaluateJavaScript(script) { [weak self] result, error in
            guard let self = self,
                  let urlString = result as? String,
                  let url = URL(string: urlString) else {
                completion(nil)
                return
            }
            
            // 2. 下载图标数据
            var request = URLRequest(url: url)
            request.timeoutInterval = 5.0 // 设置超时
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    if let data = data, let _ = UIImage(data: data) {
                        completion(data)
                    } else {
                        // 如果失败，尝试根目录的 favicon.ico (如果刚才不是尝试的这个)
                        if !urlString.hasSuffix("/favicon.ico"),
                           let rootUrl = URL(string: "/favicon.ico", relativeTo: self.webView.url) {
                            self.downloadFavicon(url: rootUrl, completion: completion)
                        } else {
                            completion(nil)
                        }
                    }
                }
            }.resume()
        }
    }
    
    /// 下载图标数据的辅助方法
    private func downloadFavicon(url: URL, completion: @escaping (Data?) -> Void) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 3.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let data = data, let _ = UIImage(data: data) {
                    completion(data)
                } else {
                    completion(nil)
                }
            }
        }.resume()
    }

    // MARK: - Deinit

    deinit {
        // 🔒 Stop any ongoing loading
        webView.stopLoading()

        // 🔒 Remove all script message handlers to prevent memory leaks
        // WKUserContentController.add(_:name:) creates strong references
        for handlerName in registeredHandlerNames {
            webView.configuration.userContentController.removeScriptMessageHandler(forName: handlerName)
        }
        registeredHandlerNames.removeAll()

        // 🔒 Clear delegates to break strong reference cycles
        webView.navigationDelegate = nil
        webView.uiDelegate = nil

        // 🔒 Remove from superview
        webView.removeFromSuperview()

        print("🧹 [WebBrowserVC] Cleaned up with proper memory management")
    }
}

// MARK: - UIGestureRecognizerDelegate

extension WebBrowserViewController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // 只在导航栏隐藏时响应手势
        return hideNavBar
    }
}

// MARK: - Status Bar Control

extension WebBrowserViewController {
    /// 重写状态栏隐藏属性
    public override var prefersStatusBarHidden: Bool {
        return isStatusBarHidden
    }

    /// 状态栏动画样式
    public override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .slide
    }

    /// 支持的屏幕方向
    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        // 如果是强制横屏，只返回横屏
        // 这里可以根据当前 state 动态返回
        return .allButUpsideDown
    }

    /// 是否自动旋转
    public override var shouldAutorotate: Bool {
        return true
    }
}

// MARK: - WKNavigationDelegate - Auto-Capture by Rules

extension WebBrowserViewController: WKNavigationDelegate {

    /// 处理导航策略，防止系统弹窗和外部跳转
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        // 1. 如果是主框架的跳转，且是 http/https，则允许在当前 WebView 加载
        // 2. 如果是 target="_blank"，强制在当前 WebView 加载，防止弹出系统浏览器
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
            decisionHandler(.cancel)
            return
        }

        // 3. 处理特殊协议 (如 tel:, mailto:, itms-services: 等)
        let scheme = url.scheme?.lowercased() ?? ""
        if !["http", "https", "file", "about", "manifest-cache"].contains(scheme) {
            // 如果需要支持这些协议，可以在这里调用 UIApplication.shared.open
            // 但为了避免弹窗干扰测试，我们先打印日志并允许
            print("🔗 [Browser] 拦截到特殊协议跳转: \(url.absoluteString)")
        }

        decisionHandler(.allow)
    }

    /// 页面加载完成 - 检查是否需要自动缓存页面
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url else { return }

        print("📄 ========================================")
        print("📄 页面加载完成")
        print("- URL: \(url.absoluteString)")
        print("- Title: \(webView.title ?? "nil")")
        print("📄 ========================================")
        WebBridgeLogger.shared.info("📄 Page loaded: \(url.absoluteString)")

        // 🔥 每次页面加载完成后都检查URL参数（支持页面内导航）
        checkURLParameters(url)

        // 更新历史记录 - 使用 async API
        fetchFavicon { [weak self] faviconData in
            guard let self = self else { return }

            // 在 MainActor 上执行异步数据库操作
            Task { @MainActor in
                do {
                    try await WebPageHistoryManager.shared.addOrUpdateHistory(
                        url: url,
                        title: self.webView.title,
                        favicon: faviconData
                    )

                    // 发送通知，告知历史记录已更新
                    NotificationCenter.default.post(name: .historyDidUpdate, object: nil)

                    print("✅ History updated successfully for: \(url.absoluteString)")
                } catch {
                    WebBridgeLogger.shared.log(.error, "Failed to update history: \(error.localizedDescription)")
                    print("❌ Failed to update history for \(url.absoluteString): \(error.localizedDescription)")
                }
            }
        }

        // 检查 URL 是否匹配页面缓存规则
        let (shouldCache, matchedRule) = PageCacheRuleManager.shared.shouldCache(url: url)

        print("🔍 缓存检查结果:")
        print("- shouldCache: \(shouldCache)")
        print("- matchedRule: \(matchedRule?.name ?? "nil")")
        print("🔍 ========================================")
        WebBridgeLogger.shared.info("🔍 Cache check - shouldCache: \(shouldCache), matchedRule: \(matchedRule?.name ?? "nil")")

        if shouldCache, let rule = matchedRule {
            print("🎯 触发自动缓存，规则: \(rule.name)")
            WebBridgeLogger.shared.info("🎯 URL '\(url.absoluteString)' matches page cache rule: \(rule.name)")

            // 自动缓存页面及所有资源
            autoCachePage(url: url, rule: rule)
        }
    }

    /// 自动缓存 URL 对应的页面及所有资源
    private func autoCachePage(url: URL, rule: PageCacheRule) {
        print("🎯 ========================================")
        print("🎯 开始自动缓存页面")
        print("- URL: \(url.absoluteString)")
        print("- 规则: \(rule.name)")
        print("🎯 ========================================")

        // 使用 WebPageOfflineCacheManager 缓存页面
        WebPageOfflineCacheManager.shared.cachePage(
            url: url,
            rule: rule
        ) { progress in
            print("📊 [\(rule.name)] 缓存进度: \(Int(progress * 100))%")
            WebBridgeLogger.shared.info("Caching progress: \(progress * 100)%")
        } completion: { result in
            switch result {
            case .success(let pageInfo):
                print("✅ ========================================")
                print("✅ 自动缓存成功！")
                print("- URL: \(url.absoluteString)")
                print("- 规则: \(rule.name)")
                print("- 标题: \(pageInfo.title)")
                print("- 资源数: \(pageInfo.resourceCount)")
                print("- 大小: \(pageInfo.formattedSize)")
                print("✅ ========================================")
                WebBridgeLogger.shared.info("""
                ✅ Page cached by rule '\(rule.name)':
                - URL: \(url.absoluteString)
                - Title: \(pageInfo.title)
                - Resources: \(pageInfo.resourceCount)
                - Size: \(pageInfo.formattedSize)
                - Cached at: \(pageInfo.formattedCachedAt)
                """)

            case .failure(let error):
                print("❌ ========================================")
                print("❌ 自动缓存失败！")
                print("- URL: \(url.absoluteString)")
                print("- 错误: \(error.localizedDescription)")
                print("❌ ========================================")
                WebBridgeLogger.shared.error("❌ Failed to cache page: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Cache Support

    /// 使用 Manifest 缓存加载 URL
    /// - Parameters:
    ///   - url: 要加载的 URL
    ///   - forceRefresh: 是否强制刷新（绕过缓存）
    /// - Note: 此方法会自动检测 manifest.json，根据 persistent 字段选择懒加载或持久化模式
    public func loadURLWithCache(_ url: URL, forceRefresh: Bool = false) {
        print("🌐 [WebBrowserVC] Loading URL with cache: \(url.absoluteString)")

        // 🔥 处理 payload 注入 URL (如果存在)
        var targetURL = url
        if let browserVC = self as? WebViewController,
           let payload = browserVC.browserConfig?.payload {
            if var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                var queryItems = components.queryItems ?? []
                for (key, value) in payload {
                    if !queryItems.contains(where: { $0.name == key }) {
                        queryItems.append(URLQueryItem(name: key, value: value))
                    }
                }
                components.queryItems = queryItems
                if let newURL = components.url {
                    targetURL = newURL
                    print("🔗 [WebBrowserVC] Appended payload to cache-load URL: \(newURL.absoluteString)")
                }
            }
        }

        currentURL = targetURL

        // 更新 UI 显示正在通过缓存检查
        updateCacheStatus(source: "CHECKING")

        // 使用 LazyManifestLoader.smartLoad() 智能加载
        LazyManifestLoader.smartLoad(
            url: url,
            in: webView,
            from: self,
            forceRefresh: forceRefresh
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }

                switch result {
                case .success:
                    print("✅ [WebBrowserVC] URL loaded with cache: \(url.absoluteString)")
                    // 检查是否真正命中了缓存。如果已经是 MANIFEST/INTERCEPT (由通知设置)，则不需要重置为 LIVE
                    if self.currentCacheSource == "CHECKING" || self.currentCacheSource == "LIVE" {
                        let isActuallyCached = self.checkIfActuallyCached(for: url)
                        if !isActuallyCached {
                            self.updateCacheStatus(source: "LIVE")
                        }
                    }
                case .failure(let error):
                    print("❌ [WebBrowserVC] Failed to load URL: \(error.localizedDescription)")
                    self.updateCacheStatus(source: "LIVE")
                    
                    // 🔥 优化：如果是自定义协议请求失败，显示错误提示页，而不是白屏
                    let isCustomScheme = url.scheme == "custom" || url.scheme == "wb-resource"
                    if isCustomScheme {
                        self.loadErrorPage(url: url, error: error)
                    } else {
                        // 回退到普通加载
                        if url.isFileURL {
                            self.webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
                        } else {
                            let request = URLRequest(url: url)
                            self.webView.load(request)
                        }
                    }
                }
            }
        }
    }

    /// 加载错误提示页面
    /// - Parameters:
    ///   - url: 失败的 URL
    ///   - error: 错误信息
    public func loadErrorPage(url: URL, error: Error) {
        let errorHTML = generateErrorHTML(url: url, error: error)
        webView.loadHTMLString(errorHTML, baseURL: url)
        print("⚠️ [WebBrowserVC] Loaded error page for: \(url.absoluteString)")
    }

    /// 生成错误提示 HTML
    /// - Parameters:
    ///   - url: 失败的 URL
    ///   - error: 错误信息
    /// - Returns: HTML 字符串
    private func generateErrorHTML(url: URL, error: Error) -> String {
        let urlString = url.absoluteString
        let errorMessage = error.localizedDescription
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>WebBridge 资源加载失败</title>
            <style>
                body { font-family: -apple-system, sans-serif; background-color: #f8f9fa; margin: 0; padding: 20px; color: #2d3748; line-height: 1.5; }
                .container { max-width: 600px; margin: 40px auto; background: white; padding: 30px; border-radius: 12px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); border-top: 6px solid #e53e3e; }
                h1 { color: #c53030; font-size: 22px; margin-top: 0; display: flex; align-items: center; }
                .icon { font-size: 28px; margin-right: 12px; }
                .info-box { background: #fff5f5; border: 1px solid #feb2b2; padding: 15px; border-radius: 8px; margin: 20px 0; word-break: break-all; }
                .label { font-weight: bold; color: #742a2a; display: block; margin-bottom: 5px; font-size: 14px; text-transform: uppercase; letter-spacing: 0.5px; }
                code { background: #edf2f7; padding: 3px 6px; border-radius: 4px; font-family: "SFMono-Regular", Consolas, monospace; font-size: 13px; color: #1a202c; }
                .footer { margin-top: 30px; font-size: 14px; color: #4a5568; border-top: 1px solid #edf2f7; padding-top: 20px; }
                ul { padding-left: 20px; margin-top: 10px; }
                li { margin-bottom: 8px; }
                .btn { display: inline-block; background: #4a5568; color: white; padding: 8px 16px; border-radius: 6px; text-decoration: none; margin-top: 15px; font-size: 14px; }
                .btn:hover { background: #2d3748; }
            </style>
        </head>
        <body>
            <div class="container">
                <h1><span class="icon">🚫</span>WebBridge 资源加载失败</h1>
                <p>在处理缓存加载请求时遇到了错误，无法加载目标页面。</p>
                
                <div class="info-box">
                    <span class="label">请求地址 (Request URL):</span>
                    <code>\(urlString)</code>
                </div>
                
                <div class="info-box">
                    <span class="label">错误原因 (Error):</span>
                    <code>\(errorMessage)</code>
                </div>
                
                <div class="footer">
                    <span class="label">排查建议:</span>
                    <ul>
                        <li>检查网络连接是否正常。</li>
                        <li>确认 <code>manifest.json</code> 映射表是否包含该相对路径。</li>
                        <li>如果是 <code>wb-resource://</code>，请确认持久化缓存目录中是否存在该文件。</li>
                        <li>尝试在管理页面清理缓存并重新加载。</li>
                    </ul>
                    <a href="javascript:location.reload()" class="btn">重试加载 (Reload)</a>
                </div>
            </div>
        </body>
        </html>
        """
    }

    /// 更新缓存状态显示
    private func updateCacheStatus(source: String) {
        // 立即更新状态变量，用于逻辑判断
        self.currentCacheSource = source
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.cacheStatusLabel.text = source
            
            switch source {
            case "LIVE":
                self.cacheStatusLabel.backgroundColor = WKColor.grey.base.withAlphaComponent(0.6)
            case "INTERCEPT":
                self.cacheStatusLabel.backgroundColor = .systemGreen
            case "MANIFEST", "HTML":
                self.cacheStatusLabel.backgroundColor = .systemBlue
            case "CHECKING":
                self.cacheStatusLabel.backgroundColor = .systemOrange
            default:
                self.cacheStatusLabel.backgroundColor = .systemOrange
            }
            
            print("📱 [Browser] Cache Status Updated: \(source)")
        }
    }

    /// 检查是否真正使用了缓存
    private func checkIfActuallyCached(for url: URL) -> Bool {
        NSLog("🔍 [Browser] Checking cache for URL: %@", url.absoluteString)
        
        // 1. 检查 PersistentManifestLoader (持久化模式)
        if PersistentManifestLoader.shared.isCached(url: url) {
            NSLog("✅ [Browser] Cache Hit: Persistent (MANIFEST)")
            updateCacheStatus(source: "MANIFEST")
            return true
        }

        // 2. 尝试解析 AppID
        let appID = AppIDResolver.resolveAppID(from: url)
        NSLog("🔍 [Browser] Resolved AppID: %@", appID)
        
        // 3. 检查 ManifestCacheManager (懒加载模式/HTML 缓存)
        if let manifest = ManifestCacheManager.shared.getCachedManifest(for: appID) {
            NSLog("✅ [Browser] Cache Hit: Lazy Manifest (INTERCEPT), persistent=%d", manifest.persistent ?? false)
            updateCacheStatus(source: "INTERCEPT")
            return true
        }
        
        // 4. 检查 InterceptiveCacheManager (已删除)
        // if InterceptiveCacheManager.shared.hasCachedResource(for: url) {
        //     NSLog("✅ [Browser] Cache Hit: Interceptive Resource (INTERCEPT)")
        //     updateCacheStatus(source: "INTERCEPT")
        //     return true
        // }
        
        NSLog("❌ [Browser] Cache Miss")
        return false
    }
}
