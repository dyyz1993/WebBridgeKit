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

/// 浏览器主页面 - 全屏沉浸式
public class WebBrowserViewController: BaseViewController<WebBrowserViewModel> {

    // MARK: - UI Components

    lazy var webView: WKWebView = {
        return viewModel.getWebView()
    }()

    let progressView: UIProgressView = {
        let progressView = UIProgressView(progressViewStyle: .default)
        progressView.tintColor = ThemeTokens.Color.textSecondary
        progressView.trackTintColor = ThemeTokens.Color.textTertiary
        return progressView
    }()

    /// 缓存状态标签
    let cacheStatusLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.caption2
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = ThemeTokens.Color.textSecondary.withAlphaComponent(0.6)
        label.layer.cornerRadius = ThemeTokens.CornerRadius.sm
        label.clipsToBounds = true
        label.text = "LIVE"
        label.isHidden = false
        return label
    }()

    /// 标题容器
    let titleContainerView: UIView = {
        let view = UIView()
        return view
    }()

    /// 标题标签
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.callout
        label.textColor = ThemeTokens.Color.textSecondary
        label.textAlignment = .center
        label.numberOfLines = 1
        label.accessibilityIdentifier = "browserManager.titleLabel"
        return label
    }()

    /// 关闭/后退按钮
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        let image = LucideIcon.xmark.templateImage(pointSize: 20, weight: .medium)
        button.setImage(image, for: .normal)
        button.tintColor = ThemeTokens.Color.textSecondary
        button.accessibilityIdentifier = "browserManager.closeButton"
        button.accessibilityLabel = "关闭"
        return button
    }()

    /// 后退按钮（当有历史时显示）
    private let backButton: UIButton = {
        let button = UIButton(type: .system)
        let image = LucideIcon.chevronLeft.templateImage(pointSize: 20, weight: .medium)
        button.setImage(image, for: .normal)
        button.tintColor = ThemeTokens.Color.textSecondary
        button.accessibilityIdentifier = "browserManager.backButton"
        button.accessibilityLabel = "返回"
        return button
    }()

    /// 更多菜单按钮
    private let menuButton: UIButton = {
        let button = UIButton(type: .system)
        let image = LucideIcon.chevronDown.templateImage(pointSize: 20, weight: .regular)
        button.setImage(image, for: .normal)
        button.tintColor = ThemeTokens.Color.textSecondary
        button.accessibilityIdentifier = "browserManager.menuButton"
        button.accessibilityLabel = "更多菜单"
        return button
    }()

    /// 手势 - 点击底部区域关闭（当导航栏隐藏时）
    var tapGesture: UITapGestureRecognizer?

    // MARK: - Bar Buttons

    var backBarButton: UIBarButtonItem?
    var closeBarButton: UIBarButtonItem?
    var menuBarButton: UIBarButtonItem?

    // MARK: - Properties

    /// 是否隐藏导航栏
    var hideNavBar = false

    /// 是否隐藏状态栏
    var isStatusBarHidden: Bool = false {
        didSet {
            setNeedsStatusBarAppearanceUpdate()
        }
    }

    /// 当前 URL
    var currentURL: URL?

    /// 当前缓存来源标识
    var currentCacheSource: String = "LIVE"

    /// 调试模式：启用时会显示错误页面而不是白屏
    public var debugMode: Bool = false

    /// Track all registered script message handler names for proper cleanup
    var registeredHandlerNames: [String] = []

    // MARK: - Initialization

    override init(viewModel: WebBrowserViewModel) {
        super.init(viewModel: viewModel)
        hidesBottomBarWhenPushed = true
        WebBridgeLogger.shared.info("🔧 WebBrowserViewController init")
    }

    /// 便捷初始化 - 支持加载 URL
    convenience init(url: URL) {
        self.init(viewModel: WebBrowserViewModel(url: url))
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
        view.backgroundColor = ThemeTokens.Color.background

        configureNavigationBar()

        view.addSubview(progressView)
        view.addSubview(webView)

        setupConstraints()
        setupActions()
        setupGestures()

        backButton.isHidden = true
        closeButton.isHidden = false

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("BarkStatusBarVisibilityChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let hidden = notification.userInfo?["hidden"] as? Bool {
                self?.setStatusBarHidden(hidden)
            }
        }

        NotificationCenter.default.addObserver(
            forName: ManifestCacheManager.cacheHitNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let source = notification.userInfo?["source"] as? String ?? "MANIFEST"
            self?.updateCacheStatus(source: source)
        }
    }



    // MARK: - Lifecycle

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if let tabBarController = self.tabBarController {
            tabBarController.tabBar.isHidden = true
            tabBarController.view.setNeedsLayout()
            tabBarController.view.layoutIfNeeded()
            print("✅ [Browser] TabBar auto-hidden on webview entry")
        }
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreUIState()
    }

    /// 还原系统 NavigationBar
    private func restoreUIState() {
        print("🔄 [Browser] Restoring UI state...")

        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        UIViewController.attemptRotationToDeviceOrientation()

        if let tabBarController = self.tabBarController {
            tabBarController.tabBar.isHidden = false
            tabBarController.view.setNeedsLayout()
            tabBarController.view.layoutIfNeeded()
            print("✅ [Browser] TabBar restored")
        }

        if let navigationController = self.navigationController {
            navigationController.navigationBar.isHidden = false
            navigationController.setNavigationBarHidden(false, animated: false)
            print("✅ [Browser] NavigationBar restored")
        }

        view.backgroundColor = ThemeTokens.Color.background
        hideNavBar = false

        print("✅ [Browser] UI state fully restored")
    }

    // MARK: - URL Loading

    /// 加载 URL 并检查参数
    private func loadURL(_ url: URL, checkParams: Bool = true) {
        currentURL = url

        if checkParams {
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
    func checkURLParameters(_ url: URL) {
        print("🔍 [WebBrowserVC] checkURLParameters called: \(url.absoluteString)")

        updateCacheStatus(source: "LIVE")

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            print("⚠️ [WebBrowserVC] No query items found - resetting UI state")
            resetUIState()
            return
        }

        print("✅ [WebBrowserVC] Found \(queryItems.count) query items")

        var shouldHideNavBar = false
        var shouldHideStatusBar = false
        var targetOrientation: UIInterfaceOrientation?

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
                print("⚠️ [WebBrowserVC] hidetabbar parameter ignored (TabBar auto-hidden)")
            case "mode":
                if let value = item.value, value.lowercased() == "immersive" {
                    print("✅ [WebBrowserVC] Activating immersive mode (mode=immersive)")
                    shouldHideNavBar = true
                    shouldHideStatusBar = true
                }
            case "orientation":
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

        setNavigationBarHidden(false)
        setStatusBarHidden(false)
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

        tabBarController.tabBar.isHidden = hidden

        tabBarController.view.setNeedsLayout()
        tabBarController.view.layoutIfNeeded()

        print("🎛️ [Browser] TabBar isHidden: \(tabBarController.tabBar.isHidden)")
        print("🎛️ [Browser] TabBar frame: \(tabBarController.tabBar.frame)")
        print("🎛️ [Browser] ViewController frame: \(self.view.frame)")
    }

    /// 设置导航栏隐藏状态
    func setNavigationBarHidden(_ hidden: Bool) {
        hideNavBar = hidden

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.navigationController?.navigationBar.isHidden = hidden
            self.navigationController?.setNavigationBarHidden(hidden, animated: false)

            if !hidden {
                let canGoBack = self.webView.canGoBack
                if canGoBack {
                    if let backBtn = self.backBarButton, let closeBtn = self.closeBarButton {
                        self.navigationItem.leftBarButtonItems = [backBtn, closeBtn]
                    }
                } else {
                    if let closeBtn = self.closeBarButton {
                        self.navigationItem.leftBarButtonItems = [closeBtn]
                    }
                }
            }

            self.webView.snp.remakeConstraints { make in
                make.left.right.equalToSuperview()

                if hidden {
                    make.top.equalTo(self.view.snp.top)
                    make.bottom.equalTo(self.view.snp.bottom)
                } else {
                    make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top)
                    make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottom)
                }
            }

            self.webView.scrollView.contentInsetAdjustmentBehavior = .never

            if hidden {
                self.view.backgroundColor = .black
                self.webView.backgroundColor = .clear
                self.webView.scrollView.backgroundColor = .clear
            } else {
                self.view.backgroundColor = ThemeTokens.Color.background
                self.webView.backgroundColor = .clear
                self.webView.scrollView.backgroundColor = .clear
            }

            self.view.layoutIfNeeded()

            print("🎛️ [Browser] System NavigationBar: \(hidden ? "隐藏" : "显示")")
        }
    }

    /// 设置状态栏隐藏状态
    func setStatusBarHidden(_ hidden: Bool) {
        isStatusBarHidden = hidden
        setNeedsStatusBarAppearanceUpdate()
        print("📱 [Browser] 状态栏: \(hidden ? "隐藏" : "显示")")
    }

    func dismissOrPop() {
        if let navigationController = navigationController, navigationController.viewControllers.count > 1 {
            navigationController.popViewController(animated: true)
        } else if presentingViewController != nil {
            dismiss(animated: true)
        } else if let tabBarController = tabBarController {
            tabBarController.selectedIndex = 0
        }
    }

    // MARK: - Bind ViewModel

    public override func bindViewModel() {
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

        output.title
            .drive(onNext: { [weak self] title in
                if title == "localhost" {
                    self?.titleLabel.text = ""
                } else {
                    self?.titleLabel.text = title ?? NSLocalizedString("Browser", comment: "")
                }
            })
            .disposed(by: rx)

        output.canGoBack
            .drive(onNext: { [weak self] canGoBack in
                guard let self = self else { return }

                if canGoBack {
                    self.backBarButton?.isEnabled = true
                    self.backBarButton?.tintColor = ThemeTokens.Color.text
                } else {
                    self.backBarButton?.isEnabled = false
                    self.backBarButton?.tintColor = .clear
                }

                if self.hideNavBar == false {
                    if canGoBack {
                        if let backBtn = self.backBarButton, let closeBtn = self.closeBarButton {
                            self.navigationItem.leftBarButtonItems = [backBtn, closeBtn]
                        }
                    } else {
                        if let closeBtn = self.closeBarButton {
                            self.navigationItem.leftBarButtonItems = [closeBtn]
                        }
                    }
                }
            })
            .disposed(by: rx)

        output.estimatedProgress
            .drive(onNext: { [weak self] progress in
                self?.progressView.setProgress(Float(progress), animated: true)
                self?.progressView.isHidden = progress >= 1.0
            })
            .disposed(by: rx)

        output.showMenu
            .drive(onNext: { [weak self] in
                self?.showMenu()
            })
            .disposed(by: rx)

        output.url
            .drive(onNext: { [weak self] url in
                self?.currentURL = url
            })
            .disposed(by: rx)

        setupUserAgent()
    }

    /// 设置自定义 User-Agent，包含版本号、屏幕尺寸和倍率
    private func setupUserAgent() {
        webView.evaluateJavaScript("navigator.userAgent") { [weak self] (result, _) in
            guard let self = self, let baseUA = result as? String else { return }

            let info = Bundle.main.infoDictionary
            let appVersion = info?["CFBundleShortVersionString"] as? String ?? "1.0.0"
            let buildNumber = info?["CFBundleVersion"] as? String ?? "1"

            let screenSize = UIScreen.main.bounds.size
            let screenScale = UIScreen.main.scale

            let customUA = "\(baseUA) WebBridgeKit/\(appVersion) (\(buildNumber); Screen/\(Int(screenSize.width))x\(Int(screenSize.height)); Ratio/\(screenScale))"

            self.webView.customUserAgent = customUA
            print("📱 [WebBrowserVC] Custom UA configured: \(customUA)")
        }
    }

    // MARK: - Deinit

    deinit {
        webView.stopLoading()

        for handlerName in registeredHandlerNames {
            webView.configuration.userContentController.removeScriptMessageHandler(forName: handlerName)
        }
        registeredHandlerNames.removeAll()

        webView.navigationDelegate = nil
        webView.uiDelegate = nil

        _ = rx

        webView.removeFromSuperview()

        isViewModelBinded = false

        print("🧹 [WebBrowserVC] Cleaned up with proper memory management")
    }
}
