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
        view.backgroundColor = ThemeTokens.Color.surface
        return view
    }()

    private let cacheCountButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(L10n.tr("web_access.cache_count_zero"), for: .normal)
        button.titleLabel?.font = ThemeTokens.Typography.footnote
        button.setTitleColor(ThemeTokens.Color.primary, for: .normal)
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
            button.configuration = config
        } else {
            button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        }
        return button
    }()

    private let separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeTokens.Color.separator
        return view
    }()

    private let loadingView = LoadingView()

    private var offlineStateView: ThemeEmptyState?

    // MARK: - Properties

    private var currentURL: URL?
    private var isShowingOfflineState = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = L10n.tr("web_access.title")
        view.backgroundColor = ThemeTokens.Color.background

        setupUI()
        setupGestures()
        setupNetworkMonitoring()

        view.accessibilityIdentifier = "WebAccessViewController"
        webView.accessibilityIdentifier = "webAccess.webView"
        urlInputView.accessibilityIdentifier = "webAccess.urlInputView"
        cacheCountButton.accessibilityIdentifier = "webAccess.cacheCountButton"
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        NetworkMonitor.shared.startMonitoring()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NetworkMonitor.shared.stopMonitoring()
    }

    private func setupNetworkMonitoring() {
        // 监听网络状态变化
        NetworkMonitor.shared.addStatusChangeCallback { [weak self] isConnected, _ in
            guard let self = self else { return }

            DispatchQueue.main.async {
                if !isConnected && self.currentURL != nil {
                    self.showOfflineState()
                } else if isConnected && self.isShowingOfflineState {
                    self.hideOfflineState()
                }
            }
        }

        // 初始检查网络状态
        if !NetworkMonitor.shared.isConnected {
        }
    }

    // MARK: - Setup UI

    private func setupUI() {
        view.addSubview(urlInputView)
        view.addSubview(webView)
        view.addSubview(statusBarView)
        view.addSubview(loadingView)
        statusBarView.addSubview(cacheCountButton)
        statusBarView.addSubview(separatorView)

        urlInputView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.height.greaterThanOrEqualTo(52)
        }

        statusBarView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
            make.height.greaterThanOrEqualTo(44)
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
            make.height.greaterThanOrEqualTo(44)
        }

        separatorView.snp.makeConstraints { make in
            make.left.right.top.equalToSuperview()
            make.height.equalTo(0.5)
        }

        let refreshControl = UIRefreshControl()
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
                self?.title = title ?? L10n.tr("web_access.title")
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
                    self?.loadingView.updateProgress(progress, message: L10n.tr("web_access.caching"))
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
                    self?.loadingView.startLoading(message: L10n.tr("web_access.loading"))
                } else {
                    self?.loadingView.stopLoading()
                }
            })
            .disposed(by: rx)

        // 绑定错误消息
        output.errorMessage
            .drive(onNext: { [weak self] message in
                guard let message = message else { return }
                self?.showAlert(title: L10n.tr("common.notice"), message: message)
            })
            .disposed(by: rx)
    }

    // MARK: - Internal Methods

    func loadTargetURL(_ url: URL) {
        currentURL = url

        if UserDefaults.standard.bool(forKey: SettingsPreferenceKeys.rememberLastApp) {
            UserDefaults.standard.set(url.absoluteString, forKey: SettingsPreferenceKeys.lastOpenedURL)
            UserDefaults.standard.synchronize()
        }

        checkURLParameters(url)

        webView.load(URLRequest(url: url))
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
            return
        }

        DispatchQueue.main.async { [weak tabBarController] in
            tabBarController?.tabBar.isHidden = hidden
        }
    }

    /// Hide/show navigation bar
    private func setNavigationBarHidden(_ hidden: Bool) {
        // Use non-animated for UI testing stability
        navigationController?.setNavigationBarHidden(hidden, animated: false)
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
    }

    /// Hide/show status bar
    private func setStatusBarHidden(_ hidden: Bool) {
        isStatusBarHidden = hidden
        setNeedsStatusBarAppearanceUpdate()
    }

    // MARK: - Status Bar Appearance

    public override var prefersStatusBarHidden: Bool {
        return isStatusBarHidden
    }

    private var isStatusBarHidden: Bool = false

    private func loadWebView(url: URL) {
        webView.load(URLRequest(url: url))
    }

    private func openCacheResources() {
        guard let history = viewModel.getCurrentHistory() else {
            showAlert(title: L10n.tr("common.notice"), message: L10n.tr("web_access.not_cached"))
            return
        }

        guard let url = URL(string: history.url) else {
            showAlert(title: L10n.tr("common.notice"), message: L10n.tr("web_access.invalid_url"))
            return
        }

        let resourceVC = CacheResourceViewController(url: url)
        navigationController?.pushViewController(resourceVC, animated: true)
    }

    @objc private func handleRefresh() {
        guard currentURL != nil else {
            webView.scrollView.refreshControl?.endRefreshing()
            return
        }

        webView.reload()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.webView.scrollView.refreshControl?.endRefreshing()
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.tr("common.confirm"), style: .default))
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
        viewModel.notifyPageDidStartLoading()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let url = webView.url {
            Task {
                try? await WebPageHistoryManager.shared.addOrUpdateHistory(url: url, title: webView.title)
            }
            viewModel.refreshCacheStatus()

            if UserDefaults.standard.bool(forKey: SettingsPreferenceKeys.rememberLastApp) {
                UserDefaults.standard.set(url.absoluteString, forKey: SettingsPreferenceKeys.lastOpenedURL)
                UserDefaults.standard.synchronize()
            }
        }

        viewModel.notifyPageDidFinishLoading()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if isNetworkRelatedError(error) || !NetworkMonitor.shared.isConnected {
            showOfflineState()
        } else {
            // 非 network 错误，显示标准错误提示
            let alert = UIAlertController(
                title: L10n.tr("web_access.load_failed"),
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: L10n.tr("web_access.retry"), style: .default) { [weak self] _ in
                self?.webView.reload()
            })
            alert.addAction(UIAlertAction(title: L10n.tr("common.cancel"), style: .cancel))
            present(alert, animated: true)
        }
    }

    private func showOfflineState() {
        guard !isShowingOfflineState else { return }
        isShowingOfflineState = true

        let emptyState = ThemeEmptyState(frame: .zero)
        emptyState.configure(
            icon: .network,
            title: L10n.tr("web_access.offline_title"),
            description: L10n.tr("web_access.offline_description")
        )

        // 添加重试按钮
        let retryButton = createRetryButton()
        emptyState.addSubview(retryButton)
        retryButton.snp.makeConstraints { make in
            make.top.equalTo(emptyState.descriptionLabel.snp.bottom).offset(24)
            make.centerX.equalToSuperview()
            make.width.equalTo(120)
            make.height.equalTo(44)
        }

        // 隐藏 WebView，显示离线状态
        webView.isHidden = true
        offlineStateView?.removeFromSuperview()

        view.addSubview(emptyState)
        emptyState.snp.makeConstraints { make in
            make.centerX.centerY.equalToSuperview()
            make.width.lessThanOrEqualToSuperview().offset(-40)
        }

        offlineStateView = emptyState
    }

    private func hideOfflineState() {
        guard isShowingOfflineState else { return }
        isShowingOfflineState = false

        offlineStateView?.removeFromSuperview()
        offlineStateView = nil

        webView.isHidden = false

        // 重新加载当前 URL
        if let url = currentURL {
            loadWebView(url: url)
        }
    }

    private func createRetryButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(L10n.tr("web_access.retry"), for: .normal)
        button.titleLabel?.font = ThemeTokens.Typography.callout
        button.backgroundColor = ThemeTokens.Color.primary
        button.setTitleColor(ThemeTokens.Color.background, for: .normal)
        button.layer.cornerRadius = ThemeTokens.CornerRadius.md
        button.addTarget(self, action: #selector(handleRetry), for: .touchUpInside)
        return button
    }

    @objc private func handleRetry() {
        if !NetworkMonitor.shared.isConnected {
            let alert = UIAlertController(
                title: L10n.tr("web_access.offline_title"),
                message: L10n.tr("web_access.offline_no_connection"),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: L10n.tr("common.confirm"), style: .default))
            present(alert, animated: true)
            return
        }

        // 检查是否有缓存的页面
        if let url = currentURL {
            Task { @MainActor in
                if let cachedHistory = try? await WebPageHistoryManager.shared.findHistory(url: url),
                   cachedHistory.isCached {
                    let cachedPageVC = CacheResourceViewController(url: url)
                    navigationController?.pushViewController(cachedPageVC, animated: true)
                    hideOfflineState()
                    return
                }

                // 重新加载页面
                hideOfflineState()
            }
        }
    }

    private func isNetworkRelatedError(_ error: Error) -> Bool {
        let errorDescription = error.localizedDescription.lowercased()

        let networkKeywords = [
            "network",
            "connection",
            "offline",
            "internet",
            "timed out",
            "timeout",
            "host",
            "dns",
            "server"
        ]

        return networkKeywords.contains { errorDescription.contains($0) }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // 允许所有导航
        decisionHandler(.allow)
    }
}
