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
        view.backgroundColor = ThemeColors.current.cardBackground
        view.layer.cornerRadius = 24
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
        view.backgroundColor = ThemeColors.current.surface
        view.layer.cornerRadius = ThemeTokens.CornerRadius.xxl
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 8
        view.layer.shadowOpacity = 0.05
        return view
    }()

    private let faviconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = ThemeTokens.CornerRadius.xl
        imageView.layer.masksToBounds = true
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.textColor = ThemeColors.current.text
        label.textAlignment = .center
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail // 尾部截断
        return label
    }()

    private let urlLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 10, weight: .regular)
        label.textColor = ThemeTokens.Colors.Light.textTertiary
        label.textAlignment = .center
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingMiddle // 中间截断（更适合 URL）
        return label
    }()

    private let pinIconView: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(LucideIcon.pin.templateImage(pointSize: 12, weight: .semibold), for: .normal)
        button.tintColor = ThemeColors.current.warning
        button.backgroundColor = ThemeColors.current.warning.withAlphaComponent(0.1)
        button.layer.cornerRadius = 9
        return button
    }()

    private let cachedBadgeView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = ThemeTokens.CornerRadius.md
        view.layer.masksToBounds = true
        return view
    }()

    private let cachedDotView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = ThemeTokens.CornerRadius.sm
        view.backgroundColor = ThemeColors.current.secondary
        return view
    }()

    private let cachedLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 9, weight: .medium)
        label.textColor = ThemeColors.current.success
        label.textAlignment = .center
        return label
    }()

    private let favoriteIconView: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        button.setImage(LucideIcon.star.templateImage(pointSize: 12, weight: .semibold), for: .normal)
        button.tintColor = ThemeTokens.Colors.Light.warning
        button.backgroundColor = ThemeTokens.Colors.Light.warning.withAlphaComponent(ThemeTokens.Opacity.badge)
        button.layer.cornerRadius = ThemeTokens.CornerRadius.md
        return button
    }()

    private let modeBadgeView: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeColors.current.primary.withAlphaComponent(0.1)
        view.layer.cornerRadius = ThemeTokens.CornerRadius.sm
        view.clipsToBounds = true
        return view
    }()

    private let modeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 8, weight: .bold)
        label.textColor = ThemeColors.current.primary
        return label
    }()

    private let sizeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedSystemFont(ofSize: 9, weight: .medium)
        label.textColor = ThemeColors.current.textSecondary
        label.textAlignment = .center
        return label
    }()

    private let lastVisitedLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 9, weight: .regular)
        label.textColor = ThemeTokens.Colors.Light.textTertiary
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
        view.layer.cornerRadius = ThemeTokens.CornerRadius.sm
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
        containerView.backgroundColor = ThemeColors.current.cardBackground

        // 重置所有 UI 状态
        titleLabel.text = nil
        urlLabel.text = nil
        pinIconView.isHidden = true
        cachedBadgeView.isHidden = true
        favoriteIconView.isHidden = true
        faviconImageView.backgroundColor = ThemeColors.current.surface
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
            self.containerView.backgroundColor = highlighted ? ThemeColors.current.surface : ThemeColors.current.cardBackground
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
        cachedBadgeView.addSubview(cachedDotView)
        cachedBadgeView.addSubview(cachedLabel)
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

        cachedDotView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(6)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(8)
        }

        cachedLabel.snp.makeConstraints { make in
            make.left.equalTo(cachedDotView.snp.right).offset(4)
            make.right.equalToSuperview().offset(-6)
            make.centerY.equalToSuperview()
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
            make.left.equalToSuperview().offset(12)
        }

        sizeLabel.snp.makeConstraints { make in
            make.top.equalTo(urlLabel.snp.bottom).offset(6)
            make.right.equalToSuperview().offset(-12)
            make.left.greaterThanOrEqualTo(lastVisitedLabel.snp.right).offset(8)
        }

        let bottomStack = UIStackView(arrangedSubviews: [appIdBadgeView, modeBadgeView])
        bottomStack.axis = .horizontal
        bottomStack.spacing = 6
        bottomStack.alignment = .trailing
        contentClipView.addSubview(bottomStack)

        bottomStack.snp.makeConstraints { make in
            make.bottom.equalToSuperview().offset(-10)
            make.right.equalToSuperview().offset(-12)
            make.height.equalTo(14)
        }

        appIdBadgeView.snp.removeConstraints()
        modeBadgeView.snp.removeConstraints()

        appIdLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 4))
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
                self.containerView.backgroundColor = ThemeTokens.Colors.Light.warning.withAlphaComponent(0.05)
                self.glassEffectView.isHidden = false
            } else {
                self.containerView.backgroundColor = ThemeColors.current.cardBackground
                self.glassEffectView.isHidden = true
            }

            self.titleLabel.text = history.title ?? (URL(string: history.url)?.host ?? history.url)

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

            self.cachedBadgeView.isHidden = false
            if history.isCached && history.cachedSize > 0 {
                self.cachedDotView.backgroundColor = ThemeTokens.Colors.Light.success
                self.cachedLabel.text = "离线可用"
                self.cachedLabel.textColor = ThemeTokens.Colors.Light.success
                self.cachedBadgeView.backgroundColor = ThemeTokens.Colors.Light.success.withAlphaComponent(ThemeTokens.Opacity.badge)
            } else if history.cachedSize > 0 {
                self.cachedDotView.backgroundColor = ThemeTokens.Colors.Light.warning
                self.cachedLabel.text = "需更新"
                self.cachedLabel.textColor = ThemeTokens.Colors.Light.warning
                self.cachedBadgeView.backgroundColor = ThemeTokens.Colors.Light.warning.withAlphaComponent(ThemeTokens.Opacity.badge)
            } else {
                self.cachedDotView.backgroundColor = ThemeColors.current.secondary
                self.cachedLabel.text = "未缓存"
                self.cachedLabel.textColor = ThemeColors.current.textSecondary
                self.cachedBadgeView.backgroundColor = ThemeColors.current.surface
            }

            // 更新按钮状态
            let pinImage = history.isPinned ? "pin.fill" : "pin"
            self.pinIconView.setImage(UIImage(systemName: pinImage), for: .normal)
            self.pinIconView.tintColor = history.isPinned ? ThemeTokens.Colors.Light.warning : ThemeTokens.Colors.Light.textTertiary
            self.pinIconView.backgroundColor = history.isPinned ? ThemeTokens.Colors.Light.warning.withAlphaComponent(0.1) : .clear

            let favoriteImage = history.isFavorite ? "star.fill" : "star"
            self.favoriteIconView.setImage(UIImage(systemName: favoriteImage), for: .normal)
            self.favoriteIconView.tintColor = history.isFavorite ? ThemeTokens.Colors.Light.warning : ThemeTokens.Colors.Light.textTertiary
            self.favoriteIconView.backgroundColor = history.isFavorite ? ThemeTokens.Colors.Light.warning.withAlphaComponent(ThemeTokens.Opacity.badge) : .clear
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
                    modeBadgeView.backgroundColor = ThemeTokens.Colors.Light.primary.withAlphaComponent(0.1)
                    modeLabel.textColor = ThemeTokens.Colors.Light.primary
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
