//
//  URLGridCell.swift
//  SuperApp
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
        view.backgroundColor = .secondarySystemGroupedBackground
        view.layer.cornerRadius = 24
        // 添加精致阴影
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 8)
        view.layer.shadowRadius = 16
        view.layer.shadowOpacity = 0.08
        return view
    }()

    private let contentClipView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 24
        view.layer.masksToBounds = true
        return view
    }()

    private let glassEffectView: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .systemThinMaterial)
        let view = UIVisualEffectView(effect: blur)
        view.layer.cornerRadius = 24
        view.layer.masksToBounds = true
        view.isHidden = true // 仅在特定状态显示
        
        // 添加磨砂边框效果
        view.layer.borderWidth = 0.5
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        return view
    }()

    private let faviconContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBackground
        view.layer.cornerRadius = 20
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 8
        view.layer.shadowOpacity = 0.05
        return view
    }()

    private let faviconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 16
        imageView.layer.masksToBounds = true
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.textColor = UIColor.label
        label.textAlignment = .center
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail // 尾部截断
        return label
    }()

    private let urlLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 10, weight: .regular)
        label.textColor = UIColor.tertiaryLabel
        label.textAlignment = .center
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingMiddle // 中间截断（更适合 URL）
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

    private let lastVisitedLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 9, weight: .regular)
        label.textColor = UIColor.quaternaryLabel
        label.textAlignment = .center
        return label
    }()

    private let appIdLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 9, weight: .bold)
        label.textColor = UIColor.systemIndigo
        label.textAlignment = .center
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let appIdBadgeView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemIndigo.withAlphaComponent(0.1)
        view.layer.cornerRadius = 4
        view.isHidden = true
        return view
    }()

    private let actionStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 6
        stack.distribution = .fillEqually
        return stack
    }()

    // MARK: - Properties
    
    private var currentHistory: WebPageHistory?

    var onPinToggle: (() -> Void)?
    var onFavoriteToggle: (() -> Void)?

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

    // MARK: - Actions

    @objc private func pinTapped() {
        onPinToggle?()
    }

    @objc private func favoriteTapped() {
        onFavoriteToggle?()
    }

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)

        // 关键修复：在初始化时就确保所有视图都是透明/隐藏的
        contentView.backgroundColor = .clear
        backgroundColor = .clear
        containerView.isHidden = true
        containerView.alpha = 0  // 同时设置 alpha 确保绝对不显示

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
        containerView.alpha = 0  // 重置 alpha
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
        contentView.backgroundColor = .clear
        backgroundColor = .clear

        contentView.addSubview(containerView)
        containerView.addSubview(contentClipView)
        
        contentClipView.addSubview(glassEffectView)
        contentClipView.addSubview(faviconContainer)
        faviconContainer.addSubview(faviconImageView)
        
        contentClipView.addSubview(actionStackView)
        actionStackView.addArrangedSubview(pinIconView)
        actionStackView.addArrangedSubview(favoriteIconView)
        
        contentClipView.addSubview(cachedBadgeView)
        contentClipView.addSubview(titleLabel)
        contentClipView.addSubview(urlLabel)
        contentClipView.addSubview(sizeLabel)
        contentClipView.addSubview(lastVisitedLabel)
        contentClipView.addSubview(modeBadgeView)
        modeBadgeView.addSubview(modeLabel)
        
        contentClipView.addSubview(appIdBadgeView)
        appIdBadgeView.addSubview(appIdLabel)

        cachedBadgeView.addSubview(cachedLabel)

        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(6)
        }

        contentClipView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        glassEffectView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        faviconContainer.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(56)
        }

        faviconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(52)
        }

        actionStackView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.right.equalToSuperview().offset(-12)
        }

        pinIconView.snp.makeConstraints { make in
            make.width.height.equalTo(22)
        }

        favoriteIconView.snp.makeConstraints { make in
            make.width.height.equalTo(22)
        }

        cachedBadgeView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.left.equalToSuperview().offset(12)
            make.height.equalTo(18)
        }

        cachedLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 6, bottom: 0, right: 6))
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(faviconContainer.snp.bottom).offset(12)
            make.left.equalToSuperview().offset(12)
            make.right.equalToSuperview().offset(-12)
        }

        urlLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.left.equalToSuperview().offset(12)
            make.right.equalToSuperview().offset(-12)
        }

        lastVisitedLabel.snp.makeConstraints { make in
            make.top.equalTo(urlLabel.snp.bottom).offset(6)
            make.left.right.equalTo(urlLabel)
        }

        sizeLabel.snp.makeConstraints { make in
            make.bottom.equalToSuperview().offset(-12)
            make.left.equalToSuperview().offset(12)
        }

        appIdBadgeView.snp.makeConstraints { make in
            make.bottom.equalToSuperview().offset(-12)
            make.centerX.equalToSuperview()
            make.height.equalTo(14)
            make.left.greaterThanOrEqualTo(sizeLabel.snp.right).offset(4)
            make.right.lessThanOrEqualTo(modeBadgeView.snp.left).offset(-4)
        }

        appIdLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 4))
        }

        modeBadgeView.snp.makeConstraints { make in
            make.bottom.equalToSuperview().offset(-12)
            make.right.equalToSuperview().offset(-12)
            make.height.equalTo(14)
        }

        modeLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 4))
        }

        pinIconView.addTarget(self, action: #selector(pinTapped), for: .touchUpInside)
        favoriteIconView.addTarget(self, action: #selector(favoriteTapped), for: .touchUpInside)

        favoriteIconView.isHidden = false
        modeBadgeView.isHidden = true
    }

    // MARK: - Update UI

    private func updateUI() {
        guard let history = currentHistory else {
            // 如果没有数据，绝对不能显示 containerView
            containerView.isHidden = true
            containerView.alpha = 0
            return
        }

        // 只有在数据加载完成后，才在主线程显示内容
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.currentHistory?.url == history.url else { return }

            // 先显示容器，并执行渐显动画
            self.containerView.isHidden = false
            UIView.animate(withDuration: 0.2) {
                self.containerView.alpha = 1
            }

            // 动态背景
            if history.isPinned {
                self.containerView.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.05)
                self.glassEffectView.isHidden = false
            } else {
                self.containerView.backgroundColor = .secondarySystemGroupedBackground
                self.glassEffectView.isHidden = true
            }

            self.titleLabel.text = history.title ?? "未知页面"

            // 格式化上次访问时间
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            self.lastVisitedLabel.text = "最后访问: \(formatter.string(from: history.lastVisitDate))"

            if history.cachedSize > 0 {
                self.sizeLabel.text = history.formattedSize
                self.sizeLabel.isHidden = false
            } else {
                self.sizeLabel.isHidden = true
            }

            self.updateModeBadge(for: history)

            if let url = URL(string: history.url) {
                self.urlLabel.text = url.host ?? history.url

                // 解析 AppID 并显示
                let appId = AppIDResolver.resolveAppID(from: url)
                self.appIdLabel.text = "ID: \(appId)"
                self.appIdBadgeView.isHidden = false
            } else {
                self.urlLabel.text = history.url
                self.appIdBadgeView.isHidden = true
            }

            if let favicon = history.favicon, let image = UIImage(data: favicon) {
                self.faviconImageView.image = image
                self.faviconImageView.backgroundColor = .clear
            } else {
                self.faviconImageView.setLetterIcon(for: history.title ?? history.url, size: CGSize(width: 52, height: 52))
            }

            self.cachedBadgeView.isHidden = !history.isCached

            // 更新按钮状态
            let pinImage = history.isPinned ? "pin.fill" : "pin"
            self.pinIconView.setImage(UIImage(systemName: pinImage), for: .normal)
            self.pinIconView.tintColor = history.isPinned ? .systemOrange : .systemGray4
            self.pinIconView.backgroundColor = history.isPinned ? UIColor.systemOrange.withAlphaComponent(0.1) : .clear

            let favoriteImage = history.isFavorite ? "star.fill" : "star"
            self.favoriteIconView.setImage(UIImage(systemName: favoriteImage), for: .normal)
            self.favoriteIconView.tintColor = history.isFavorite ? .systemYellow : .systemGray4
            self.favoriteIconView.backgroundColor = history.isFavorite ? UIColor.systemYellow.withAlphaComponent(0.1) : .clear
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
