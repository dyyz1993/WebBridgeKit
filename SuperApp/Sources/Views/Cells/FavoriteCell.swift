//
//  FavoriteCell.swift
//  SuperApp
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit
import WebBridgeKit

/// 收藏列表单元格
/// S4: single-row card — icon, title (📌 marks legacy pinned items), domain.
/// The per-item 缓存模式 switch, decorative star, and the pin toggle (置顶 has
/// no visible outlet in Drel) were removed; removing a favorite stays
/// available via the trailing swipe action.
class FavoriteCell: UITableViewCell {

    static let identifier = "FavoriteCell"

    // MARK: - UI Components

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeTokens.Color.cardBackground
        view.layer.cornerRadius = ThemeTokens.CornerRadius.lg
        view.layer.masksToBounds = true
        return view
    }()

    private let faviconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = ThemeTokens.Color.primary
        imageView.backgroundColor = ThemeTokens.Color.surface
        imageView.layer.cornerRadius = ThemeTokens.CornerRadius.md
        imageView.layer.masksToBounds = true
        imageView.clipsToBounds = true
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.callout
        label.textColor = ThemeTokens.Color.text
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let urlLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.footnote
        label.textColor = ThemeTokens.Color.textSecondary
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()

    // MARK: - Properties

    private var currentFavorite: URLFavorite?

    var favorite: URLFavorite? {
        didSet {
            currentFavorite = favorite
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
        // 确保cell背景透明，避免白色遮挡
        contentView.backgroundColor = .clear
        backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(containerView)
        containerView.addSubview(faviconImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(urlLabel)

        containerView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(6)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.bottom.equalToSuperview().offset(-6)
        }

        faviconImageView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(44)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.left.equalTo(faviconImageView.snp.right).offset(12)
            make.right.equalToSuperview().offset(-14)
        }

        urlLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.left.equalTo(faviconImageView.snp.right).offset(12)
            make.right.equalToSuperview().offset(-14)
            make.bottom.equalToSuperview().offset(-16)
        }

    }

    // MARK: - Update UI

    private func updateUI() {
        guard let favorite = currentFavorite else {
            titleLabel.text = ""
            urlLabel.text = ""
            faviconImageView.image = nil
            return
        }

        // 设置标题（置顶以📌标注，与列表单行卡片约定一致）
        let baseTitle = favorite.title ?? L10n.tr("favorite.unknown_page")
        titleLabel.text = favorite.isPinned ? "📌 " + baseTitle : baseTitle

        // 设置 URL
        if let url = URL(string: favorite.url) {
            urlLabel.text = url.host ?? favorite.url
        } else {
            urlLabel.text = favorite.url
        }

        // 设置图标
        if let favicon = favorite.favicon, let image = UIImage(data: favicon) {
            faviconImageView.image = image
            faviconImageView.backgroundColor = .clear
        } else {
            // 使用首字母图标
            faviconImageView.setLetterIcon(for: favorite.title ?? favorite.url, size: CGSize(width: 40, height: 40))
        }

    }

    // MARK: - Actions

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        currentFavorite = nil
        faviconImageView.image = nil
        // 重置所有 UI 状态
        titleLabel.text = nil
        urlLabel.text = nil
        faviconImageView.backgroundColor = ThemeTokens.Color.surface
    }
}
