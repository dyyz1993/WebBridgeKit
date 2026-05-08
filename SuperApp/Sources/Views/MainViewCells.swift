//
//  MainViewCells.swift
//  SuperApp
//
//  Extracted from MainViewController.swift
//

import UIKit
import SnapKit
import WebBridgeKit

// MARK: - PushTokenCardCell

class PushTokenCardCell: UICollectionViewCell {
    static let identifier = "PushTokenCardCell"

    private let gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [
            ThemeColors.current.primary.withAlphaComponent(0.8).cgColor,
            ThemeTokens.Colors.Light.primary.withAlphaComponent(0.6).cgColor
        ]
        layer.startPoint = CGPoint(x: 0, y: 0)
        layer.endPoint = CGPoint(x: 1, y: 1)
        layer.cornerRadius = ThemeTokens.CornerRadius.lg
        return layer
    }()

    private let containerView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = ThemeTokens.CornerRadius.lg
        view.layer.masksToBounds = true
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.footnote
        label.textColor = .white.withAlphaComponent(0.9)
        label.text = "Push Token"
        return label
    }()

    private let urlLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        label.textColor = .white.withAlphaComponent(0.85)
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()

    private let tokenLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        label.textColor = .white.withAlphaComponent(0.7)
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()

    private let copyButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        button.setImage(UIImage(systemName: "doc.on.doc", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        button.layer.cornerRadius = ThemeTokens.CornerRadius.lg
        return button
    }()

    private let registerButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(L10n.tr("home.token_card.register"), for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        button.tintColor = .white
        button.backgroundColor = UIColor.white.withAlphaComponent(0.25)
        button.layer.cornerRadius = ThemeTokens.CornerRadius.lg
        button.isHidden = true
        return button
    }()

    var onCopyTapped: (() -> Void)?
    var onRegisterTapped: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = containerView.bounds
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onCopyTapped = nil
        onRegisterTapped = nil
    }

    private func setupUI() {
        contentView.addSubview(containerView)
        containerView.layer.insertSublayer(gradientLayer, at: 0)
        containerView.addSubview(titleLabel)
        containerView.addSubview(urlLabel)
        containerView.addSubview(tokenLabel)
        containerView.addSubview(copyButton)
        containerView.addSubview(registerButton)

        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(4)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.left.equalToSuperview().offset(16)
        }

        urlLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.left.equalToSuperview().offset(16)
            make.right.equalTo(copyButton.snp.left).offset(-12)
        }

        tokenLabel.snp.makeConstraints { make in
            make.top.equalTo(urlLabel.snp.bottom).offset(4)
            make.left.equalToSuperview().offset(16)
            make.right.equalTo(copyButton.snp.left).offset(-12)
            make.bottom.equalToSuperview().offset(-16)
        }

        copyButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(32)
        }

        registerButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.equalTo(56)
            make.height.equalTo(28)
        }

        copyButton.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)
        registerButton.addTarget(self, action: #selector(registerTapped), for: .touchUpInside)
    }

    func configure(serverURL: String, deviceToken: String, isRegistered: Bool) {
        if isRegistered {
            urlLabel.text = serverURL
            tokenLabel.text = "Device: \(deviceToken.prefix(16))\(deviceToken.count > 16 ? "..." : "")"
            copyButton.isHidden = false
            registerButton.isHidden = true
        } else {
            urlLabel.text = serverURL
            tokenLabel.text = L10n.tr("home.token_card.not_registered")
            copyButton.isHidden = true
            registerButton.isHidden = false
        }
    }

    @objc private func copyTapped() {
        onCopyTapped?()
    }

    @objc private func registerTapped() {
        onRegisterTapped?()
    }
}

// MARK: - QuickActionCell

class QuickActionCell: UICollectionViewCell {
    static let identifier = "QuickActionCell"

    private let stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.distribution = .fillEqually
        sv.spacing = 8
        return sv
    }()

    var onActionTapped: ((Int) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onActionTapped = nil
    }

    private func setupUI() {
        contentView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func configure(actions: [(icon: String, title: String, color: UIColor)]) {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, action) in actions.enumerated() {
            let btn = createActionButton(icon: action.icon, title: action.title, color: action.color)
            btn.tag = index
            btn.addTarget(self, action: #selector(actionTapped(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(btn)
        }
    }

    private func createActionButton(icon: String, title: String, color: UIColor) -> UIButton {
        let button = UIButton(type: .system)
        button.backgroundColor = ThemeColors.current.cardBackground
        button.layer.cornerRadius = ThemeTokens.CornerRadius.md

        let iconView = UIImageView()
        iconView.image = UIImage(systemName: icon, withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .medium))
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = ThemeTokens.Typography.caption2
        titleLabel.textColor = color
        titleLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 4
        stack.isUserInteractionEnabled = false

        button.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.top.greaterThanOrEqualToSuperview().offset(8)
            make.bottom.lessThanOrEqualToSuperview().offset(-8)
            make.left.greaterThanOrEqualToSuperview().offset(4)
            make.right.lessThanOrEqualToSuperview().offset(-4)
        }

        return button
    }

    @objc private func actionTapped(_ sender: UIButton) {
        onActionTapped?(sender.tag)
    }
}

// MARK: - SectionHeaderView

class SectionHeaderView: UICollectionReusableView {
    static let identifier = "SectionHeader"

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.title3
        label.textColor = ThemeColors.current.text
        return label
    }()

    private let indicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeColors.current.primary
        view.layer.cornerRadius = ThemeTokens.CornerRadius.sm
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(indicatorView)
        addSubview(titleLabel)
        indicatorView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
            make.width.equalTo(4)
            make.height.equalTo(18)
        }
        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(indicatorView.snp.right).offset(10)
            make.centerY.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - CommandBannerView

class CommandBannerView: UIView {

    var onTap: (() -> Void)?
    var onDismiss: (() -> Void)?

    private let iconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = ThemeColors.current.primary
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        iv.image = UIImage(systemName: "link.badge.plus", withConfiguration: config)
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.subheadline
        label.textColor = ThemeColors.current.text
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let dismissButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        button.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: config), for: .normal)
        button.tintColor = ThemeTokens.Colors.Light.textTertiary
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = ThemeColors.current.primary.withAlphaComponent(0.1)
        layer.cornerRadius = ThemeTokens.CornerRadius.sm
        clipsToBounds = true

        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(dismissButton)

        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(20)
        }

        dismissButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-8)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(44)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(8)
            make.trailing.equalTo(dismissButton.snp.leading).offset(-4)
            make.centerY.equalToSuperview()
        }

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(bannerTapped))
        addGestureRecognizer(tapGesture)

        dismissButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
    }

    func configure(title: String) {
        titleLabel.text = L10n.tr("home.command.banner_format", title)
    }

    @objc private func bannerTapped() {
        onTap?()
    }

    @objc private func dismissTapped() {
        onDismiss?()
    }
}
