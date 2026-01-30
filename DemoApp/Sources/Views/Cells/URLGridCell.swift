//
//  URLGridCell.swift
//  DemoApp
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit
import WebBridgeKit

/// URL 宫格单元格
class URLGridCell: UICollectionViewCell {

    static let identifier = "URLGridCell"

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
        imageView.tintColor = UIColor.systemBlue
        imageView.backgroundColor = UIColor.tertiarySystemBackground
        imageView.layer.cornerRadius = 8
        imageView.layer.masksToBounds = true
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor.label
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()

    private let urlLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        label.textColor = UIColor.secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 1
        return label
    }()

    private let pinIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "pin.fill")
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = UIColor.systemOrange
        return imageView
    }()

    private let cachedBadgeView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemGreen
        view.layer.cornerRadius = 8
        view.layer.masksToBounds = true
        return view
    }()

    private let cachedLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        label.textColor = .white
        label.text = "已缓存"
        label.textAlignment = .center
        return label
    }()

    private let favoriteIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "star.fill")
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = UIColor.systemYellow
        return imageView
    }()

    // MARK: - Properties

    private var currentHistory: WebPageHistory?

    var history: WebPageHistory? {
        didSet {
            currentHistory = history
            updateUI()
        }
    }

    var isFavorite: Bool = false {
        didSet {
            updateFavoriteIcon()
        }
    }

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
        contentView.addSubview(containerView)
        containerView.addSubview(faviconImageView)
        containerView.addSubview(pinIconView)
        containerView.addSubview(cachedBadgeView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(urlLabel)
        containerView.addSubview(favoriteIconView)

        cachedBadgeView.addSubview(cachedLabel)

        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(4)
        }

        faviconImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(48)
        }

        pinIconView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.right.equalToSuperview().offset(-8)
            make.width.height.equalTo(16)
        }

        cachedBadgeView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.right.equalToSuperview()
            make.width.greaterThanOrEqualTo(44)
            make.height.equalTo(16)
        }

        cachedLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(4)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(faviconImageView.snp.bottom).offset(8)
            make.left.equalToSuperview().offset(8)
            make.right.equalToSuperview().offset(-8)
        }

        urlLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.left.equalToSuperview().offset(8)
            make.right.equalToSuperview().offset(-8)
            make.bottom.equalToSuperview().offset(-12)
        }

        favoriteIconView.snp.makeConstraints { make in
            make.bottom.equalToSuperview().offset(-8)
            make.right.equalToSuperview().offset(-8)
            make.width.height.equalTo(20)
        }

        favoriteIconView.isHidden = true
    }

    // MARK: - Update UI

    private func updateUI() {
        guard let history = currentHistory else {
            titleLabel.text = ""
            urlLabel.text = ""
            pinIconView.isHidden = true
            cachedBadgeView.isHidden = true
            favoriteIconView.isHidden = true
            faviconImageView.image = nil
            return
        }

        // 设置标题
        titleLabel.text = history.title ?? "未知页面"

        // 设置 URL
        if let url = URL(string: history.url) {
            urlLabel.text = url.host ?? history.url
        } else {
            urlLabel.text = history.url
        }

        // 设置图标
        if let favicon = history.favicon, let image = UIImage(data: favicon) {
            faviconImageView.image = image
            faviconImageView.backgroundColor = .clear
        } else {
            // 使用首字母图标
            faviconImageView.image = nil
            faviconImageView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        }

        // 缓存状态
        if history.isCached {
            cachedBadgeView.isHidden = false
            cachedLabel.text = "已缓存"
        } else {
            cachedBadgeView.isHidden = true
        }

        // 置顶状态
        pinIconView.isHidden = true

        // 收藏状态通过 isFavorite 属性单独设置
        updateFavoriteIcon()
    }

    private func updateFavoriteIcon() {
        favoriteIconView.isHidden = !isFavorite
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        currentHistory = nil
        faviconImageView.image = nil
        isFavorite = false
    }
}
