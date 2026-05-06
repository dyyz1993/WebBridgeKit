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
class FavoriteCell: UITableViewCell {

    static let identifier = "FavoriteCell"

    // MARK: - UI Components

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.secondarySystemBackground
        view.layer.cornerRadius = 12
        view.layer.masksToBounds = true
        return view
    }()

    private let faviconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = ThemeColors.current.primary
        imageView.backgroundColor = .tertiarySystemBackground
        imageView.layer.masksToBounds = true
        imageView.clipsToBounds = true
        return imageView
    }()

    private let titleLabel: UILabel = {
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

    private let pinButton: UIButton = {
        let button = UIButton(type: .system)
        let image = LucideIcon.pin.image(pointSize: 16)
        button.setImage(image, for: .normal)
        button.tintColor = ThemeColors.current.warning
        return button
    }()

    private let favoriteIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = LucideIcon.star.image(pointSize: 18)
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = UIColor.systemYellow
        return imageView
    }()

    private let cacheModeSwitch: UISwitch = {
        let switchControl = UISwitch()
        switchControl.isOn = false
        switchControl.tintColor = ThemeColors.current.success
        switchControl.onTintColor = ThemeColors.current.success
        return switchControl
    }()

    private let cacheModeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = UIColor.secondaryLabel
        label.text = "缓存模式"
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

    var onPinToggle: ((String) -> Void)?
    var onCacheModeToggle: ((String, Bool) -> Void)?

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
        containerView.addSubview(pinButton)
        containerView.addSubview(titleLabel)
        containerView.addSubview(urlLabel)
        containerView.addSubview(favoriteIconView)
        containerView.addSubview(cacheModeLabel)
        containerView.addSubview(cacheModeSwitch)

        containerView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.bottom.equalToSuperview().offset(-8)
        }

        faviconImageView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(44)
        }

        pinButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.right.equalToSuperview().offset(-12)
            make.width.height.equalTo(32)
        }

        favoriteIconView.snp.makeConstraints { make in
            make.bottom.equalToSuperview().offset(-8)
            make.right.equalToSuperview().offset(-12)
            make.width.height.equalTo(20)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.left.equalTo(faviconImageView.snp.right).offset(12)
            make.right.equalTo(pinButton.snp.left).offset(-8)
        }

        urlLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.left.equalTo(faviconImageView.snp.right).offset(12)
            make.right.equalTo(pinButton.snp.left).offset(-8)
        }

        cacheModeLabel.snp.makeConstraints { make in
            make.bottom.equalToSuperview().offset(-12)
            make.left.equalTo(faviconImageView.snp.right).offset(12)
        }

        cacheModeSwitch.snp.makeConstraints { make in
            make.centerY.equalTo(cacheModeLabel)
            make.left.equalTo(cacheModeLabel.snp.right).offset(8)
            make.right.lessThanOrEqualTo(favoriteIconView.snp.left).offset(-8)
        }

        // 添加按钮事件
        pinButton.addTarget(self, action: #selector(pinButtonTapped), for: .touchUpInside)
        cacheModeSwitch.addTarget(self, action: #selector(cacheModeSwitchChanged), for: .valueChanged)
    }

    // MARK: - Update UI

    private func updateUI() {
        guard let favorite = currentFavorite else {
            titleLabel.text = ""
            urlLabel.text = ""
            pinButton.isHidden = true
            favoriteIconView.isHidden = true
            faviconImageView.image = nil
            cacheModeSwitch.isOn = false
            return
        }

        // 设置标题
        titleLabel.text = favorite.title ?? "未知页面"

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

        // 置顶状态
        pinButton.isHidden = false
        pinButton.tintColor = favorite.isPinned ? ThemeColors.current.warning : .systemGray3

        // 收藏图标
        favoriteIconView.isHidden = false

        // 缓存模式
        cacheModeSwitch.isOn = favorite.enableCacheMode
    }

    // MARK: - Actions

    @objc private func pinButtonTapped() {
        guard let favorite = currentFavorite else { return }
        onPinToggle?(favorite.id)
    }

    @objc private func cacheModeSwitchChanged() {
        guard let favorite = currentFavorite else { return }
        onCacheModeToggle?(favorite.id, cacheModeSwitch.isOn)
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        currentFavorite = nil
        faviconImageView.image = nil
        onPinToggle = nil
        onCacheModeToggle = nil
        // 重置所有 UI 状态
        titleLabel.text = nil
        urlLabel.text = nil
        pinButton.isHidden = true
        favoriteIconView.isHidden = true
        cacheModeSwitch.isOn = false
        faviconImageView.backgroundColor = UIColor.tertiarySystemBackground
    }
}
