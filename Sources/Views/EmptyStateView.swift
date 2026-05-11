//
//  EmptyStateView.swift
//  SuperApp
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit

/// 空状态视图
/// 用于显示列表为空时的提示信息
public class EmptyStateView: UIView {

    // MARK: - UI Components

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear  // 确保容器背景透明
        return view
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = UIColor.systemGray3
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.headline
        label.textColor = UIColor.label
        label.textAlignment = .center
        label.accessibilityIdentifier = "EmptyStateView.titleLabel"
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.footnote
        label.textColor = UIColor.secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let actionButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = ThemeTokens.Typography.callout
        button.layer.cornerRadius = ThemeTokens.CornerRadius.md
        button.backgroundColor = UIColor.systemBlue
        button.setTitleColor(.white, for: .normal)
        return button
    }()

    // MARK: - Properties

    public var onActionTap: (() -> Void)?

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
        backgroundColor = .clear  // 确保背景透明，避免白色蒙层

        // Accessibility identifier for testing
        accessibilityIdentifier = "EmptyStateView"

        addSubview(containerView)
        containerView.addSubview(iconImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(descriptionLabel)
        containerView.addSubview(actionButton)

        containerView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.left.greaterThanOrEqualToSuperview().offset(40)
            make.right.lessThanOrEqualToSuperview().offset(-40)
        }

        iconImageView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.width.height.equalTo(80)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconImageView.snp.bottom).offset(16)
            make.left.right.equalToSuperview()
        }

        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.left.right.equalToSuperview()
        }

        actionButton.snp.makeConstraints { make in
            make.top.equalTo(descriptionLabel.snp.bottom).offset(20)
            make.centerX.equalToSuperview()
            make.width.equalTo(160)
            make.height.equalTo(44)
            make.bottom.equalToSuperview()
        }

        actionButton.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
    }

    // MARK: - Configure

    public func configure(icon: String? = nil, title: String, description: String, actionTitle: String? = nil) {
        if let icon = icon {
            let config = UIImage.SymbolConfiguration(pointSize: 60, weight: .light)
            iconImageView.image = UIImage(systemName: icon, withConfiguration: config)
            iconImageView.isHidden = false
        } else {
            iconImageView.isHidden = true
        }

        titleLabel.text = title
        descriptionLabel.text = description

        // Debug: 打印配置信息
        print("🔍 [EmptyStateView] configured - title: \(title), icon: \(icon ?? "none")")

        if let actionTitle = actionTitle {
            actionButton.setTitle(actionTitle, for: .normal)
            actionButton.isHidden = false

            actionButton.snp.remakeConstraints { make in
                make.top.equalTo(descriptionLabel.snp.bottom).offset(20)
                make.centerX.equalToSuperview()
                make.width.greaterThanOrEqualTo(160)
                make.height.equalTo(44)
                make.bottom.equalToSuperview()
            }
        } else {
            actionButton.isHidden = true

            actionButton.snp.remakeConstraints { make in
                make.top.equalTo(descriptionLabel.snp.bottom).offset(20)
                make.height.equalTo(0)
                make.bottom.equalToSuperview()
            }
        }
    }

    // MARK: - Actions

    @objc private func actionButtonTapped() {
        onActionTap?()
    }
}
