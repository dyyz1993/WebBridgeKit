//
//  DemoViewController.swift
//  SuperApp
//
//  Created on 2026-01-16.
//

import UIKit
import WebBridgeKit
import os.log

class DemoViewController: UIViewController {

    // MARK: - Properties

    private let scrollView = UIScrollView()
    private let contentStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 24
        return stack
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        title = "WebBridgeKit Demo"
        view.backgroundColor = .systemGroupedBackground

        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStackView)
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])

        addHeaderSection()
        addMainActionsSection()
        addAboutSection()
    }

    // MARK: - Sections

    private func addHeaderSection() {
        let headerView = UIView()
        headerView.backgroundColor = .systemBackground
        headerView.layer.cornerRadius = 16
        headerView.layer.masksToBounds = true

        let titleLabel = UILabel()
        titleLabel.text = "🌉 WebBridgeKit"
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = .label

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Native-Web 桥接框架"
        subtitleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel

        let versionLabel = UILabel()
        versionLabel.text = "支持 32 个 Native Handler"
        versionLabel.font = .systemFont(ofSize: 12, weight: .medium)
        versionLabel.textColor = .systemBlue
        versionLabel.textAlignment = .center

        let stackView = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, versionLabel])
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false

        headerView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 24),
            stackView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -24)
        ])

        contentStackView.addArrangedSubview(headerView)
        contentStackView.addArrangedSubview(createSpacingView(height: 8))
    }

    private func addMainActionsSection() {
        let containerView = UIView()
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 16
        containerView.layer.masksToBounds = true

        let sectionLabel = createSectionLabel(title: "快速开始", icon: "🚀")

        let actionsStackView = UIStackView()
        actionsStackView.axis = .vertical
        actionsStackView.spacing = 12

        let openTestsButton = createActionButton(
            title: "打开测试页面",
            subtitle: "测试所有 32 个 Native Handler",
            icon: "🧪",
            color: UIColor(red: 0.4, green: 0.5, blue: 0.9, alpha: 1.0),
            action: #selector(openTestPage)
        )

        let openRemoteButton = createActionButton(
            title: "打开远程网页",
            subtitle: "浏览任意网站",
            icon: "🌐",
            color: UIColor(red: 0.3, green: 0.8, blue: 0.6, alpha: 1.0),
            action: #selector(openRemotePage)
        )

        let systemInfoButton = createActionButton(
            title: "系统信息",
            subtitle: "查看设备和应用信息",
            icon: "📱",
            color: UIColor(red: 0.9, green: 0.5, blue: 0.4, alpha: 1.0),
            action: #selector(showSystemInfo)
        )

        let cacheDebugButton = createActionButton(
            title: "缓存调试",
            subtitle: "查看和管理压缩缓存",
            icon: "🗂️",
            color: UIColor(red: 0.6, green: 0.4, blue: 0.8, alpha: 1.0),
            action: #selector(openCacheDebug)
        )

        actionsStackView.addArrangedSubview(openTestsButton)
        actionsStackView.addArrangedSubview(createSeparator())
        actionsStackView.addArrangedSubview(openRemoteButton)
        actionsStackView.addArrangedSubview(createSeparator())
        actionsStackView.addArrangedSubview(systemInfoButton)
        actionsStackView.addArrangedSubview(createSeparator())
        actionsStackView.addArrangedSubview(cacheDebugButton)

        actionsStackView.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(sectionLabel)
        containerView.addSubview(actionsStackView)

        NSLayoutConstraint.activate([
            sectionLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            sectionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            sectionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

            actionsStackView.topAnchor.constraint(equalTo: sectionLabel.bottomAnchor, constant: 12),
            actionsStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            actionsStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            actionsStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
        ])

        contentStackView.addArrangedSubview(containerView)
    }

    private func addAboutSection() {
        let containerView = UIView()
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 16
        containerView.layer.masksToBounds = true

        let sectionLabel = createSectionLabel(title: "关于", icon: "ℹ️")

        let infoLabel = UILabel()
        infoLabel.text = """
        WebBridgeKit 是一个强大的 iOS Native-Web 桥接框架。

        功能特点：
        • 32 个原生 Handler
        • 完整的 JS-OC 通信
        • 支持异步调用
        • 内置权限管理
        • 离线缓存支持
        """
        infoLabel.font = .systemFont(ofSize: 13, weight: .regular)
        infoLabel.textColor = .secondaryLabel
        infoLabel.numberOfLines = 0

        let stackView = UIStackView(arrangedSubviews: [sectionLabel, infoLabel])
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
        ])

        contentStackView.addArrangedSubview(containerView)
    }

    // MARK: - Helper Views

    private func createSectionLabel(title: String, icon: String) -> UILabel {
        let label = UILabel()
        label.text = "\(icon) \(title)"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        return label
    }

    private func createActionButton(title: String, subtitle: String, icon: String, color: UIColor, action: Selector) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = color.withAlphaComponent(0.1)
        containerView.layer.cornerRadius = 12
        containerView.isUserInteractionEnabled = true

        let iconLabel = UILabel()
        iconLabel.text = icon
        iconLabel.font = .systemFont(ofSize: 24)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .label

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel

        let textStackView = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStackView.axis = .vertical
        textStackView.spacing = 4

        let horizontalStackView = UIStackView(arrangedSubviews: [iconLabel, textStackView])
        horizontalStackView.axis = .horizontal
        horizontalStackView.spacing = 12
        horizontalStackView.alignment = .center

        horizontalStackView.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(horizontalStackView)
        containerView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: action))

        NSLayoutConstraint.activate([
            horizontalStackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            horizontalStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            horizontalStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            horizontalStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12)
        ])

        let heightConstraint = containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 60)
        heightConstraint.priority = .defaultHigh
        heightConstraint.isActive = true

        return containerView
    }

    private func createSeparator() -> UIView {
        let separator = UIView()
        separator.backgroundColor = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return separator
    }

    private func createSpacingView(height: CGFloat) -> UIView {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: height).isActive = true
        return view
    }

    // MARK: - Actions

    @objc private func openTestPage() {
        // 使用 os_log 以便在 Console.app 中查看
        os_log("=== 点击了打开测试页面 ===", log: OSLog.default, type: .info)

        // 查找 test.html 文件（在 bundle 根目录）
        if let testURL = Bundle.main.url(forResource: "test", withExtension: "html") {
            os_log("✅ 找到测试页面: %@", log: OSLog.default, type: .info, testURL.absoluteString)

            // 直接打开测试页面（移除了人为延迟）
            WebBrowserManager.shared.openBrowser(
                url: testURL,
                params: WebBrowserParams(displayMode: .normal),
                from: self
            )
        } else {
            os_log("❌ 找不到测试页面文件", log: OSLog.default, type: .error)
            let bundlePath = Bundle.main.bundlePath
            showAlert(title: "错误", message: "找不到测试页面文件\n\nBundle路径：\(bundlePath)")
        }
    }

    @objc private func openRemotePage() {
        let alert = UIAlertController(title: "打开网页", message: "输入 URL", preferredStyle: .alert)

        alert.addTextField { textField in
            textField.placeholder = "https://"
            textField.text = "https://github.com"
        }

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "打开", style: .default) { _ in
            if let urlString = alert.textFields?.first?.text,
               let url = URL(string: urlString) {
                WebBrowserManager.shared.openBrowser(
                    url: url,
                    params: WebBrowserParams(displayMode: .normal),
                    from: self
                )
            }
        })

        present(alert, animated: true)
    }

    @objc private func showSystemInfo() {
        let info = [
            ("应用名称", Bundle.main.infoDictionary?["CFBundleName"] as? String ?? ""),
            ("应用版本", Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""),
            ("系统名称", UIDevice.current.systemName),
            ("系统版本", UIDevice.current.systemVersion),
            ("设备型号", UIDevice.current.model),
            ("设备名称", UIDevice.current.name),
            ("WebBridgeKit", "v1.0 - 32 Handlers")
        ]

        let message = info.map { "\($0.0): \($0.1)" }.joined(separator: "\n")
        showAlert(title: "系统信息", message: message)
    }

    @objc private func openCacheDebug() {
        let cacheDebugVC = WebCacheDebugPanelViewController()
        let navController = UINavigationController(rootViewController: cacheDebugVC)
        present(navController, animated: true)
    }

    // MARK: - Alert

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}
