//
//  WebAccessViewController.swift
//  SuperApp
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa
@preconcurrency import WebKit
import WebBridgeKit

/// URL 访问和缓存页面控制器
class WebAccessViewController: BaseViewController<WebAccessViewModel> {

    // MARK: - UI Components

    private lazy var urlInputView: URLInputView = {
        let view = URLInputView()
        return view
    }()

    private lazy var webView: WKWebView = {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.dataDetectorTypes = []

        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = self
        web.scrollView.contentInsetAdjustmentBehavior = .automatic
        return web
    }()

    private let statusBarView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        return view
    }()

    private let cacheCountButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("0 个资源", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        button.setTitleColor(.systemBlue, for: .normal)
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        return button
    }()

    private let separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .separator
        return view
    }()

    private let refreshControl: UIRefreshControl = {
        let refresh = UIRefreshControl()
        return refresh
    }()

    private let loadingView = LoadingView()

    // MARK: - Properties

    private var currentURL: URL?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "网页访问"
        view.backgroundColor = .systemBackground

        // 先添加所有视图（不设置约束）
        view.addSubview(urlInputView)
        view.addSubview(webView)
        view.addSubview(statusBarView)
        view.addSubview(loadingView)
        statusBarView.addSubview(cacheCountButton)
        statusBarView.addSubview(separatorView)

        setupGestures()

        // MARK: - Accessibility Identifiers
        view.accessibilityIdentifier = "WebAccessViewController"
        webView.accessibilityIdentifier = "webAccess.webView"
        urlInputView.accessibilityIdentifier = "webAccess.urlInputView"
        cacheCountButton.accessibilityIdentifier = "webAccess.cacheCountButton"
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // 在 viewWillAppear 中设置约束，此时 view hierarchy 已完全建立
        setupUI()
    }

    // MARK: - Setup UI

    private func setupUI() {
        // 先添加所有视图到视图层次结构
        view.addSubview(urlInputView)
        view.addSubview(webView)
        view.addSubview(statusBarView)
        view.addSubview(loadingView)

        statusBarView.addSubview(cacheCountButton)
        statusBarView.addSubview(separatorView)

        // 然后设置所有约束
        urlInputView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.height.equalTo(52)
        }

        statusBarView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
            make.height.equalTo(44)
        }

        webView.snp.makeConstraints { make in
            make.top.equalTo(urlInputView.snp.bottom)
            make.left.right.equalToSuperview()
            make.bottom.equalTo(statusBarView.snp.top)
        }

        loadingView.snp.makeConstraints { make in
            make.top.equalTo(urlInputView.snp.bottom)
            make.left.right.equalToSuperview()
            make.bottom.equalTo(statusBarView.snp.top)
        }

        cacheCountButton.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        separatorView.snp.makeConstraints { make in
            make.left.right.top.equalToSuperview()
            make.height.equalTo(0.5)
        }

        // 下拉刷新
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        webView.scrollView.refreshControl = refreshControl
    }

    private func setupGestures() {
        // URL 输入回调
        urlInputView.onLoadURL = { [weak self] url in
            self?.loadTargetURL(url)
        }

        // 缓存按钮回调
        urlInputView.onCacheTap = {
            // 触发缓存操作
            // 通过 RxSwift 处理
        }

        // 缓存模式切换回调
        urlInputView.onCacheModeChange = { _ in
            // 触发模式切换
            // 通过 RxSwift 处理
        }

        // 缓存数量点击
        cacheCountButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.openCacheResources()
            })
            .disposed(by: rx)
    }

    // MARK: - Bind ViewModel

    override func bindViewModel() {
        let loadURL = urlInputView.urlDidChange
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .compactMap { URL(string: $0) }
            .asDriver(onErrorJustReturn: URL(string: "about:blank")!)

        let cacheButtonTap = urlInputView.cacheButton.rx.tap.asDriver()
        let cacheModeToggle = urlInputView.cacheSwitch.rx.value.asDriver()
        let cacheCountTap = cacheCountButton.rx.tap.asDriver()

        let input = WebAccessViewModel.Input(
            loadURL: loadURL,
            cacheButtonTap: cacheButtonTap,
            cacheModeToggle: cacheModeToggle,
            cacheCountTap: cacheCountTap
        )

        let output = viewModel.transform(input: input)

        // 绑定标题
        output.title
            .drive(onNext: { [weak self] title in
                self?.title = title ?? "网页访问"
            })
            .disposed(by: rx)

        // 绑定 URL
        output.url
            .drive(onNext: { [weak self] url in
                guard let url = url else { return }
                self?.currentURL = url
                self?.urlInputView.setURL(url)
                self?.loadWebView(url: url)
            })
            .disposed(by: rx)

        // 绑定是否可以缓存
        output.canCache
            .drive(urlInputView.cacheButton.rx.isEnabled)
            .disposed(by: rx)

        // 绑定是否已缓存
        output.isCached
            .drive(onNext: { [weak self] isCached in
                self?.urlInputView.setCached(isCached)
            })
            .disposed(by: rx)

        // 绑定缓存进度
        output.cacheProgress
            .drive(onNext: { [weak self] progress in
                if progress > 0 && progress < 1 {
                    self?.loadingView.updateProgress(progress, message: "缓存中...")
                } else if progress >= 1 {
                    self?.loadingView.stopLoading()
                }
            })
            .disposed(by: rx)

        // 绑定缓存数量
        output.cacheCount
            .drive(cacheCountButton.rx.title())
            .disposed(by: rx)

        // 绑定显示缓存资源
        output.showCacheResources
            .drive(onNext: { [weak self] in
                self?.openCacheResources()
            })
            .disposed(by: rx)

        // 绑定加载状态
        output.loading
            .drive(onNext: { [weak self] loading in
                if loading {
                    self?.loadingView.startLoading(message: "加载中...")
                } else {
                    self?.loadingView.stopLoading()
                }
            })
            .disposed(by: rx)

        // 绑定错误消息
        output.errorMessage
            .drive(onNext: { [weak self] message in
                guard let message = message else { return }
                self?.showAlert(title: "提示", message: message)
            })
            .disposed(by: rx)
    }

    // MARK: - Internal Methods

    func loadTargetURL(_ url: URL) {
        print("🔵 [WebAccessVC] loadURL called: \(url.absoluteString)")
        currentURL = url

        // 保存上次打开的 URL（如果启用了记忆功能）
        if UserDefaults.standard.bool(forKey: "EnableLastAppMemory") {
            UserDefaults.standard.set(url.absoluteString, forKey: "LastOpenedURL")
            UserDefaults.standard.synchronize()
            print("💾 [WebAccessVC] Saved LastOpenedURL: \(url.absoluteString)")
        }

        // 🔥 Check URL parameters for fullscreen mode
        checkURLParameters(url)

        print("🔵 [WebAccessVC] Loading URL in WebView...")
        webView.load(URLRequest(url: url))
        print("🔵 [WebAccessVC] webView.load() called successfully")
    }

    /// Check URL parameters for fullscreen mode
    private func checkURLParameters(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return
        }

        for item in queryItems {
            switch item.name.lowercased() {
            case "hidetabbar":
                if let value = item.value, value == "1" || value.lowercased() == "true" {
                    setTabBarHidden(true)
                }
            case "mode":
                if let value = item.value, value.lowercased() == "immersive" {
                    setTabBarHidden(true)
                    setNavigationBarHidden(true)
                    setStatusBarHidden(true)
                    hideURLInputView(true)
                }
            case "hidenavbar":
                if let value = item.value, value == "1" || value.lowercased() == "true" {
                    setNavigationBarHidden(true)
                    hideURLInputView(true)
                }
            case "hidestatusbar":
                if let value = item.value, value == "1" || value.lowercased() == "true" {
                    setStatusBarHidden(true)
                }
            default:
                break
            }
        }
    }

    /// Hide/show TabBar
    private func setTabBarHidden(_ hidden: Bool) {
        guard let tabBarController = self.tabBarController else {
            print("⚠️ [WebAccessVC] No TabBarController found")
            return
        }

        print("🎛️ [WebAccessVC] setTabBarHidden: \(hidden)")

        // Use DispatchQueue.main to avoid threading issues
        DispatchQueue.main.async { [weak tabBarController] in
            tabBarController?.tabBar.isHidden = hidden
        }
    }

    /// Hide/show navigation bar
    private func setNavigationBarHidden(_ hidden: Bool) {
        // Use non-animated for UI testing stability
        navigationController?.setNavigationBarHidden(hidden, animated: false)
        print("🎛️ [WebAccessVC] NavigationBar hidden: \(hidden)")
    }

    /// Hide/show URL input view and status bar
    private func hideURLInputView(_ hidden: Bool) {
        // Use immediate change without animation for stability
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.urlInputView.alpha = hidden ? 0 : 1
            self.urlInputView.isHidden = hidden
            self.statusBarView.alpha = hidden ? 0 : 1
            self.statusBarView.isHidden = hidden
        }
        print("🎛️ [WebAccessVC] URLInputView and StatusBarView hidden: \(hidden)")
    }

    /// Hide/show status bar
    private func setStatusBarHidden(_ hidden: Bool) {
        isStatusBarHidden = hidden
        setNeedsStatusBarAppearanceUpdate()
        print("🎛️ [WebAccessVC] StatusBar hidden: \(hidden)")
    }

    // MARK: - Status Bar Appearance

    public override var prefersStatusBarHidden: Bool {
        return isStatusBarHidden
    }

    private var isStatusBarHidden: Bool = false

    private func loadWebView(url: URL) {
        print("🟢 [WebAccessVC] loadWebView called: \(url.absoluteString)")

        // ============================================================
        // NEW APPROACH: System URLCache
        // 无需 HTML 修改或 JS 注入
        // WKWebView 会自动使用 URLCache.shared 处理缓存
        // ============================================================
        print("🟢 [WebAccessVC] Loading with System URLCache")
        webView.load(URLRequest(url: url))

        // ============================================================
        // OLD APPROACH (DISABLED): bark-cache:// URL Scheme
        // This approach required HTML modification
        // ============================================================
        // if let cachedHistory = WebPageHistoryManager.shared.findHistory(url: url),
        //    cachedHistory.isCached {
        //     let cacheURL = URL(string: "bark-cache://\(cachedHistory.id)/index.html")!
        //     webView.load(URLRequest(url: cacheURL))
        // } else {
        //     webView.load(URLRequest(url: url))
        // }

        print("🟢 [WebAccessVC] WebView load initiated")
    }

    private func openCacheResources() {
        guard let history = viewModel.getCurrentHistory() else {
            showAlert(title: "提示", message: "该页面尚未缓存")
            return
        }

        guard let url = URL(string: history.url) else {
            showAlert(title: "提示", message: "无效的页面地址")
            return
        }

        let resourceVC = CacheResourceViewController(url: url)
        navigationController?.pushViewController(resourceVC, animated: true)
    }

    @objc private func handleRefresh() {
        guard currentURL != nil else {
            refreshControl.endRefreshing()
            return
        }

        // 重新加载页面
        webView.reload()

        // 延迟结束刷新
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.refreshControl.endRefreshing()
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Public Methods

    func loadPage(url: URL) {
        currentURL = url
        urlInputView.setURL(url)
        loadWebView(url: url)
    }
}

// MARK: - WKNavigationDelegate

extension WebAccessViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("⚠️ [WebAccessVC] WebView didStartProvisionalNavigation")
        // 通知 ViewModel 页面开始加载
        viewModel.notifyPageDidStartLoading()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("✅ [WebAccessVC] WebView didFinish navigation - URL: \(webView.url?.absoluteString ?? "nil")")
        // 更新历史记录
        if let url = webView.url {
            WebPageHistoryManager.shared.addOrUpdateHistory(url: url, title: webView.title)
            viewModel.refreshCacheStatus()

            // 记录最后打开的 URL
            if UserDefaults.standard.bool(forKey: "EnableLastAppMemory") {
                UserDefaults.standard.set(url.absoluteString, forKey: "LastOpenedURL")
                UserDefaults.standard.synchronize()
                print("💾 [WebAccess] 记忆上次应用 URL: \(url.absoluteString)")
            }
        }

        // 通知 ViewModel 页面加载完成
        viewModel.notifyPageDidFinishLoading()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let alert = UIAlertController(
            title: "加载失败",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "重试", style: .default) { [weak self] _ in
            self?.webView.reload()
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // 允许所有导航
        decisionHandler(.allow)
    }
}
