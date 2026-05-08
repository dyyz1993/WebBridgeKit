//
//  APIKeyCell.swift
//  SuperApp
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit
import WebBridgeKit

/// API 密钥列表单元格
class APIKeyCell: UITableViewCell {

    static let identifier = "APIKeyCell"

    // MARK: - UI Components

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeColors.current.cardBackground
        view.layer.cornerRadius = ThemeTokens.CornerRadius.lg
        view.layer.masksToBounds = true
        return view
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        imageView.image = UIImage(systemName: "key.fill", withConfiguration: config)
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = ThemeTokens.Colors.Light.primary
        imageView.backgroundColor = ThemeTokens.Colors.Light.primary.withAlphaComponent(0.1)
        imageView.layer.cornerRadius = ThemeTokens.CornerRadius.md
        imageView.layer.masksToBounds = true
        return imageView
    }()

    private let typeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textColor = ThemeColors.current.text
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let keyLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.footnote
        label.textColor = ThemeColors.current.textSecondary
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()

    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.caption1
        label.textColor = ThemeTokens.Colors.Light.textTertiary
        label.numberOfLines = 1
        return label
    }()

    private let statusBadge: UIView = {
        let view = UIView()
        view.layer.cornerRadius = ThemeTokens.CornerRadius.sm
        view.layer.masksToBounds = true
        return view
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.caption2
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    private let copyButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let image = UIImage(systemName: "doc.on.doc", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = ThemeTokens.Colors.Light.primary
        return button
    }()

    private let groupBadge: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeTokens.Colors.Light.primary.withAlphaComponent(ThemeTokens.Opacity.badge)
        view.layer.cornerRadius = ThemeTokens.CornerRadius.sm
        view.isHidden = true
        return view
    }()

    private let groupLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.caption2
        label.textColor = ThemeTokens.Colors.Light.primary
        return label
    }()

    // MARK: - Properties

    private var currentKey: APIKey?
    var onCopyTap: ((String) -> Void)?

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
        backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(containerView)
        containerView.addSubview(iconImageView)
        containerView.addSubview(typeLabel)
        containerView.addSubview(keyLabel)
        containerView.addSubview(dateLabel)
        containerView.addSubview(groupBadge)
        containerView.addSubview(statusBadge)
        containerView.addSubview(copyButton)

        statusBadge.addSubview(statusLabel)
        groupBadge.addSubview(groupLabel)

        containerView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.bottom.equalToSuperview().offset(-8)
        }

        iconImageView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(44)
        }

        typeLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.left.equalTo(iconImageView.snp.right).offset(12)
            make.right.equalTo(statusBadge.snp.left).offset(-8)
        }

        keyLabel.snp.makeConstraints { make in
            make.top.equalTo(typeLabel.snp.bottom).offset(4)
            make.left.equalTo(iconImageView.snp.right).offset(12)
            make.right.equalTo(copyButton.snp.left).offset(-8)
        }

        groupBadge.snp.makeConstraints { make in
            make.centerY.equalTo(dateLabel)
            make.left.equalTo(iconImageView.snp.right).offset(12)
            make.height.equalTo(16)
        }

        groupLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 4))
        }

        dateLabel.snp.makeConstraints { make in
            make.top.equalTo(keyLabel.snp.bottom).offset(4)
            make.left.equalTo(groupBadge.isHidden ? iconImageView.snp.right : groupBadge.snp.right).offset(groupBadge.isHidden ? 12 : 6)
            make.right.equalTo(copyButton.snp.left).offset(-8)
            make.bottom.equalToSuperview().offset(-12)
        }

        copyButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalToSuperview().offset(-12)
            make.width.height.equalTo(44)
        }

        statusBadge.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.right.equalTo(copyButton.snp.left).offset(-8)
            make.height.equalTo(20)
        }

        statusLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8))
        }

        copyButton.addTarget(self, action: #selector(copyButtonTapped), for: .touchUpInside)
    }

    // MARK: - Configure

    func configure(with key: APIKey, maskKey: Bool = true) {
        currentKey = key
        updateUI(maskKey: maskKey)
    }

    private func updateUI(maskKey: Bool) {
        guard let key = currentKey else {
            typeLabel.text = ""
            keyLabel.text = ""
            dateLabel.text = ""
            statusBadge.isHidden = true
            return
        }

        // 密钥类型
        if key.isPermanent {
            typeLabel.text = "永久密钥"
            iconImageView.tintColor = ThemeTokens.Colors.Light.success
            iconImageView.backgroundColor = ThemeTokens.Colors.Light.success.withAlphaComponent(0.1)
        } else {
            typeLabel.text = "临时密钥"
            iconImageView.tintColor = ThemeTokens.Colors.Light.primary
            iconImageView.backgroundColor = ThemeTokens.Colors.Light.primary.withAlphaComponent(0.1)
        }

        // 绑定群组
        if let groupId = key.boundGroupId, !groupId.isEmpty {
            groupBadge.isHidden = false
            groupLabel.text = "群组: \(groupId)"
        } else {
            groupBadge.isHidden = true
        }

        // 更新日期标签约束
        dateLabel.snp.remakeConstraints { make in
            make.top.equalTo(keyLabel.snp.bottom).offset(4)
            if !groupBadge.isHidden {
                make.left.equalTo(groupBadge.snp.right).offset(6)
            } else {
                make.left.equalTo(iconImageView.snp.right).offset(12)
            }
            make.right.equalTo(copyButton.snp.left).offset(-8)
            make.bottom.equalToSuperview().offset(-12)
        }

        // 密钥值
        if maskKey && key.isPermanent {
            keyLabel.text = key.maskedKey
        } else {
            keyLabel.text = key.keyValue
        }

        // 创建时间
        dateLabel.text = "创建于 \(key.formattedCreatedAt)"

        // 状态标签
        statusBadge.isHidden = false
        if key.isExpired {
            statusBadge.backgroundColor = ThemeTokens.Colors.Light.error
            statusLabel.text = "已过期"
        } else if key.isPermanent {
            statusBadge.backgroundColor = ThemeTokens.Colors.Light.success
            statusLabel.text = "永久有效"
        } else {
            statusBadge.backgroundColor = ThemeTokens.Colors.Light.warning
            statusLabel.text = key.remainingTimeText ?? "已过期"
        }
    }

    // MARK: - Actions

    @objc private func copyButtonTapped() {
        guard let key = currentKey else { return }
        onCopyTap?(key.keyValue)
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        currentKey = nil
        onCopyTap = nil
        typeLabel.text = ""
        keyLabel.text = ""
        dateLabel.text = ""
        statusBadge.isHidden = true
        statusLabel.text = ""
        groupBadge.isHidden = true
        groupLabel.text = ""
        iconImageView.tintColor = ThemeTokens.Colors.Light.primary
        iconImageView.backgroundColor = ThemeTokens.Colors.Light.primary.withAlphaComponent(0.1)
    }
}
