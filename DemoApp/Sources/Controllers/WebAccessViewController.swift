//
//  WebAccessViewController.swift
//  DemoApp
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

        setupUI()
        setupGestures()

        // MARK: - Accessibility Identifiers
        view.accessibilityIdentifier = "WebAccessViewController"
        webView.accessibilityIdentifier = "webAccess.webView"
        urlInputView.accessibilityIdentifier = "webAccess.urlInputView"
        cacheCountButton.accessibilityIdentifier = "webAccess.cacheCountButton"
    }

    // MARK: - Setup UI

    private func setupUI() {
        // URL 输入工具栏
        view.addSubview(urlInputView)

        urlInputView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.height.equalTo(52)
        }

        // WebView
        view.addSubview(webView)

        webView.snp.makeConstraints { make in
            make.top.equalTo(urlInputView.snp.bottom)
            make.left.right.equalToSuperview()
            make.bottom.equalTo(statusBarView.snp.top)
        }

        // 下拉刷新
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        webView.scrollView.refreshControl = refreshControl

        // 底部状态栏
        view.addSubview(statusBarView)
        statusBarView.addSubview(cacheCountButton)
        statusBarView.addSubview(separatorView)

        statusBarView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
            make.height.equalTo(44)
        }

        cacheCountButton.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        separatorView.snp.makeConstraints { make in
            make.left.right.top.equalToSuperview()
            make.height.equalTo(0.5)
        }

        // Loading View
        view.addSubview(loadingView)

        loadingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func setupGestures() {
        // URL 输入回调
        urlInputView.onLoadURL = { [weak self] url in
            self?.loadURL(url)
        }

        // 缓存按钮回调
        urlInputView.onCacheTap = {
            // 触发缓存操作
            // 通过 RxSwift 处理
        }

        // 缓存模式切换回调
        urlInputView.onCacheModeChange = { isEnabled in
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

    // MARK: - Private Methods

    private func loadURL(_ url: URL) {
        currentURL = url
        webView.load(URLRequest(url: url))
    }

    private func loadWebView(url: URL) {
        // 检查是否有离线缓存
        if let cachedHistory = WebPageHistoryManager.shared.findHistory(url: url),
           cachedHistory.isCached {
            // 使用离线缓存加载
            let cacheURL = URL(string: "bark-cache://\(cachedHistory.id)/index.html")!
            webView.load(URLRequest(url: cacheURL))
        } else {
            // 加载在线版本
            webView.load(URLRequest(url: url))
        }
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
        // 通知 ViewModel 页面开始加载
        viewModel.notifyPageDidStartLoading()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // 更新历史记录
        if let url = webView.url {
            WebPageHistoryManager.shared.addOrUpdateHistory(url: url, title: webView.title)
            viewModel.refreshCacheStatus()
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
