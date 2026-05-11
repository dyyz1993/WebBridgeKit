//
//  TokenCell.swift
//  SuperApp
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit
import WebBridgeKit

/// 口令列表单元格
class TokenCell: UITableViewCell {

    static let identifier = "TokenCell"

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
        imageView.image = LucideIcon.key.templateImage(pointSize: 20, weight: .medium)
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = ThemeTokens.Colors.Light.primary
        imageView.backgroundColor = ThemeTokens.Colors.Light.primary.withAlphaComponent(ThemeTokens.Opacity.badge)
        imageView.layer.cornerRadius = ThemeTokens.CornerRadius.md
        imageView.layer.masksToBounds = true
        return imageView
    }()

    private let tokenLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.callout
        label.textColor = ThemeColors.current.text
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()

    private let urlLabel: UILabel = {
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

    private let accessCountLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.caption2
        label.textColor = ThemeTokens.Colors.Light.textTertiary
        label.textAlignment = .right
        return label
    }()

    // MARK: - Properties

    private var currentToken: AccessToken?

    var token: AccessToken? {
        didSet {
            currentToken = token
            updateUI()
        }
    }

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
        containerView.addSubview(tokenLabel)
        containerView.addSubview(urlLabel)
        containerView.addSubview(dateLabel)
        containerView.addSubview(statusBadge)
        containerView.addSubview(accessCountLabel)

        statusBadge.addSubview(statusLabel)

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

        tokenLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.left.equalTo(iconImageView.snp.right).offset(12)
            make.right.equalTo(statusBadge.snp.left).offset(-8)
        }

        urlLabel.snp.makeConstraints { make in
            make.top.equalTo(tokenLabel.snp.bottom).offset(4)
            make.left.equalTo(iconImageView.snp.right).offset(12)
            make.right.equalToSuperview().offset(-12)
        }

        dateLabel.snp.makeConstraints { make in
            make.top.equalTo(urlLabel.snp.bottom).offset(4)
            make.left.equalTo(iconImageView.snp.right).offset(12)
            make.right.equalTo(accessCountLabel.snp.left).offset(-8)
        }

        accessCountLabel.snp.makeConstraints { make in
            make.centerY.equalTo(dateLabel)
            make.right.equalToSuperview().offset(-12)
        }

        statusBadge.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.right.equalToSuperview().offset(-12)
            make.height.equalTo(20)
        }

        statusLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8))
        }
    }

    // MARK: - Update UI

    private func updateUI() {
        guard let token = currentToken else {
            tokenLabel.text = ""
            urlLabel.text = ""
            dateLabel.text = ""
            accessCountLabel.text = ""
            statusBadge.isHidden = true
            return
        }

        // 口令码
        tokenLabel.text = token.token

        // URL
        if let url = URL(string: token.url) {
            urlLabel.text = url.host ?? token.url
        } else {
            urlLabel.text = token.url
        }

        // 创建时间
        dateLabel.text = "创建于 \(token.formattedCreatedAt)"

        // 访问次数
        accessCountLabel.text = "访问 \(token.accessCount) 次"

        // 状态标签
        statusBadge.isHidden = false
        if token.isExpired {
            statusBadge.backgroundColor = ThemeTokens.Colors.Light.error
            statusLabel.text = "已过期"
        } else if token.isPermanent {
            statusBadge.backgroundColor = ThemeTokens.Colors.Light.success
            statusLabel.text = "永久"
        } else {
            statusBadge.backgroundColor = ThemeTokens.Colors.Light.primary
            statusLabel.text = "剩余 \(token.remainingTimeText)"
        }
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        currentToken = nil
        tokenLabel.text = ""
        urlLabel.text = ""
        dateLabel.text = ""
        accessCountLabel.text = ""
        statusBadge.isHidden = true
        statusLabel.text = ""
        statusBadge.backgroundColor = .clear
    }
}
