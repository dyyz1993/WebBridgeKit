//
//  ManifestCacheTestViewController.swift
//  DemoApp
//
//  Created on 2025-02-02.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit
import WebKit
import WebBridgeKit

/// Manifest 缓存测试页面
/// 功能：
/// 1. URL 输入和验证
/// 2. 测试模式选择（持久化/懒加载）
/// 3. Manifest 下载和解析
/// 4. 资源缓存测试
/// 5. WebView 加载展示
/// 6. 日志输出和统计信息
class ManifestCacheTestViewController: UIViewController {

    // MARK: - UI Components

    private let scrollView = UIScrollView()

    private let contentView = UIView()

    /// URL 输入容器
    private let urlInputContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 12
        return view
    }()

    private let urlLabel: UILabel = {
        let label = UILabel()
        label.text = "测试 URL"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        return label
    }()

    private let urlTextField: UITextField = {
        let field = UITextField()
        field.placeholder = "输入包含 manifest.json 的 URL"
        field.font = .systemFont(ofSize: 16)
        field.borderStyle = .none
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.keyboardType = .URL
        field.accessibilityIdentifier = "manifest_test.url_field"
        return field
    }()

    /// 快速选择测试 URL
    private let urlPresetSegment: UISegmentedControl = {
        let segment = UISegmentedControl(items: ["Manifest测试", "百度"])
        segment.selectedSegmentIndex = -1  // 默认不选中
        return segment
    }()

    /// 测试模式选择
    private let modeLabel: UILabel = {
        let label = UILabel()
        label.text = "缓存模式"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        return label
    }()

    private let modeSegment: UISegmentedControl = {
        let segment = UISegmentedControl(items: ["懒加载", "持久化"])
        segment.selectedSegmentIndex = 0  // DEBUG: 默认懒加载模式
        segment.accessibilityIdentifier = "manifest_test.mode_segment"
        return segment
    }()

    /// 操作按钮
    private let startButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("开始测试", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        button.accessibilityIdentifier = "manifest_test.start_button"
        return button
    }()

    private let clearCacheButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("清除缓存", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.backgroundColor = .secondarySystemBackground
        button.setTitleColor(.systemRed, for: .normal)
        button.layer.cornerRadius = 8
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        button.accessibilityIdentifier = "manifest_test.clear_cache_button"
        return button
    }()

    /// 统计信息
    private let statsContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 12
        return view
    }()

    private let statsTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "缓存统计"
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .label
        return label
    }()

    private let statsLabel: UILabel = {
        let label = UILabel()
        label.text = "暂无数据"
        label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    /// 日志输出
    private let logContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 12
        return view
    }()

    private let logTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "操作日志"
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .label
        return label
    }()

    private let logTextView: UITextView = {
        let textView = UITextView()
        textView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.textColor = .label
        textView.backgroundColor = .tertiarySystemBackground
        textView.layer.cornerRadius = 8
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.isEditable = false
        textView.accessibilityIdentifier = "manifest_test.log_view"
        return textView
    }()

    private let copyLogButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("📋 复制", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
        button.setTitleColor(.systemBlue, for: .normal)
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        button.accessibilityIdentifier = "manifest_test.copy_log_button"
        return button
    }()

    private let clearLogButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("🗑️ 清空", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
        button.setTitleColor(.systemRed, for: .normal)
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        button.accessibilityIdentifier = "manifest_test.clear_log_button"
        return button
    }()

    // ✅ WebView 已删除 - 底部 WebView 不再需要，因为测试时会使用全屏展示
    // 原因：底部 WebView 会导致视图层级复杂，可能出现覆盖问题
    // 解决方案：测试时直接在全屏模式下创建新的 WebView 实例

    // MARK: - Properties

    private var isTestRunning = false
    private let manifestCacheManager = ManifestCacheManager.shared
    private var currentCacheID: String?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Manifest 缓存测试"
        view.backgroundColor = .systemGroupedBackground

        setupUI()
        setupActions()

        updateStats()

        // 设置默认 URL - 指向本地测试服务器（使用实际 IP）
        #if DEBUG
        urlTextField.text = "http://192.168.0.4:8080/manifest_cache_demo/"
        #else
        urlTextField.text = "https://example.com/test-page"
        #endif

        addLog("📱 Manifest 缓存测试页面已加载")
        addLog("🔧 支持两种模式：")
        addLog("   - 懒加载：立即加载 HTML，后台下载资源")
        addLog("   - 持久化：等待所有资源下载完成后加载")

        // 监听 LazyManifestLoader 的资源加载日志通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleResourceLogNotification(_:)),
            name: LazyManifestLoader.resourceLogNotification,
            object: nil
        )

        // 注释掉自动测试，让用户手动点击"开始测试"按钮
        // #if DEBUG
        // DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
        //     self?.addLog("🤖 DEBUG 模式：自动开始测试...")
        //     // 使用持久化模式
        //     self?.modeSegment.selectedSegmentIndex = 0  // 懒加载模式
        //     self?.startTest()
        // }
        // #endif
    }

    deinit {
        // 移除通知监听器
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // ✅ WebView 已删除，不再需要处理覆盖问题
    }

    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }

        // contentView 的约束在最后设置，因为需要引用 logContainer

        // URL 输入
        contentView.addSubview(urlInputContainer)
        urlInputContainer.addSubview(urlLabel)
        urlInputContainer.addSubview(urlTextField)
        urlInputContainer.addSubview(urlPresetSegment)

        urlInputContainer.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
        }

        urlLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
        }

        urlTextField.snp.makeConstraints { make in
            make.top.equalTo(urlLabel.snp.bottom).offset(8)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
        }

        // 快速选择 URL（放在 urlInputContainer 内部）
        urlPresetSegment.snp.makeConstraints { make in
            make.top.equalTo(urlTextField.snp.bottom).offset(8)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.bottom.equalToSuperview().offset(-12)
        }

        // 模式选择
        contentView.addSubview(modeLabel)
        contentView.addSubview(modeSegment)

        modeLabel.snp.makeConstraints { make in
            make.top.equalTo(urlInputContainer.snp.bottom).offset(20)
            make.left.equalToSuperview().offset(20)
        }

        modeSegment.snp.makeConstraints { make in
            make.top.equalTo(modeLabel.snp.bottom).offset(8)
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
            make.height.equalTo(32)
        }

        // 操作按钮
        let buttonStack = UIStackView(arrangedSubviews: [startButton, clearCacheButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 12
        buttonStack.distribution = .fillEqually
        // ✅ 关键修复：StackView 必须允许触摸事件传递到子视图
        // 删除 isUserInteractionEnabled = true，让 StackView 不拦截触摸事件
        // 这样内部的按钮才能接收到 .touchUpInside 事件

        contentView.addSubview(buttonStack)
        buttonStack.snp.makeConstraints { make in
            make.top.equalTo(modeSegment.snp.bottom).offset(20)
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
            make.height.equalTo(48)
        }

        // 统计信息
        contentView.addSubview(statsContainer)
        statsContainer.addSubview(statsTitleLabel)
        statsContainer.addSubview(statsLabel)

        statsContainer.snp.makeConstraints { make in
            make.top.equalTo(buttonStack.snp.bottom).offset(20)
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
        }

        statsTitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
        }

        statsLabel.snp.makeConstraints { make in
            make.top.equalTo(statsTitleLabel.snp.bottom).offset(8)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.bottom.equalToSuperview().offset(-12)
        }

        // 日志输出
        contentView.addSubview(logContainer)
        logContainer.addSubview(logTitleLabel)
        logContainer.addSubview(copyLogButton)
        logContainer.addSubview(clearLogButton)
        logContainer.addSubview(logTextView)

        logContainer.snp.makeConstraints { make in
            make.top.equalTo(statsContainer.snp.bottom).offset(20)
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
            make.height.equalTo(200)
        }

        logTitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.left.equalToSuperview().offset(16)
        }

        let logButtonStack = UIStackView(arrangedSubviews: [copyLogButton, clearLogButton])
        logButtonStack.axis = .horizontal
        logButtonStack.spacing = 8
        logButtonStack.distribution = .fillEqually
        // ✅ 关键修复：StackView 必须允许触摸事件传递到子视图
        // 删除 isUserInteractionEnabled = true，让 StackView 不拦截触摸事件

        logContainer.addSubview(logButtonStack)
        logButtonStack.snp.makeConstraints { make in
            // ✅ 修复: 让 logButtonStack 和 logTitleLabel 顶部对齐
            make.top.equalTo(logTitleLabel)
            make.right.equalToSuperview().offset(-16)
            make.height.equalTo(28)
        }

        copyLogButton.snp.makeConstraints { make in
            make.width.equalTo(70)
        }

        clearLogButton.snp.makeConstraints { make in
            make.width.equalTo(70)
        }

        logTextView.snp.makeConstraints { make in
            // ✅ 修复: logTextView 的顶部应该相对于 logButtonStack.bottom，而不是 logTitleLabel.bottom
            make.top.equalTo(logButtonStack.snp.bottom).offset(8)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.bottom.equalToSuperview().offset(-12)
        }

        // ✅ 所有视图都已添加，现在设置 contentView 的约束
        contentView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.width.equalToSuperview()
            make.bottom.equalTo(logContainer.snp.bottom).offset(20)
        }
    }

    private func setupActions() {
        startButton.addTarget(self, action: #selector(startTest), for: .touchUpInside)
        clearCacheButton.addTarget(self, action: #selector(clearCache), for: .touchUpInside)
        clearLogButton.addTarget(self, action: #selector(clearLog), for: .touchUpInside)
        copyLogButton.addTarget(self, action: #selector(copyLog), for: .touchUpInside)
        urlPresetSegment.addTarget(self, action: #selector(urlPresetChanged), for: .valueChanged)
    }

    // MARK: - Actions

    @objc private func urlPresetChanged() {
        switch urlPresetSegment.selectedSegmentIndex {
        case 0:
            // Manifest 测试
            urlTextField.text = "http://192.168.0.4:8080/manifest_cache_demo/"
            addLog("🔄 已选择: Manifest 测试 URL")
        case 1:
            // 百度
            urlTextField.text = "https://www.baidu.com"
            addLog("🔄 已选择: 百度（无 manifest，将回退到普通加载）")
        default:
            break
        }
    }

    @objc private func startTest() {
        guard !isTestRunning else {
            showAlert(title: "提示", message: "测试正在进行中，请稍候")
            return
        }

        guard let urlText = urlTextField.text, !urlText.isEmpty else {
            showAlert(title: "错误", message: "请输入有效的 URL")
            return
        }

        guard let url = URL(string: urlText) else {
            showAlert(title: "错误", message: "URL 格式不正确")
            return
        }

        isTestRunning = true
        startButton.isEnabled = false
        startButton.setTitle("测试中...", for: .normal)

        addLog("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        addLog("🚀 开始测试")
        addLog("📍 URL: \(url.absoluteString)")

        // ✅ FIX: 使用 smartLoad 自动根据 manifest.persistent 选择模式
        // 不管用户选择什么，都以 manifest.json 的 persistent 字段为准
        let userSelectedMode = modeSegment.selectedSegmentIndex == 1 ? "持久化" : "懒加载"
        addLog("📦 用户选择: \(userSelectedMode)")
        addLog("📋 实际模式将根据 manifest.json 的 persistent 字段自动选择")

        // 使用 smartLoad 让系统自动选择正确的加载器
        testSmartLoad(url: url)
    }

    @objc private func clearCache() {
        addLog("🗑️ 清除所有缓存...")

        // 0. 取消所有正在进行的下载
        LazyManifestLoader.shared.cancelAllDownloads()
        addLog("   ⏸️ 已取消正在进行的下载")

        // 1. 清除 Manifest 缓存
        manifestCacheManager.clearAll()
        addLog("   ✅ Manifest 缓存已清除")

        // 2. 清除持久化缓存
        PersistentManifestLoader.shared.clearAllCache()
        addLog("   ✅ 持久化缓存已清除")

        // 3. 清除 WKWebView 系统缓存（关键！）
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        WKWebsiteDataStore.default().removeData(ofTypes: dataTypes, modifiedSince: Date.distantPast) {
            DispatchQueue.main.async { [weak self] in
                self?.addLog("   ✅ WKWebView 缓存已清除")
                self?.addLog("✅ 所有缓存已清除")
                self?.addLog("💡 提示：下次加载时会重新下载所有内容")
                self?.updateStats()
            }
        }
    }

    @objc private func clearLog() {
        logTextView.text = ""
    }

    @objc private func copyLog() {
        let logText = logTextView.text ?? ""
        guard !logText.isEmpty else {
            showAlert(title: "提示", message: "日志为空，无法复制")
            return
        }

        UIPasteboard.general.string = logText
        addLog("✅ 日志已复制到剪贴板")

        // 显示简短提示
        let alert = UIAlertController(title: "✅", message: "日志已复制", preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            alert.dismiss(animated: true)
        }
    }

    // MARK: - Test Methods

    /// 测试持久化加载
    private func testPersistentLoad(url: URL) {
        addLog("📥 持久化模式：")

        // ✅ 创建临时 WebView 用于测试
        let config = WKWebViewConfiguration()
        let schemeHandler = ManifestURLSchemeHandler()
        config.setURLSchemeHandler(schemeHandler, forURLScheme: "custom")
        config.setURLSchemeHandler(schemeHandler, forURLScheme: "wb-resource")
        let tempWebView = WKWebView(frame: .zero, configuration: config)

        // 首先检查是否已有缓存
        let isCached = PersistentManifestLoader.shared.isCached(url: url)
        if isCached {
            addLog("💡 检测到已有缓存，直接从缓存加载")
            addLog("   1. 读取缓存文件")
            addLog("   2. 加载到 WebView")

            PersistentManifestLoader.shared.loadFromCache(
                url: url,
                in: tempWebView
            ) { [weak self] result in
                // ✅ FIX: 回调可能在后台线程，必须切换到主线程更新 UI
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }

                    self.isTestRunning = false
                    self.startButton.isEnabled = true
                    self.startButton.setTitle("开始测试", for: .normal)

                    switch result {
                    case .success:
                        self.addLog("✅ 从缓存加载成功")
                        self.updateStats()

                    case .failure(let error):
                        self.addLog("❌ 缓存加载失败: \(error.localizedDescription)")
                        // 如果缓存加载失败，尝试重新下载
                        self.addLog("⚠️ 缓存加载失败，尝试重新下载...")
                        self.downloadAndCache(url: url)
                    }
                }
            }
        } else {
            addLog("📥 首次加载，将下载所有资源：")
            addLog("   1. 下载 manifest.json")
            addLog("   2. 检查 persistent 字段")
            addLog("   3. 下载所有资源")
            addLog("   4. 加载到 WebView")
            downloadAndCache(url: url)
        }
    }

    /// 下载并缓存
    private func downloadAndCache(url: URL) {
        addLog("📥 持久化模式：显示全屏进度条")

        // ✅ 创建临时 WebView 用于测试
        let config = WKWebViewConfiguration()
        let schemeHandler = ManifestURLSchemeHandler()
        config.setURLSchemeHandler(schemeHandler, forURLScheme: "custom")
        config.setURLSchemeHandler(schemeHandler, forURLScheme: "wb-resource")
        let tempWebView = WKWebView(frame: .zero, configuration: config)

        // 创建全屏进度控制器
        let progressVC = FullScreenProgressViewController()
        progressVC.modalPresentationStyle = .fullScreen
        present(progressVC, animated: true) { [weak self] in
            guard let self = self else { return }

            // 进度条显示后再开始加载
            PersistentManifestLoader.load(
                url: url,
                in: tempWebView,
                from: self
            ) { [weak self, weak progressVC] result in
                // ✅ FIX: URLSession 回调在后台线程，必须切换到主线程更新 UI
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }

                    self.isTestRunning = false
                    self.startButton.isEnabled = true
                    self.startButton.setTitle("开始测试", for: .normal)

                    // 关闭进度条
                    progressVC?.dismissWithAnimation { [weak self] in
                        guard let self = self else { return }

                        switch result {
                        case .success:
                            self.addLog("✅ 持久化加载成功")
                            self.updateStats()

                            // 打开全屏 WebView 展示页面
                            let displayVC = WebViewDisplayViewController(webView: tempWebView) {
                                self.dismiss(animated: true)
                            }
                            displayVC.modalPresentationStyle = .fullScreen
                            self.present(displayVC, animated: true)

                        case .failure(let error):
                            self.addLog("❌ 持久化加载失败!")
                            self.addLog("   错误类型: \(type(of: error))")
                            self.addLog("   错误描述: \(error.localizedDescription)")
                            self.addLog("   完整错误: \(error)")

                            // 检查是否是 URLError
                            if let urlError = error as? URLError {
                                self.addLog("   URLError 代码: \(urlError.code.rawValue)")
                                self.addLog("   URLError 描述: \(urlError.localizedDescription)")
                                if let failURL = urlError.failureURLString {
                                    self.addLog("   失败的 URL: \(failURL)")
                                }
                            }

                            // 检查是否是 LoaderError
                            if let loaderError = error as? PersistentManifestLoader.LoaderError {
                                self.addLog("   LoaderError: \(loaderError)")
                            }

                            // 检查缓存目录状态
                            let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                                .appendingPathComponent("WebBridgeKit/PersistentCache")
                            self.addLog("   缓存目录存在: \(FileManager.default.fileExists(atPath: cacheDir.path))")

                            self.showAlert(title: "测试失败", message: error.localizedDescription)
                        }
                    }
                }
            }
        }
    }

    /// 测试懒加载
    private func testLazyLoad(url: URL) {
        addLog("⚡ 懒加载模式：立即打开全屏页面")

        // ✅ 创建临时 WebView 用于测试
        let config = WKWebViewConfiguration()
        let schemeHandler = ManifestURLSchemeHandler()
        config.setURLSchemeHandler(schemeHandler, forURLScheme: "custom")
        config.setURLSchemeHandler(schemeHandler, forURLScheme: "wb-resource")
        let tempWebView = WKWebView(frame: .zero, configuration: config)

        // 创建新的全屏页面展示器
        let displayVC = WebViewDisplayViewController(webView: tempWebView) { [weak self] in
            self?.addLog("✅ 全屏页面已关闭")
            self?.dismiss(animated: true)
        }

        displayVC.modalPresentationStyle = .fullScreen
        addLog("📱 准备打开全屏页面...")

        // Delay presentation to next run loop to ensure UI is ready
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            print("🔍 [DEBUG] navigationController = \(String(describing: self.navigationController))")
            print("🔍 [DEBUG] tabBarController = \(String(describing: self.tabBarController))")
            print("🔍 [DEBUG] presentingViewController = \(String(describing: self.presentingViewController))")
            print("🔍 [DEBUG] view.window = \(String(describing: self.view.window))")
            print("🔍 [DEBUG] isViewLoaded = \(self.isViewLoaded)")

            // Try push instead of present for better reliability
            if let navController = self.navigationController {
                self.addLog("🔄 使用 Navigation Push 打开全屏页面")
                navController.pushViewController(displayVC, animated: true)
                self.addLog("✅ 全屏页面已打开")
            } else {
                // Fallback to present
                let presentingVC = self
                presentingVC.present(displayVC, animated: true) {
                    self.addLog("✅ 全屏页面已打开")
                }
            }
        }

        addLog("   1. 下载 manifest.json")
        addLog("   2. 立即加载 HTML")
        addLog("   3. 后台下载资源")

        // 后台加载
        LazyManifestLoader.load(
            url: url,
            in: tempWebView
        ) { [weak self] result in
            // ✅ FIX: URLSession 回调在后台线程，必须切换到主线程更新 UI
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                self.isTestRunning = false
                self.startButton.isEnabled = true
                self.startButton.setTitle("开始测试", for: .normal)

                switch result {
                case .success:
                    self.addLog("✅ 懒加载启动成功")
                    self.addLog("🔄 资源正在后台下载中...")
                    self.updateStats()

                    // 监控后台下载进度
                    self.monitorBackgroundDownload(url: url)

                case .failure(let error):
                    self.addLog("❌ 懒加载失败: \(error.localizedDescription)")
                    // 关闭全屏页面并显示错误
                    displayVC.dismiss(animated: true) {
                        self.showAlert(title: "测试失败", message: error.localizedDescription)
                    }
                }
            }
        }
    }

    /// 测试智能加载（根据 manifest.persistent 自动选择模式）
    private func testSmartLoad(url: URL) {
        addLog("🤖 智能模式：自动根据 manifest.json 的 persistent 字段选择加载器")

        // ✅ 创建临时 WebView 用于测试
        let config = WKWebViewConfiguration()
        let schemeHandler = ManifestURLSchemeHandler()
        config.setURLSchemeHandler(schemeHandler, forURLScheme: "custom")
        config.setURLSchemeHandler(schemeHandler, forURLScheme: "wb-resource")
        let tempWebView = WKWebView(frame: .zero, configuration: config)

        // ✅ 先创建 WebView 展示页面（先 present，这样进度页面可以覆盖在上面）
        addLog("📱 准备 WebView 展示页面...")
        let displayVC = WebViewDisplayViewController(webView: tempWebView) { [weak self] in
            self?.addLog("✅ 全屏页面已关闭")
            // 只关闭 WebView 展示页面，不要关闭测试页面
        }
        displayVC.modalPresentationStyle = .fullScreen

        // 先 present 展示页面
        present(displayVC, animated: true) { [weak self] in
            guard let self = self else { return }

            self.addLog("✅ WebView 展示页面已打开")

            // 然后在展示页面上调用 smartLoad
            // 如果是持久化模式，进度页面会覆盖在展示页面上
            // 下载完成后，进度页面关闭，WebView 就显示出来了
            self.addLog("📥 正在检查 manifest.json...")

            LazyManifestLoader.smartLoad(
                url: url,
                in: tempWebView,
                from: displayVC  // ✅ 从展示页面上显示进度页面
            ) { [weak self] result in
                // ✅ FIX: URLSession 回调在后台线程，必须切换到主线程更新 UI
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }

                    self.isTestRunning = false
                    self.startButton.isEnabled = true
                    self.startButton.setTitle("开始测试", for: .normal)

                    switch result {
                    case .success:
                        // ✅ 展示页面已经打开了，不需要再 present
                        // 进度页面会自动关闭，WebView 就显示出来了
                        self.addLog("✅ 智能加载成功")
                        self.addLog("📱 WebView 已准备就绪")
                        self.updateStats()

                    case .failure(let error):
                        self.addLog("❌ 智能加载失败: \(error.localizedDescription)")

                        // 加载失败，关闭展示页面
                        displayVC.dismiss(animated: true) {
                            // 检查是否是持久化模式错误
                            if error.localizedDescription.contains("persistentModeDisabled") {
                                self.addLog("⚠️ manifest.json 的 persistent 字段为 false")
                                self.addLog("💡 建议：在 manifest.json 中设置 \"persistent\": true 以使用持久化模式")
                            }

                            self.showAlert(title: "测试失败", message: error.localizedDescription)
                        }
                    }
                }
            }
        }
    }

    /// 监控后台下载进度
    private func monitorBackgroundDownload(url: URL) {
        // ⚠️ 禁用进度监控（可能导致后台线程 UI 更新问题）
        // 懒加载会在后台自动下载，无需轮询
        /*
        let cacheID = "lazy_\(abs(url.absoluteString.hashValue))"

        // 定时检查进度
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            if let state = LazyManifestLoader.shared.getLoadingState(for: url) {
                let progress = Int(state.progress * 100)
                self.addLog("⬇️ 下载进度: \(progress)% (\(state.downloadedResources)/\(state.totalResources))")

                if state.isCompleted {
                    self.addLog("✅ 后台下载完成")
                    self.updateStats()
                    timer.invalidate()
                }
            } else {
                // 状态不存在，可能已完成或失败
                timer.invalidate()
            }
        }
        */
    }

    // MARK: - Helper Methods

    /// 处理 LazyManifestLoader 的资源加载日志通知
    @objc private func handleResourceLogNotification(_ notification: Notification) {
        guard let logMessage = notification.userInfo?["log"] as? String else {
            return
        }

        // 在主线程上更新 UI
        DispatchQueue.main.async { [weak self] in
            self?.addLog(logMessage)
        }
    }

    private func addLog(_ message: String) {
        // ✅ FIX: 简化 log 方法，避免复杂的 text range 计算
        // 确保 logTextView 已创建
        guard self.logTextView != nil else {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timestamp)] \(message)")
            return
        }

        let logAction = { [weak self] in
            guard let self = self else { return }

            let timestamp = DateFormatter.localizedString(
                from: Date(),
                dateStyle: .none,
                timeStyle: .medium
            )

            let logLine = "[\(timestamp)] \(message)\n"

            // 简单的文本追加
            self.logTextView.text += logLine

            // 使用 setContentOffset 更安全的滚动方式
            if self.logTextView.text.count > 0 {
                let bottomOffset = CGPoint(x: 0, y: self.logTextView.contentSize.height - self.logTextView.bounds.height)
                if bottomOffset.y > 0 {
                    self.logTextView.setContentOffset(bottomOffset, animated: false)
                }
            }

            print(logLine)
        }

        if Thread.isMainThread {
            logAction()
        } else {
            DispatchQueue.main.sync { logAction() }
        }
    }

    private func updateStats() {
        let stats = manifestCacheManager.getStats()

        let statsText = """
        总请求数: \(stats.totalRequests)
        缓存命中: \(stats.cacheHits)
        缓存未命中: \(stats.cacheMisses)
        命中率: \(stats.formattedHitRate)
        缓存大小: \(stats.formattedCacheSize)
        """

        DispatchQueue.main.async { [weak self] in
            self?.statsLabel.text = statsText
        }
    }

    private func showAlert(title: String, message: String) {
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            self?.present(alert, animated: true)
        }
    }
}

// MARK: - Extensions

// ✅ WKNavigationDelegate 扩展已删除 - 底部 WebView 不再需要
// 页面验证和展示功能已移至全屏模式下的 WebView
