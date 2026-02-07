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
        view.backgroundColor = UIColor.secondarySystemGroupedBackground
        view.layer.cornerRadius = 20
        // 添加阴影效果
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 8
        view.layer.shadowOpacity = 0.1
        view.layer.masksToBounds = false
        view.isHidden = false
        return view
    }()

    private let faviconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.tintColor = UIColor.systemBlue
        imageView.backgroundColor = UIColor.tertiarySystemGroupedBackground
        imageView.layer.cornerRadius = 14
        imageView.layer.masksToBounds = true
        // 添加精致边框
        imageView.layer.borderWidth = 0.5
        imageView.layer.borderColor = UIColor.separator.cgColor
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.textColor = UIColor.label
        label.textAlignment = .center
        label.numberOfLines = 1
        return label
    }()

    private let urlLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 10, weight: .regular)
        label.textColor = UIColor.tertiaryLabel
        label.textAlignment = .center
        label.numberOfLines = 1
        return label
    }()

    private let pinIconView: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        button.setImage(UIImage(systemName: "pin.fill", withConfiguration: config), for: .normal)
        button.tintColor = UIColor.systemOrange
        button.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.1)
        button.layer.cornerRadius = 9
        return button
    }()

    private let cachedBadgeView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.15)
        view.layer.cornerRadius = 6
        view.layer.masksToBounds = true
        return view
    }()

    private let cachedLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 9, weight: .bold)
        label.textColor = UIColor.systemGreen
        label.text = "OFFLINE"
        label.textAlignment = .center
        return label
    }()

    private let favoriteIconView: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        button.setImage(UIImage(systemName: "star.fill", withConfiguration: config), for: .normal)
        button.tintColor = UIColor.systemYellow
        button.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.1)
        button.layer.cornerRadius = 9
        return button
    }()

    private let modeBadgeView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        view.layer.cornerRadius = 4
        view.clipsToBounds = true
        return view
    }()

    private let modeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 8, weight: .bold)
        label.textColor = UIColor.systemBlue
        return label
    }()

    private let sizeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedSystemFont(ofSize: 9, weight: .medium)
        label.textColor = UIColor.secondaryLabel
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

    var isFavorite: Bool = false {
        didSet {
            updateFavoriteIcon()
        }
    }

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)

        // 关键修复：在初始化时就确保所有视图都是透明/隐藏的
        contentView.backgroundColor = .clear
        backgroundColor = .clear
        containerView.isHidden = true

        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        currentHistory = nil
        faviconImageView.image = nil
        isFavorite = false

        // 彻底重置所有状态，避免显示空白白色面板
        contentView.backgroundColor = .clear
        backgroundColor = .clear
        containerView.isHidden = true
        containerView.backgroundColor = UIColor.secondarySystemBackground  // 重置为默认颜色

        // 重置所有 UI 状态
        titleLabel.text = nil
        urlLabel.text = nil
        pinIconView.isHidden = true
        cachedBadgeView.isHidden = true
        favoriteIconView.isHidden = true
        faviconImageView.backgroundColor = UIColor.tertiarySystemBackground
    }

    // MARK: - Interaction
    
    var onPinToggle: (() -> Void)?
    var onFavoriteToggle: (() -> Void)?

    override var isHighlighted: Bool {
        didSet {
            animateSelection(isHighlighted)
        }
    }
    
    private func animateSelection(_ highlighted: Bool) {
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [.allowUserInteraction, .beginFromCurrentState], animations: {
            self.containerView.transform = highlighted ? CGAffineTransform(scaleX: 0.94, y: 0.94) : .identity
            self.containerView.backgroundColor = highlighted ? UIColor.tertiarySystemGroupedBackground : UIColor.secondarySystemGroupedBackground
            self.containerView.layer.shadowOpacity = highlighted ? 0.05 : 0.1
        }, completion: nil)
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // 确保contentView背景透明，避免白色遮挡
        contentView.backgroundColor = .clear
        backgroundColor = .clear

        contentView.addSubview(containerView)
        containerView.addSubview(faviconImageView)
        containerView.addSubview(pinIconView)
        containerView.addSubview(cachedBadgeView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(urlLabel)
        containerView.addSubview(favoriteIconView)
        containerView.addSubview(sizeLabel)
        containerView.addSubview(modeBadgeView)
        modeBadgeView.addSubview(modeLabel)

        cachedBadgeView.addSubview(cachedLabel)

        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(6)
        }

        faviconImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(52)
        }

        pinIconView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.right.equalToSuperview().offset(-10)
            make.width.height.equalTo(18)
        }

        cachedBadgeView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.left.equalToSuperview().offset(10)
            make.height.equalTo(18)
            make.width.greaterThanOrEqualTo(50)
        }

        cachedLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 6, bottom: 0, right: 6))
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(faviconImageView.snp.bottom).offset(12)
            make.left.equalToSuperview().offset(10)
            make.right.equalToSuperview().offset(-10)
        }

        urlLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.left.equalToSuperview().offset(10)
            make.right.equalToSuperview().offset(-10)
        }

        sizeLabel.snp.makeConstraints { make in
            make.bottom.equalToSuperview().offset(-12)
            make.left.equalToSuperview().offset(10)
        }

        modeBadgeView.snp.makeConstraints { make in
            make.bottom.equalToSuperview().offset(-12)
            make.right.equalToSuperview().offset(-10)
            make.height.equalTo(14)
        }

        modeLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 4))
        }

        favoriteIconView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.right.equalToSuperview().offset(-10)
            make.width.height.equalTo(18)
        }

        pinIconView.addTarget(self, action: #selector(pinTapped), for: .touchUpInside)
        favoriteIconView.addTarget(self, action: #selector(favoriteTapped), for: .touchUpInside)

        favoriteIconView.isHidden = true
        modeBadgeView.isHidden = true
    }

    @objc private func pinTapped() {
        onPinToggle?()
    }

    @objc private func favoriteTapped() {
        onFavoriteToggle?()
    }

    // MARK: - Update UI

    private func updateUI() {
        guard let history = currentHistory else {
            // 没有数据时隐藏容器视图
            containerView.isHidden = true
            accessibilityIdentifier = nil
            titleLabel.text = ""
            urlLabel.text = ""
            pinIconView.isHidden = true
            cachedBadgeView.isHidden = true
            favoriteIconView.isHidden = true
            modeBadgeView.isHidden = true
            faviconImageView.image = nil
            return
        }

        // 有数据时显示容器视图
        containerView.isHidden = false
        containerView.backgroundColor = UIColor.secondarySystemBackground

        // Set accessibility identifier for testing
        accessibilityIdentifier = "history.cell.\(history.id)"

        // 设置标题
        titleLabel.text = history.title ?? "未知页面"

        // 设置缓存大小
        if history.cachedSize > 0 {
            sizeLabel.text = history.formattedSize
            sizeLabel.isHidden = false
        } else {
            sizeLabel.text = nil
            sizeLabel.isHidden = true
        }

        // 设置加载模式
        updateModeBadge(for: history)

        // 设置 URL
        if let url = URL(string: history.url) {
            let host = url.host ?? ""
            if host == "localhost" {
                urlLabel.text = ""
            } else {
                urlLabel.text = host
            }
        } else {
            urlLabel.text = history.url
        }

        // 设置图标
        if let favicon = history.favicon, let image = UIImage(data: favicon) {
            faviconImageView.image = image
            faviconImageView.backgroundColor = .clear
        } else {
            // 使用首字母图标
            faviconImageView.setLetterIcon(for: history.title ?? history.url, size: CGSize(width: 52, height: 52))
        }

        // 缓存状态
        if history.isCached {
            cachedBadgeView.isHidden = false
            cachedLabel.text = "OFFLINE"
        } else {
            cachedBadgeView.isHidden = true
        }

        // 置顶状态
        let pinImage = history.isPinned ? "pin.fill" : "pin"
        pinIconView.setImage(UIImage(systemName: pinImage, withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold)), for: .normal)
        pinIconView.tintColor = history.isPinned ? UIColor.systemOrange : UIColor.systemGray4
        pinIconView.backgroundColor = history.isPinned ? UIColor.systemOrange.withAlphaComponent(0.15) : UIColor.systemGray6.withAlphaComponent(0.5)
        pinIconView.isHidden = false // 始终显示以便点击
        
        // 收藏状态
        let favoriteImage = history.isFavorite ? "star.fill" : "star"
        favoriteIconView.setImage(UIImage(systemName: favoriteImage, withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold)), for: .normal)
        favoriteIconView.tintColor = history.isFavorite ? UIColor.systemYellow : UIColor.systemGray4
        favoriteIconView.backgroundColor = history.isFavorite ? UIColor.systemYellow.withAlphaComponent(0.15) : UIColor.systemGray6.withAlphaComponent(0.5)
        favoriteIconView.isHidden = false // 始终显示以便点击
        
        // 始终显示置顶和收藏，并并排排列
        favoriteIconView.snp.remakeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.right.equalToSuperview().offset(-10)
            make.width.height.equalTo(20)
        }
        
        pinIconView.snp.remakeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.right.equalTo(favoriteIconView.snp.left).offset(-6)
            make.width.height.equalTo(20)
        }
    }

    private func updateModeBadge(for history: WebPageHistory) {
        if let url = URL(string: history.url) {
            let cacheID = AppIDResolver.resolveAppID(from: url)
            if let manifest = ManifestStore.shared.getManifest(for: cacheID) {
                modeBadgeView.isHidden = false
                if manifest.persistent == true {
                    modeLabel.text = "PERSISTENT"
                    modeBadgeView.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.1)
                    modeLabel.textColor = UIColor.systemPurple
                } else {
                    modeLabel.text = "LAZY"
                    modeBadgeView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
                    modeLabel.textColor = UIColor.systemBlue
                }
                return
            }
        }
        modeBadgeView.isHidden = true
    }

    private func updateFavoriteIcon() {
        // 由于现在统一在 updateUI 中根据 history.isFavorite 处理，
        // 这里可以保持为空或者根据需要更新
    }
}
