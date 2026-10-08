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
/// S4: single-row card — icon, title, domain; pinned items carry a Lucide
/// pin glyph before the title (same icon as the inbox cards). The per-item
/// 缓存模式 switch, decorative star, and the pin toggle (置顶 has
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

    /// 置顶标记：与收件箱卡片同款 Lucide pin 图标（主题色），
    /// 非置顶隐藏后标题自然回位。
    private let pinIconView: UIImageView = {
        let iv = UIImageView()
        iv.image = LucideIcon.pin.templateImage(pointSize: ThemeTokens.Icons.Sizes.xs)
        iv.tintColor = ThemeTokens.Color.primary
        iv.contentMode = .scaleAspectFit
        iv.isHidden = true
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.callout
        label.textColor = ThemeTokens.Color.text
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private lazy var titleRowStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [pinIconView, titleLabel])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 4
        return stack
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
        containerView.addSubview(titleRowStack)
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

        pinIconView.snp.makeConstraints { make in
            make.width.height.equalTo(ThemeTokens.Icons.Sizes.xs)
        }

        titleRowStack.snp.makeConstraints { make in
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

        // 标题（置顶以 pin 图标标注，见 pinIconView）
        titleLabel.text = favorite.title ?? L10n.tr("favorite.unknown_page")
        pinIconView.isHidden = !favorite.isPinned

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

        // UI 测试用运行时标识：置顶浮顶断言按 id 取行，禁止硬编码位置
        accessibilityIdentifier = "favorite.card.\(favorite.id)"
    }

    // MARK: - Actions

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        currentFavorite = nil
        faviconImageView.image = nil
        pinIconView.isHidden = true
        // 重置所有 UI 状态
        titleLabel.text = nil
        urlLabel.text = nil
        faviconImageView.backgroundColor = ThemeTokens.Color.surface
    }
}
