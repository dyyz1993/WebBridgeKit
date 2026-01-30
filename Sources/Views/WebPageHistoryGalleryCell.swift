//
//  WebPageHistoryGalleryCell.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-15.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import SnapKit
import UIKit

// Framework imports

/// 历史记录画册单元格
class WebPageHistoryGalleryCell: UICollectionViewCell {

    // MARK: - Reuse Identifier

    static let reuseIdentifier = "WebPageHistoryGalleryCell"

    // MARK: - UI Components

    /// 缩略图容器
    private let thumbnailContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = WKColor.background.secondary
        view.layer.cornerRadius = 12
        view.layer.masksToBounds = true
        return view
    }()

    /// 缩略图
    private let thumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = WKColor.background.secondary
        return imageView
    }()

    /// 网站首字母图标
    private let fallbackIconLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = WKColor.lightBlue.darken3
        label.layer.cornerRadius = 12
        label.layer.masksToBounds = true
        return label
    }()

    /// 缓存状态角标
    private let cacheBadgeView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        imageView.backgroundColor = UIColor.systemGreen
        imageView.layer.cornerRadius = 10
        imageView.layer.masksToBounds = true
        imageView.image = UIImage(systemName: "checkmark.circle.fill")
        return imageView
    }()

    /// 标题标签
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = WKColor.grey.darken4
        label.numberOfLines = 2
        label.textAlignment = .center
        return label
    }()

    /// URL 标签
    private let urlLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        label.textColor = WKColor.grey.base
        label.numberOfLines = 1
        label.textAlignment = .center
        return label
    }()

    // MARK: - Properties

    private var currentHistory: WebPageHistory?

    var history: WebPageHistory? {
        didSet {
            currentHistory = history
            updateUI()
        }
    }

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        contentView.addSubview(thumbnailContainerView)
        thumbnailContainerView.addSubview(thumbnailImageView)
        thumbnailContainerView.addSubview(fallbackIconLabel)
        thumbnailContainerView.addSubview(cacheBadgeView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(urlLabel)

        thumbnailContainerView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.left.right.equalToSuperview()
            make.height.equalTo(thumbnailContainerView.snp.width)
        }

        thumbnailImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        fallbackIconLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        cacheBadgeView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.right.equalToSuperview().offset(-8)
            make.width.height.equalTo(20)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(thumbnailContainerView.snp.bottom).offset(8)
            make.left.right.equalToSuperview().inset(4)
        }

        urlLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
            make.left.right.equalToSuperview().inset(4)
        }
    }

    // MARK: - Update UI

    private func updateUI() {
        guard let history = currentHistory else {
            titleLabel.text = ""
            urlLabel.text = ""
            thumbnailImageView.isHidden = true
            fallbackIconLabel.isHidden = true
            cacheBadgeView.isHidden = true
            return
        }

        // 设置标题
        titleLabel.text = history.title ?? URL(string: history.url)?.host

        // 设置 URL
        if let url = URL(string: history.url) {
            urlLabel.text = url.host
        } else {
            urlLabel.text = history.url
        }

        // 设置缩略图
        if let thumbnail = history.thumbnail, let image = UIImage(data: thumbnail) {
            thumbnailImageView.image = image
            thumbnailImageView.isHidden = false
            fallbackIconLabel.isHidden = true
        } else {
            // 显示首字母
            let firstLetter = (history.title ?? URL(string: history.url)?.host ?? "?").prefix(1).uppercased()
            fallbackIconLabel.text = String(firstLetter)
            fallbackIconLabel.backgroundColor = generateColor(for: String(firstLetter))
            thumbnailImageView.isHidden = true
            fallbackIconLabel.isHidden = false
        }

        // 设置缓存状态角标
        cacheBadgeView.isHidden = !history.isCached
    }

    // MARK: - Helper Methods

    private func generateColor(for letter: String) -> UIColor {
        let colors: [UIColor] = [
            WKColor.lightBlue.darken3,
            UIColor.systemGreen,
            UIColor.systemOrange,
            UIColor.systemPurple,
            UIColor.systemRed,
            UIColor.systemTeal
        ]

        let index = abs(letter.hashValue) % colors.count
        return colors[index]
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailImageView.image = nil
        currentHistory = nil
    }
}
