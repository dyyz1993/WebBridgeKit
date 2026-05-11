//
//  WebGestureInterceptor.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-15.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import WebKit

/// 手势拦截器 - 负责拦截和处理 WebView 上的手势
public class WebGestureInterceptor: NSObject {

    // MARK: - Properties

    private weak var webView: WKWebView?
    private weak var gestureHandler: WebGestureHandler?
    private var config: WebGestureConfig

    // 手势识别器
    private var panGestureRecognizer: UIPanGestureRecognizer!
    private var swipeLeftGestureRecognizer: UISwipeGestureRecognizer!
    private var swipeRightGestureRecognizer: UISwipeGestureRecognizer!
    private var longPressGestureRecognizer: UILongPressGestureRecognizer!
    private var doubleTapGestureRecognizer: UITapGestureRecognizer!

    // 下拉相关
    private var pullStartY: CGFloat = 0
    private var isPulling = false
    private var pullIndicatorView: PullIndicatorView?

    // MARK: - Initialization

    public init(webView: WKWebView, gestureHandler: WebGestureHandler) {
        self.webView = webView
        self.gestureHandler = gestureHandler
        self.config = gestureHandler.getConfig()
        super.init()

        setupGestures()
    }

    // MARK: - Setup

    private func setupGestures() {
        guard let webView = webView else { return }

        // 下拉手势
        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGestureRecognizer.delegate = self
        webView.addGestureRecognizer(panGestureRecognizer)

        // 左滑手势
        swipeLeftGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeLeft(_:)))
        swipeLeftGestureRecognizer.direction = .left
        swipeLeftGestureRecognizer.delegate = self
        webView.addGestureRecognizer(swipeLeftGestureRecognizer)

        // 右滑手势
        swipeRightGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeRight(_:)))
        swipeRightGestureRecognizer.direction = .right
        swipeRightGestureRecognizer.delegate = self
        webView.addGestureRecognizer(swipeRightGestureRecognizer)

        // 长按手势
        longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressGestureRecognizer.minimumPressDuration = 0.5
        longPressGestureRecognizer.delegate = self
        webView.addGestureRecognizer(longPressGestureRecognizer)

        // 双击手势
        doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGestureRecognizer.numberOfTapsRequired = 2
        doubleTapGestureRecognizer.delegate = self
        webView.addGestureRecognizer(doubleTapGestureRecognizer)

        // 创建下拉指示器
        if config.showVisualFeedback {
            setupPullIndicator()
        }

        WebBridgeLogger.shared.info("[WebGestureInterceptor] Gestures setup completed")
    }

    private func setupPullIndicator() {
        guard let webView = webView else { return }

        let indicator = PullIndicatorView()
        indicator.frame = CGRect(x: 0, y: -60, width: webView.bounds.width, height: 60)
        indicator.alpha = 0
        webView.scrollView.addSubview(indicator)
        pullIndicatorView = indicator
    }

    // MARK: - Gesture Handlers

    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard config.enabled && config.enabledGestures.contains(.pull) else { return }
        guard let webView = webView else { return }

        let translation = gesture.translation(in: webView)
        _ = gesture.velocity(in: webView)
        let location = gesture.location(in: webView)

        // 只在顶部且向下拖动时响应
        let scrollView = webView.scrollView
        let isAtTop = scrollView.contentOffset.y <= -scrollView.adjustedContentInset.top
        let isPullingDown = translation.y > 0

        switch gesture.state {
        case .began:
            if isAtTop {
                isPulling = true
                pullStartY = location.y
                gestureHandler?.handlePullStart(at: pullStartY)
            }

        case .changed:
            guard isPulling && isPullingDown else { return }

            let screenHeight = UIScreen.main.bounds.height
            let maxDistance = screenHeight * config.pullMaxDistance
            let threshold = screenHeight * config.pullThreshold

            // 使用阻尼效果，越往下拉越难拉
            let dampenedDistance = dampenDistance(translation.y, max: maxDistance)

            gestureHandler?.handlePullMove(
                distance: dampenedDistance,
                threshold: threshold,
                maxDistance: maxDistance
            )

            // 更新视觉指示器
            if config.showVisualFeedback {
                updatePullIndicator(distance: dampenedDistance, threshold: threshold, max: maxDistance)
            }

        case .ended, .cancelled:
            guard isPulling else { return }

            let screenHeight = UIScreen.main.bounds.height
            let threshold = screenHeight * config.pullThreshold

            gestureHandler?.handlePullRelease(threshold: threshold)

            if config.showVisualFeedback {
                if translation.y >= threshold {
                    // 达到阈值，显示加载状态
                    showLoadingIndicator()
                } else if config.autoBounceBack {
                    // 未达到阈值，回弹
                    hidePullIndicator()
                }
            }

            isPulling = false
            pullStartY = 0

        default:
            break
        }
    }

    @objc private func handleSwipeLeft(_ gesture: UISwipeGestureRecognizer) {
        guard config.enabled && config.enabledGestures.contains(.swipeLeft) else { return }

        let location = gesture.location(in: webView)
        gestureHandler?.sendGestureEvent(
            type: "swipeLeft",
            event: "detected",
            data: [
                "location": ["x": location.x, "y": location.y],
                "direction": "left"
            ]
        )
    }

    @objc private func handleSwipeRight(_ gesture: UISwipeGestureRecognizer) {
        guard config.enabled && config.enabledGestures.contains(.swipeRight) else { return }

        let location = gesture.location(in: webView)
        gestureHandler?.sendGestureEvent(
            type: "swipeRight",
            event: "detected",
            data: [
                "location": ["x": location.x, "y": location.y],
                "direction": "right"
            ]
        )
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard config.enabled && config.enabledGestures.contains(.longPress) else { return }

        if gesture.state == .began {
            let location = gesture.location(in: webView)
            gestureHandler?.sendGestureEvent(
                type: "longPress",
                event: "detected",
                data: [
                    "location": ["x": location.x, "y": location.y]
                ]
            )
        }
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        guard config.enabled && config.enabledGestures.contains(.doubleTap) else { return }

        let location = gesture.location(in: webView)
        gestureHandler?.sendGestureEvent(
            type: "doubleTap",
            event: "detected",
            data: [
                "location": ["x": location.x, "y": location.y]
            ]
        )
    }

    // MARK: - Visual Feedback

    private func updatePullIndicator(distance: CGFloat, threshold: CGFloat, max: CGFloat) {
        guard let indicator = pullIndicatorView else { return }

        let progress = min(distance / threshold, 1.0)

        // 根据进度更新指示器
        UIView.animate(withDuration: ThemeTokens.Animation.fast.duration) {
            indicator.alpha = progress
            indicator.transform = CGAffineTransform(scaleX: progress, y: progress)
            indicator.setProgress(progress, triggered: distance >= threshold)
        }
    }

    private func showLoadingIndicator() {
        guard let indicator = pullIndicatorView else { return }

        indicator.startLoading()
        UIView.animate(withDuration: ThemeTokens.Animation.fast.duration) {
            indicator.alpha = 1
        }
    }

    private func hidePullIndicator() {
        guard let indicator = pullIndicatorView else { return }

        indicator.stopLoading()
        UIView.animate(withDuration: ThemeTokens.Animation.slow.duration, delay: 0, options: .curveEaseOut) {
            indicator.alpha = 0
            indicator.transform = .identity
        }
    }

    // MARK: - Helper Methods

    private func dampenDistance(_ distance: CGFloat, max: CGFloat) -> CGFloat {
        // 使用对数阻尼，让下拉感觉更自然
        let damping = log(1 + distance / 100) * 150
        return min(damping, max)
    }

    // MARK: - Public Methods

    /// 更新手势配置
    public func updateConfig(_ newConfig: WebGestureConfig) {
        self.config = newConfig

        // 启用/禁用手势识别器
        panGestureRecognizer.isEnabled = config.enabled && config.enabledGestures.contains(.pull)
        swipeLeftGestureRecognizer.isEnabled = config.enabled && config.enabledGestures.contains(.swipeLeft)
        swipeRightGestureRecognizer.isEnabled = config.enabled && config.enabledGestures.contains(.swipeRight)
        longPressGestureRecognizer.isEnabled = config.enabled && config.enabledGestures.contains(.longPress)
        doubleTapGestureRecognizer.isEnabled = config.enabled && config.enabledGestures.contains(.doubleTap)

        // 更新指示器
        if config.showVisualFeedback && pullIndicatorView == nil {
            setupPullIndicator()
        } else if !config.showVisualFeedback {
            pullIndicatorView?.removeFromSuperview()
            pullIndicatorView = nil
        }
    }

    /// 停止加载指示器
    public func stopLoading() {
        hidePullIndicator()
    }

    /// 清理
    public func cleanup() {
        pullIndicatorView?.removeFromSuperview()
        pullIndicatorView = nil
    }
}

