//
//  EmptyStateView.swift
//  SuperApp
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit

/// 统一空状态视图
/// 支持图标（Lucide 或 SF Symbol）、标题、副标题、操作按钮
public class EmptyStateView: UIView {

    // MARK: - UI Components

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = ThemeTokens.Color.textSecondary
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.sectionTitle
        label.textColor = ThemeTokens.Color.textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.accessibilityIdentifier = "EmptyStateView.titleLabel"
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.body
        label.textColor = ThemeTokens.Color.textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.metadata
        label.textColor = ThemeTokens.Color.textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let actionButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = ThemeTokens.Typography.subheadline
        button.layer.cornerRadius = ThemeTokens.CornerRadius.md
        button.backgroundColor = ThemeTokens.Color.primary
        button.setTitleColor(ThemeTokens.Color.background, for: .normal)
        button.contentEdgeInsets = UIEdgeInsets(
            top: ThemeTokens.Spacing.sm,
            left: ThemeTokens.Spacing.md,
            bottom: ThemeTokens.Spacing.sm,
            right: ThemeTokens.Spacing.md
        )
        return button
    }()

    // MARK: - Properties

    public var onActionTap: (() -> Void)?
    private var actionIcon: LucideIcon?

    // MARK: - Initialization

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public convenience init(onAction: (() -> Void)? = nil) {
        self.init(frame: .zero)
        self.onActionTap = onAction
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = .clear
        accessibilityIdentifier = "EmptyStateView"

        addSubview(containerView)
        containerView.addSubview(iconImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)
        containerView.addSubview(descriptionLabel)
        containerView.addSubview(actionButton)

        containerView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(ThemeTokens.Spacing.xl)
        }

        iconImageView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.size.equalTo(ThemeTokens.Icons.Sizes.xxl)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconImageView.snp.bottom).offset(ThemeTokens.Spacing.md)
            make.leading.trailing.equalToSuperview()
        }

        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(ThemeTokens.Spacing.xs)
            make.leading.trailing.equalToSuperview()
        }

        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(ThemeTokens.Spacing.xs)
            make.leading.trailing.equalToSuperview()
        }

        actionButton.snp.makeConstraints { make in
            make.top.equalTo(descriptionLabel.snp.bottom).offset(ThemeTokens.Spacing.lg)
            make.centerX.equalToSuperview()
            make.width.greaterThanOrEqualTo(120)
            make.height.equalTo(44)
            make.bottom.equalToSuperview()
        }

        actionButton.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
    }

    // MARK: - Configure (Lucide Icon)

    public func configure(
        icon: LucideIcon,
        title: String,
        subtitle: String? = nil,
        description: String,
        actionTitle: String? = nil,
        actionIcon: LucideIcon? = nil
    ) {
        iconImageView.image = icon.templateImage(pointSize: ThemeTokens.Icons.Sizes.xxl, weight: .light)
        iconImageView.isHidden = false

        titleLabel.text = title
        configureSubtitle(subtitle)
        descriptionLabel.text = description
        self.actionIcon = actionIcon
        configureActionButton(actionTitle, icon: actionIcon)
    }

    // MARK: - Configure (SF Symbol)

    public func configure(icon: String? = nil, title: String, description: String, actionTitle: String? = nil) {
        if let icon = icon {
            let config = UIImage.SymbolConfiguration(pointSize: 60, weight: .light)
            iconImageView.image = UIImage(systemName: icon, withConfiguration: config)
            iconImageView.isHidden = false
        } else {
            iconImageView.isHidden = true
        }

        titleLabel.text = title
        subtitleLabel.isHidden = true
        descriptionLabel.text = description
        configureActionButton(actionTitle)
    }

    // MARK: - Private

    private func configureSubtitle(_ subtitle: String?) {
        if let subtitle = subtitle, !subtitle.isEmpty {
            subtitleLabel.text = subtitle
            subtitleLabel.isHidden = false
        } else {
            subtitleLabel.isHidden = true
        }
    }

    private func configureActionButton(_ actionTitle: String?, icon: LucideIcon? = nil) {
        if let actionTitle = actionTitle {
            actionButton.setTitle(actionTitle, for: .normal)
            if let icon = icon {
                actionButton.setImage(icon.templateImage(pointSize: ThemeTokens.Icons.Sizes.sm), for: .normal)
                actionButton.tintColor = ThemeTokens.Color.background
                actionButton.semanticContentAttribute = .forceLeftToRight
                actionButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: ThemeTokens.Spacing.sm)
            } else {
                actionButton.setImage(nil, for: .normal)
            }
            actionButton.isHidden = false

            actionButton.snp.remakeConstraints { make in
                make.top.equalTo(descriptionLabel.snp.bottom).offset(ThemeTokens.Spacing.lg)
                make.centerX.equalToSuperview()
                make.width.greaterThanOrEqualTo(120)
                make.height.equalTo(44)
                make.bottom.equalToSuperview()
            }
        } else {
            actionButton.isHidden = true

            actionButton.snp.remakeConstraints { make in
                make.top.equalTo(descriptionLabel.snp.bottom)
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
