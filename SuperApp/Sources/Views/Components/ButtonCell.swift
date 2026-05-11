//
//  ButtonCell.swift
//  SuperApp
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit
import WebBridgeKit

/// 按钮列表项单元格
class ButtonCell: UITableViewCell {

    static let identifier = "ButtonCell"

    // MARK: - Button Types

    enum ButtonType {
        case test  // 测试连接 (蓝色)
        case save  // 保存 (绿色)
        case reset // 重置 (红色)

        var title: String {
            switch self {
            case .test: return "测试连接"
            case .save: return "保存配置"
            case .reset: return "重置默认"
            }
        }

        var color: UIColor {
            switch self {
            case .test: return ThemeColors.current.primary
            case .save: return ThemeTokens.Color.success
            case .reset: return ThemeTokens.Color.error
            }
        }

        var backgroundColor: UIColor {
            switch self {
            case .test: return ThemeColors.current.primary.withAlphaComponent(0.1)
            case .save: return ThemeTokens.Color.success.withAlphaComponent(0.1)
            case .reset: return ThemeTokens.Color.error.withAlphaComponent(0.1)
            }
        }
    }

    // MARK: - UI Components

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.callout
        label.textColor = ThemeColors.current.text
        return label
    }()

    private let actionButton: UIButton = {
        let button: UIButton
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
            button = UIButton(configuration: config)
        } else {
            button = UIButton(type: .system)
            button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        }
        button.titleLabel?.font = ThemeTokens.Typography.callout
        button.layer.cornerRadius = ThemeTokens.CornerRadius.sm
        button.clipsToBounds = true
        return button
    }()

    // MARK: - Properties

    private var buttonType: ButtonType = .test
    var onButtonTap: (() -> Void)?

    // MARK: - Initialization

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        selectionStyle = .none
        backgroundColor = ThemeColors.current.background

        contentView.addSubview(titleLabel)
        contentView.addSubview(actionButton)

        titleLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
        }

        actionButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.height.equalTo(36)
        }

        actionButton.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
    }

    // MARK: - Configure

    func configure(title: String, buttonType: ButtonType, enabled: Bool = true) {
        self.buttonType = buttonType

        titleLabel.text = title
        actionButton.setTitle(buttonType.title, for: .normal)
        actionButton.isEnabled = enabled

        if enabled {
            actionButton.setTitleColor(buttonType.color, for: .normal)
            actionButton.backgroundColor = buttonType.backgroundColor
        } else {
            actionButton.setTitleColor(ThemeTokens.Color.textTertiary, for: .normal)
            actionButton.backgroundColor = ThemeColors.current.surface
        }
    }

    // MARK: - Actions

    @objc private func buttonTapped() {
        onButtonTap?()

        // Add button feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    // MARK: - Public Methods

    func setEnabled(_ enabled: Bool) {
        actionButton.isEnabled = enabled
        if enabled {
            actionButton.setTitleColor(buttonType.color, for: .normal)
            actionButton.backgroundColor = buttonType.backgroundColor
        } else {
            actionButton.setTitleColor(ThemeTokens.Color.textTertiary, for: .normal)
            actionButton.backgroundColor = ThemeColors.current.surface
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        buttonType = .test
        titleLabel.text = ""
        onButtonTap = nil
    }
}