// MARK: - UIGestureRecognizerDelegate

extension WebGestureInterceptor: UIGestureRecognizerDelegate {

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let webView = webView else { return false }

        // 对于下拉手势，只在页面顶部时响应
        if gestureRecognizer === panGestureRecognizer {
            let scrollView = webView.scrollView
            let isAtTop = scrollView.contentOffset.y <= -scrollView.adjustedContentInset.top

            // 检查是否是向下拉
            if let pan = gestureRecognizer as? UIPanGestureRecognizer {
                let velocity = pan.velocity(in: webView)
                return isAtTop && velocity.y > 0
            }

            return isAtTop
        }

        return true
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 允许与 WebView 的滚动手势同时识别
        if otherGestureRecognizer is UIPanGestureRecognizer {
            return true
        }
        return false
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UILongPressGestureRecognizer) -> Bool {
        // 下拉手势不需要等待长按失败
        return false
    }
}

// MARK: - PullIndicatorView

private class PullIndicatorView: UIView {

    private let iconView = UIImageView()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let label = UILabel()
    private var isLoading = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = ThemeTokens.Color.background

        // 图标
        iconView.image = LucideIcon.arrowDown.templateImage()
        iconView.tintColor = ThemeTokens.Color.textSecondary
        iconView.contentMode = .scaleAspectFit
        addSubview(iconView)

