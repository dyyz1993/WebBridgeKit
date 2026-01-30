//
//  EmptyStateView.swift
//  DemoApp
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit

/// 空状态视图
/// 用于显示列表为空时的提示信息
class EmptyStateView: UIView {

    // MARK: - UI Components

    private let containerView: UIView = {
        let view = UIView()
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
        label.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        label.textColor = UIColor.label
        label.textAlignment = .center
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = UIColor.secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let actionButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.layer.cornerRadius = 8
        button.backgroundColor = UIColor.systemBlue
        button.setTitleColor(.white, for: .normal)
        return button
    }()

    // MARK: - Properties

    var onActionTap: (() -> Void)?

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
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

    func configure(icon: String? = nil, title: String, description: String, actionTitle: String? = nil) {
        if let icon = icon {
            iconImageView.image = UIImage(systemName: icon)
            iconImageView.isHidden = false
        } else {
            iconImageView.isHidden = true
        }

        titleLabel.text = title
        descriptionLabel.text = description

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
