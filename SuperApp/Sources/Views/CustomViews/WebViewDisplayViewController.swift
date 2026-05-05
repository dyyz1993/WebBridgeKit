//
//  WebViewDisplayViewController.swift
//  SuperApp
//
//  Created on 2025-02-03.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit
import WebKit

/// 全屏 WebView 展示控制器
/// 用于展示已加载内容的 WebView，提供全屏浏览体验
public class WebViewDisplayViewController: UIViewController {

    // MARK: - UI Components

    private let webView: WKWebView
    private let onClose: (() -> Void)?

    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("✕ 关闭", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.backgroundColor = UIColor.systemBackground
        button.layer.cornerRadius = 20
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.3
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.accessibilityIdentifier = "webview_display.close_button"
        button.accessibilityLabel = "关闭 WebView"
        return button
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "📱 WebView 实际渲染效果"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.textAlignment = .center
        label.layer.cornerRadius = 8
        label.layer.masksToBounds = true
        return label
    }()

    // MARK: - Initialization

    /// 初始化全屏 WebView 展示控制器
    /// - Parameters:
    ///   - webView: 要展示的 WebView
    ///   - onClose: 关闭回调
    public init(webView: WKWebView, onClose: (() -> Void)?) {
        self.webView = webView
        self.onClose = onClose
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        view.accessibilityIdentifier = "WebViewDisplayViewController"

        setupUI()
        setupActions()

        // ✅ 修复：在全屏展示时启用 WebView 的用户交互
        // 这样用户可以与 WebView 内容进行交互（滚动、点击链接等）
        webView.isUserInteractionEnabled = true
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("✅ [WebViewDisplayVC] Full screen view did appear - presentation successful!")
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // 如果是模态展示，隐藏导航栏
        if presentingViewController != nil {
            navigationController?.setNavigationBarHidden(true, animated: animated)
        }
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // ⚠️ 关键：在 pop 返回时移除 WebView
        // 这样原控制器的 viewDidAppear 会检测到 webView.superview == nil 并重新添加
        if navigationController?.viewControllers.count ?? 0 > 1 {
            // 我们还在导航栈中，即将被 pop
            // 移除 WebView，让它返回到原控制器
            if webView.superview == self.view {
                print("🔧 [WebViewDisplayVC] 准备返回，移除 WebView")
                webView.removeFromSuperview()
            }
        }

        // 恢复导航栏
        if presentingViewController != nil {
            navigationController?.setNavigationBarHidden(false, animated: animated)
        }
    }

    // MARK: - Setup

    private func setupUI() {
        // Remove WebView from old parent (SnapKit constraints are auto-deactivated)
        webView.removeFromSuperview()

        // 添加 WebView
        view.addSubview(webView)
        webView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }

        // 添加关闭按钮
        view.addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.right.equalToSuperview().offset(-16)
            make.width.equalTo(80)
            make.height.equalTo(40)
        }

        // 添加标题标签
        view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.centerX.equalToSuperview()
            make.height.equalTo(32)
            make.left.greaterThanOrEqualToSuperview().offset(100)
            make.right.lessThanOrEqualTo(closeButton.snp.left).offset(-16)
        }
    }

    private func setupActions() {
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        // Pop if pushed, otherwise dismiss
        if navigationController?.viewControllers.count ?? 0 > 1 {
            navigationController?.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
        onClose?()
    }
}