        // 加载指示器
        activityIndicator.hidesWhenStopped = true
        activityIndicator.color = ThemeTokens.Color.textSecondary
        addSubview(activityIndicator)

        // 标签
        label.text = "下拉刷新"
        label.font = .systemFont(ofSize: 12)
        label.textColor = ThemeTokens.Color.textSecondary
        label.textAlignment = .center
        addSubview(label)

        // 布局
        iconView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(10)
            make.width.height.equalTo(24)
        }

        activityIndicator.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(10)
        }

        label.snp.makeConstraints { make in
            make.top.equalTo(iconView.snp.bottom).offset(4)
            make.centerX.equalToSuperview()
        }
    }

    func setProgress(_ progress: CGFloat, triggered: Bool) {
        guard !isLoading else { return }

        let rotation = CGFloat.pi * progress
        iconView.transform = CGAffineTransform(rotationAngle: rotation)

        if triggered {
            iconView.image = LucideIcon.arrowUp.templateImage()
            label.text = "释放刷新"
        } else {
            iconView.image = LucideIcon.arrowDown.templateImage()
            label.text = "下拉刷新"
        }

        iconView.alpha = progress
        label.alpha = progress
    }

    func startLoading() {
        isLoading = true
        iconView.isHidden = true
        activityIndicator.startAnimating()
        label.text = "加载中..."
    }

    func stopLoading() {
        isLoading = false
        iconView.isHidden = false
        activityIndicator.stopAnimating()
        label.text = "下拉刷新"

        UIView.animate(withDuration: ThemeTokens.Animation.fast.duration) {
            self.iconView.transform = .identity
            self.iconView.alpha = 0
            self.label.alpha = 0
        }
    }
}
