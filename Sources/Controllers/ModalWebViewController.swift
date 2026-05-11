//
//  ModalWebViewController.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-14.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import WebKit

// Framework imports

/// 弹窗模式的 WebViewController
/// 支持自定义大小、半透明遮罩、点击背景关闭、拖拽关闭等功能
public class ModalWebViewController: UIViewController {

    // MARK: - Properties

    public var webView: WKWebView!
    public var bridge: WebJavaScriptBridge?
    public var allowJavaScriptClose: Bool = true

    private var containerView: UIView!
    private var maskView: UIView!
    private var webViewVC: WebViewController!
    private var config: WebBrowserParams.ModalConfig

    // MARK: - Initialization

    public init(htmlName: String, config: WebBrowserParams.ModalConfig = .default) {
        self.config = config
        super.init(nibName: nil, bundle: nil)
        loadLocalHTML(named: htmlName)
    }

    public init(url: URL, config: WebBrowserParams.ModalConfig = .default) {
        self.config = config
        super.init(nibName: nil, bundle: nil)
        loadRemoteURL(url)
    }

    required init?(coder: NSCoder) {
        self.config = .default
        super.init(coder: coder)
    }

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGestures()
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // 入场动画
        UIView.animate(withDuration: ThemeTokens.Animation.slow.duration, delay: 0, options: .curveEaseOut) {
            self.containerView.transform = .identity
            self.maskView?.alpha = 1
        }
    }

    // MARK: - Setup

    private func setupUI() {
        view.accessibilityIdentifier = "modalBrowser.view"
        view.backgroundColor = .clear

        // 遮罩层
        if config.showMask {
            maskView = UIView()
            maskView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            maskView.accessibilityIdentifier = "modalBrowser.maskView"
            maskView.alpha = 0
            view.addSubview(maskView)
            maskView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }

            // 点击遮罩手势
            if config.clickMaskCloses {
                let tap = UITapGestureRecognizer(target: self, action: #selector(handleMaskTap))
                maskView.addGestureRecognizer(tap)
            }
        }

        // 容器视图
        containerView = UIView()
        containerView.accessibilityIdentifier = "modalBrowser.containerView"
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = config.cornerRadius
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = config.shadowOpacity
        containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        containerView.layer.shadowRadius = 16
        containerView.clipsToBounds = true
        view.addSubview(containerView)

        // 计算尺寸
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        let width = screenWidth * config.widthPercent
        let height = screenHeight * config.heightPercent

        containerView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(width)
            make.height.equalTo(height)
        }

        // 初始缩放（用于动画）
        containerView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)

        // 嵌入 WebViewController
        let webVC = WebViewController()
        webViewVC = webVC
        addChild(webVC)
        containerView.addSubview(webVC.view)
        webVC.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        webVC.didMove(toParent: self)

        webView = webVC.webView
        webView.accessibilityIdentifier = "modalBrowser.webView"
        bridge = webVC.bridge

        // 关闭按钮
        if config.clickMaskCloses {
            setupCloseButton()
        }
    }

    private func setupGestures() {
        // 拖拽关闭手势
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture))
        pan.delegate = self
        view.addGestureRecognizer(pan)
    }

    private func setupCloseButton() {
        let closeButton = UIButton(type: .system)
        closeButton.accessibilityIdentifier = "modalBrowser.closeButton"
        closeButton.setImage(LucideIcon.xmarkCircle.templateImage(), for: .normal)
        closeButton.tintColor = .gray
        closeButton.backgroundColor = UIColor.white.withAlphaComponent(0.8)
        closeButton.layer.cornerRadius = ThemeTokens.CornerRadius.xl
        closeButton.accessibilityLabel = "关闭弹窗"
        closeButton.addTarget(self, action: #selector(handleCloseButtonTap), for: .touchUpInside)

        containerView.addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.right.equalToSuperview().offset(-12)
            make.width.height.equalTo(32)
        }
    }

    // MARK: - Actions

    @objc private func handleMaskTap() {
        // 发送事件到 JS
        bridge?.sendEventToJS(event: "onBackgroundTap", data: [:])

        // 关闭弹窗
        if config.clickMaskCloses {
            closeWithAnimation()
        }
    }

    @objc private func handleCloseButtonTap() {
        closeWithAnimation()
    }

    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)

        switch gesture.state {
        case .changed:
            if translation.y > 0 {
                containerView.transform = CGAffineTransform(translationX: 0, y: translation.y)
                let progress = min(translation.y / 200, 1)
                maskView?.alpha = 1 - progress
            }
        case .ended:
            if translation.y > 100 || velocity.y > 1000 {
                closeWithAnimation()
            } else {
                UIView.animate(withDuration: ThemeTokens.Animation.slow.duration) {
                    self.containerView.transform = .identity
                    self.maskView?.alpha = 1
                }
            }
        default:
            break
        }
    }

    // MARK: - Public Methods

    public func loadLocalHTML(named htmlName: String) {
        DispatchQueue.main.async { [weak self] in
            self?.webViewVC?.loadLocalHTML(named: htmlName)
        }
    }

    public func loadRemoteURL(_ url: URL) {
        DispatchQueue.main.async { [weak self] in
            self?.webViewVC?.loadURL(url)
        }
    }

    public func updateWidth(_ percentString: String) {
        guard let percent = Float(percentString.replacingOccurrences(of: "%", with: "")) else { return }
        let width = UIScreen.main.bounds.width * CGFloat(percent / 100)

        guard let containerView = containerView else { return }
        UIView.animate(withDuration: ThemeTokens.Animation.slow.duration) {
            containerView.snp.updateConstraints { make in
                make.width.equalTo(width)
            }
            self.view.layoutIfNeeded()
        }
    }

    public func updateHeight(_ percentString: String) {
        guard let percent = Float(percentString.replacingOccurrences(of: "%", with: "")) else { return }
        let height = UIScreen.main.bounds.height * CGFloat(percent / 100)

        guard let containerView = containerView else { return }
        UIView.animate(withDuration: ThemeTokens.Animation.slow.duration) {
            containerView.snp.updateConstraints { make in
                make.height.equalTo(height)
            }
            self.view.layoutIfNeeded()
        }
    }

    public var showMask: Bool {
        get { config.showMask }
        set {
            config.showMask = newValue
            maskView?.isHidden = !newValue
        }
    }

    // MARK: - Close

    public func close(animated: Bool = true) {
        if animated {
            closeWithAnimation()
        } else {
            dismiss(animated: false)
        }
    }

    private func closeWithAnimation() {
        UIView.animate(withDuration: ThemeTokens.Animation.normal.duration, animations: {
            self.containerView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            self.maskView?.alpha = 0
        }, completion: { _ in
            self.dismiss(animated: false)
        })
    }

    // MARK: - Cleanup

    deinit {
        // 🔒 Clean up child view controller
        webViewVC?.willMove(toParent: nil)
        webViewVC?.view.removeFromSuperview()
        webViewVC?.removeFromParent()

        // 🔒 Stop loading and clean up WebView
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView?.uiDelegate = nil

        // 🔒 Remove from superview
        webView?.removeFromSuperview()

        // 🔒 Clean up bridge
        bridge = nil

        print("🧹 [ModalWebVC] Cleaned up with proper memory management")
    }
}

// MARK: - UIGestureRecognizerDelegate

extension ModalWebViewController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 允许拖拽手势和 WebView 滚动手势同时识别
        return true
    }
}
