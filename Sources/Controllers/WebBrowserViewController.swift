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
class WebBrowserViewController: BaseViewController<WebBrowserViewModel> {

    // MARK: - UI Components

    /// 状态栏背景视图 - 填充刘海区域
    private let statusBarBackground: UIView = {
        let view = UIView()
        view.backgroundColor = WKColor.background.primary
        return view
    }()

    private lazy var webView: WKWebView = {
        return viewModel.getWebView()
    }()

    private let progressView: UIProgressView = {
        let progressView = UIProgressView(progressViewStyle: .default)
        progressView.tintColor = WKColor.grey.base
        progressView.trackTintColor = WKColor.grey.lighten2
        return progressView
    }()

    /// 简化的导航栏 - 只显示标题和关闭/后退按钮
    private let navigationBar: UIView = {
        let view = UIView()
        view.backgroundColor = WKColor.background.primary
        return view
    }()

    /// 标题标签
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = WKColor.grey.base
        label.textAlignment = .center
        label.numberOfLines = 1
        return label
    }()

    /// 关闭/后退按钮
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let image = UIImage(systemName: "xmark", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = WKColor.grey.base
        return button
    }()

    /// 后退按钮（当有历史时显示）
    private let backButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let image = UIImage(systemName: "chevron.left", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = WKColor.grey.base
        return button
    }()

    /// 更多菜单按钮
    private let menuButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        let image = UIImage(systemName: "ellipsis.circle", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = WKColor.grey.base
        return button
    }()

    /// 手势 - 点击底部区域关闭（当导航栏隐藏时）
    private var tapGesture: UITapGestureRecognizer?

    // MARK: - Properties

    /// 是否隐藏导航栏
    private var hideNavBar = false

    /// 当前 URL
    private var currentURL: URL?

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

    override func makeUI() {
        view.backgroundColor = WKColor.background.primary

        // 添加状态栏背景（填充刘海区域）
        view.addSubview(statusBarBackground)
        view.addSubview(navigationBar)
        navigationBar.addSubview(titleLabel)
        navigationBar.addSubview(closeButton)
        navigationBar.addSubview(backButton)
        navigationBar.addSubview(menuButton)

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

        // 加载初始内容
        if let initialURL = viewModel.initialURL {
            loadURL(initialURL, checkParams: true)
        } else {
            loadWelcomePage()
        }
    }

    private func setupConstraints() {
        // 状态栏背景 - 从屏幕顶部到安全区域顶部
        statusBarBackground.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.top)
        }

        // 导航栏 - 从安全区域顶部开始
        navigationBar.snp.makeConstraints { make in
            make.top.left.right.equalTo(view.safeAreaLayoutGuide)
            make.height.equalTo(44)
        }

        webView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.left.right.bottom.equalToSuperview()
        }

        closeButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(32)
        }

        backButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(32)
        }

        menuButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(32)
        }

        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
            make.left.greaterThanOrEqualTo(closeButton.snp.right).offset(8)
            make.right.lessThanOrEqualTo(menuButton.snp.left).offset(-8)
        }

        progressView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.left.right.equalToSuperview()
            make.height.equalTo(2)
        }
    }

    private func setupActions() {
        // 关闭按钮 - 直接关闭浏览器
        closeButton.rx.tap
            .asDriver()
            .drive(onNext: { [weak self] in
                self?.dismissOrPop()
            })
            .disposed(by: rx)
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

    // MARK: - URL Loading

    /// 加载 URL 并检查参数
    private func loadURL(_ url: URL, checkParams: Bool = true) {
        currentURL = url

        if checkParams {
            // 检查 URL 参数
            checkURLParameters(url)
        }

        let request = URLRequest(url: url)
        webView.load(request)

        print("🌐 [Browser] 加载 URL: \(url.absoluteString)")
    }

    /// 检查 URL 参数
    private func checkURLParameters(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return
        }

        for item in queryItems {
            switch item.name.lowercased() {
            case "hidenavbar":
                if let value = item.value, value == "1" || value.lowercased() == "true" {
                    setNavigationBarHidden(true)
                }
            default:
                break
            }
        }
    }

    /// 设置导航栏隐藏状态
    private func setNavigationBarHidden(_ hidden: Bool) {
        hideNavBar = hidden

        UIView.animate(withDuration: 0.3) {
            self.navigationBar.alpha = hidden ? 0 : 1
            self.navigationBar.isHidden = hidden
            self.statusBarBackground.alpha = hidden ? 0 : 1
            self.statusBarBackground.isHidden = hidden
        }

        // 更新 WebView 约束
        webView.snp.updateConstraints { make in
            if hidden {
                make.top.equalToSuperview()  // 紧贴屏幕顶部
            } else {
                make.top.equalTo(self.navigationBar.snp.bottom)
            }
        }

        print("🎛️ [Browser] 导航栏: \(hidden ? "隐藏" : "显示")")
    }

    private func dismissOrPop() {
        // 检查是否在 TabBarController 中
        if let tabBarController = tabBarController {
            // 在 TabBar 中，切换到第一个 Tab
            tabBarController.selectedIndex = 0
        } else if let navigationController = navigationController, navigationController.viewControllers.count > 1 {
            // 在导航栈中，弹出当前页面
            navigationController.popViewController(animated: true)
        } else {
            // 被 present 出来的，dismiss
            dismiss(animated: true)
        }
    }

    // MARK: - Bind ViewModel

    override func bindViewModel() {
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
                self?.titleLabel.text = title ?? NSLocalizedString("Browser", comment: "")
            })
            .disposed(by: rx)

        // 绑定后退状态 - 控制关闭/后退按钮显示
        output.canGoBack
            .drive(onNext: { [weak self] canGoBack in
                // 当导航栏隐藏时，不显示任何按钮
                guard self?.hideNavBar == false else { return }

                if canGoBack {
                    self?.backButton.isHidden = false
                    self?.closeButton.isHidden = true
                } else {
                    self?.backButton.isHidden = true
                    self?.closeButton.isHidden = false
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
            "🎛️ 导航栏": hideNavBar ? "隐藏" : "显示"
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
}

// MARK: - UIGestureRecognizerDelegate

extension WebBrowserViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // 只在导航栏隐藏时响应手势
        return hideNavBar
    }
}

// MARK: - WKNavigationDelegate - Auto-Capture by Rules

extension WebBrowserViewController: WKNavigationDelegate {

    /// 页面加载完成 - 检查是否需要自动缓存页面
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url else { return }

        print("📄 ========================================")
        print("📄 页面加载完成")
        print("- URL: \(url.absoluteString)")
        print("📄 ========================================")
        WebBridgeLogger.shared.info("📄 Page loaded: \(url.absoluteString)")

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
}
