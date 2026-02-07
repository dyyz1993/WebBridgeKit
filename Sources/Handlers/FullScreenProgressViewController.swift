//
//  FullScreenProgressViewController.swift
//  DemoApp
//
//  Created on 2025-02-03.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit

/// 全屏进度视图控制器
/// 提供类似系统原生加载界面的全屏进度显示
public class FullScreenProgressViewController: UIViewController {

    // MARK: - UI Components

    // ✅ 验证标签：确认使用的是正确的文件
    private let verificationLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = .systemGreen
        label.textAlignment = .center
        label.text = "✅ 已修改 2025-02-04 Sources/Handlers/FullScreenProgressViewController.swift"
        label.backgroundColor = .systemBackground
        return label
    }()

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        return view
    }()

    private let iconImageView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 60, weight: .light)
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .systemBlue
        imageView.image = UIImage(systemName: "icloud.and.arrow.down", withConfiguration: config)
        return imageView
    }()

    private let progressView: UIProgressView = {
        let progress = UIProgressView(progressViewStyle: .default)
        progress.trackTintColor = .systemGray5
        progress.progressTintColor = .systemBlue
        return progress
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 2
        label.text = "正在准备..."
        return label
    }()

    private let percentageLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 24, weight: .bold)
        label.textColor = .systemBlue
        label.textAlignment = .center
        label.text = "0%"
        return label
    }()

    private let detailLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 1
        label.text = "等待开始..."
        return label
    }()

    private let completeIconImageView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 60, weight: .light)
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .systemGreen
        imageView.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: config)
        imageView.isHidden = true
        return imageView
    }()

    // MARK: - Properties

    private var totalResources: Int = 0
    private var currentProgress: Int = 0

    // MARK: - Initialization

    public init(totalResources: Int = 0) {
        self.totalResources = totalResources
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        view.accessibilityIdentifier = "FullScreenProgressViewController"

        setupUI()

        // 入场动画
        animateIn()
    }

    // MARK: - Setup

    private func setupUI() {
        view.addSubview(verificationLabel)
        view.addSubview(containerView)
        containerView.addSubview(iconImageView)
        containerView.addSubview(progressView)
        containerView.addSubview(statusLabel)
        containerView.addSubview(percentageLabel)
        containerView.addSubview(detailLabel)
        containerView.addSubview(completeIconImageView)

        // 验证标签在顶部
        verificationLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(8)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
        }

        containerView.snp.makeConstraints { make in
            make.top.equalTo(verificationLabel.snp.bottom).offset(8)
            make.left.right.bottom.equalToSuperview()
        }

        // 图标
        iconImageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview().offset(-120)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(80)
        }

        // 进度条
        progressView.snp.makeConstraints { make in
            make.top.equalTo(iconImageView.snp.bottom).offset(40)
            make.left.equalToSuperview().offset(60)
            make.right.equalToSuperview().offset(-60)
            make.height.equalTo(8)
        }

        // 百分比
        percentageLabel.snp.makeConstraints { make in
            make.top.equalTo(progressView.snp.bottom).offset(24)
            make.centerX.equalToSuperview()
        }

        // 状态标签
        statusLabel.snp.makeConstraints { make in
            make.top.equalTo(percentageLabel.snp.bottom).offset(16)
            make.left.equalToSuperview().offset(40)
            make.right.equalToSuperview().offset(-40)
        }

        // 详细信息
        detailLabel.snp.makeConstraints { make in
            make.top.equalTo(statusLabel.snp.bottom).offset(8)
            make.left.equalToSuperview().offset(40)
            make.right.equalToSuperview().offset(-40)
        }

        // 完成图标
        completeIconImageView.snp.makeConstraints { make in
            make.center.equalTo(iconImageView)
            make.width.height.equalTo(80)
        }
    }

    // MARK: - Animations

    private func animateIn() {
        containerView.alpha = 0
        containerView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)

        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0,
            options: .curveEaseOut
        ) {
            self.containerView.alpha = 1
            self.containerView.transform = .identity
        }

        // 图标轻微动画
        UIView.animate(
            withDuration: 1.0,
            delay: 0.3,
            options: [.repeat, .autoreverse]
        ) {
            self.iconImageView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }
    }

    private func animateOut(completion: @escaping () -> Void) {
        UIView.animate(
            withDuration: 0.25,
            delay: 0,
            options: .curveEaseIn
        ) {
            self.containerView.alpha = 0
            self.containerView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        } completion: { _ in
            completion()
        }
    }

    // MARK: - Public Methods

    /// 更新下载进度
    /// - Parameters:
    ///   - current: 当前下载数量
    ///   - total: 总数量
    ///   - message: 状态消息
    ///   - resourceName: 当前下载的资源名称
    public func updateProgress(current: Int, total: Int, message: String, resourceName: String? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.currentProgress = current
            self.totalResources = total

            let progress = Float(current) / Float(total)

            // 更新进度条
            UIView.animate(withDuration: 0.2) {
                self.progressView.setProgress(progress, animated: true)
            }

            // 更新百分比
            self.percentageLabel.text = "\(Int(progress * 100))%"

            // 更新状态
            self.statusLabel.text = message

            // 更新详细信息
            if let resourceName = resourceName {
                self.detailLabel.text = "正在下载: \(resourceName)"
            } else {
                self.detailLabel.text = "\(current) / \(total) 个资源"
            }

            // 检查是否完成
            if current >= total {
                showCompletion()
            }
        }
    }

    /// 显示完成状态
    private func showCompletion() {
        // 停止图标动画
        iconImageView.layer.removeAllAnimations()

        // ✅ 只更新进度条到100%，不改变任何文案
        progressView.setProgress(1.0, animated: true)
        percentageLabel.text = "100%"

        // 隐藏下载图标
        iconImageView.isHidden = true

        // 不显示完成图标
        completeIconImageView.isHidden = true
    }

    /// 带动画关闭
    public func dismissWithAnimation(completion: @escaping () -> Void) {
        animateOut {
            self.dismiss(animated: false, completion: completion)
        }
    }
}
