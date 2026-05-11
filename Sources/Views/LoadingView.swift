//
//  LoadingView.swift
//  SuperApp
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit

/// 加载视图
/// 显示加载动画和进度
public class LoadingView: UIView {

    // MARK: - UI Components

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBackground
        view.layer.cornerRadius = ThemeTokens.CornerRadius.lg
        view.layer.masksToBounds = true
        return view
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private let progressView: UIProgressView = {
        let progress = UIProgressView(progressViewStyle: .default)
        progress.trackTintColor = UIColor.systemGray5
        progress.progressTintColor = UIColor.systemBlue
        return progress
    }()

    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.footnote
        label.textColor = UIColor.secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let detailLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.caption1
        label.textColor = UIColor.tertiaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    // MARK: - Properties

    private var isProgressMode = false

    // MARK: - Initialization

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        // 默认隐藏，避免显示白色面板
        isHidden = true
        alpha = 0
        backgroundColor = UIColor.black.withAlphaComponent(0.3)

        addSubview(containerView)
        containerView.addSubview(activityIndicator)
        containerView.addSubview(progressView)
        containerView.addSubview(messageLabel)
        containerView.addSubview(detailLabel)

        containerView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(200)
            make.height.greaterThanOrEqualTo(120)
        }

        activityIndicator.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.centerX.equalToSuperview()
        }

        progressView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
            make.height.equalTo(4)
        }

        messageLabel.snp.makeConstraints { make in
            make.top.equalTo(activityIndicator.snp.bottom).offset(16)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
        }

        detailLabel.snp.makeConstraints { make in
            make.top.equalTo(messageLabel.snp.bottom).offset(8)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.bottom.equalToSuperview().offset(-20)
        }

        progressView.isHidden = true
    }

    // MARK: - Public Methods

    /// 开始加载（旋转指示器模式）
    public func startLoading(message: String? = nil) {
        isProgressMode = false

        activityIndicator.startAnimating()
        activityIndicator.isHidden = false
        progressView.isHidden = true

        if let message = message {
            messageLabel.text = message
            messageLabel.isHidden = false
        } else {
            messageLabel.isHidden = true
        }

        detailLabel.text = ""
        detailLabel.isHidden = true

        isHidden = false
        alpha = 0
        UIView.animate(withDuration: ThemeTokens.Animation.fast.duration) {
            self.alpha = 1
        }
    }

    /// 开始加载（进度条模式）
    public func startProgressLoading(message: String? = nil) {
        isProgressMode = true

        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
        progressView.isHidden = false
        progressView.progress = 0

        if let message = message {
            messageLabel.text = message
            messageLabel.isHidden = false
        } else {
            messageLabel.isHidden = true
        }

        detailLabel.text = "0%"
        detailLabel.isHidden = false

        isHidden = false
        alpha = 0
        UIView.animate(withDuration: ThemeTokens.Animation.fast.duration) {
            self.alpha = 1
        }
    }

    /// 更新进度
    public func updateProgress(_ progress: Double, message: String? = nil, detail: String? = nil) {
        guard isProgressMode else { return }

        progressView.progress = Float(progress)
        detailLabel.text = detail ?? "\(Int(progress * 100))%"

        if let message = message {
            messageLabel.text = message
        }
    }

    /// 停止加载
    public func stopLoading() {
        activityIndicator.stopAnimating()

        UIView.animate(withDuration: ThemeTokens.Animation.fast.duration, animations: {
            self.alpha = 0
        }, completion: { _ in
            self.isHidden = true
        })
    }

    /// 更新消息
    public func updateMessage(_ message: String) {
        messageLabel.text = message
    }

    /// 更新详情
    public func updateDetail(_ detail: String) {
        detailLabel.text = detail
        detailLabel.isHidden = false
    }
}
