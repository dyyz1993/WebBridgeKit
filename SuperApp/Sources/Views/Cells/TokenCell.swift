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
        view.backgroundColor = UIColor.secondarySystemBackground
        view.layer.cornerRadius = 12
        view.layer.masksToBounds = true
        return view
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        imageView.image = UIImage(systemName: "key.fill", withConfiguration: config)
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = UIColor.systemPurple
        imageView.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.1)
        imageView.layer.cornerRadius = 8
        imageView.layer.masksToBounds = true
        return imageView
    }()

    private let tokenLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textColor = UIColor.label
        label.numberOfLines = 1
        return label
    }()

    private let urlLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        label.textColor = UIColor.secondaryLabel
        label.numberOfLines = 1
        return label
    }()

    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor.tertiaryLabel
        label.numberOfLines = 1
        return label
    }()

    private let statusBadge: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 4
        view.layer.masksToBounds = true
        return view
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    private let accessCountLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        label.textColor = UIColor.tertiaryLabel
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
            statusBadge.backgroundColor = UIColor.systemRed
            statusLabel.text = "已过期"
        } else if token.isPermanent {
            statusBadge.backgroundColor = UIColor.systemGreen
            statusLabel.text = "永久"
        } else {
            statusBadge.backgroundColor = UIColor.systemBlue
            statusLabel.text = "剩余 \(token.remainingTimeText)"
        }
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        currentToken = nil
    }
}
