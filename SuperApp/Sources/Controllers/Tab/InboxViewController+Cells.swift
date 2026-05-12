//
//  InboxViewController+Cells.swift
//  SuperApp
//
//  Inbox cell components extracted from InboxViewController.
//

import UIKit
import SnapKit
import WebBridgeKit

// MARK: - InboxGroupHeaderCell

class InboxGroupHeaderCell: UITableViewCell {

    static let identifier = "InboxGroupHeaderCell"

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.footnote
        label.textColor = ThemeColors.current.textSecondary
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let chevronImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = LucideIcon.chevronDown.templateImage(pointSize: 14)
        iv.tintColor = ThemeColors.current.textSecondary
        iv.contentMode = .scaleAspectFit
        iv.accessibilityLabel = "展开收起"
        return iv
    }()

    var onTap: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        contentView.backgroundColor = .clear

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        contentView.addGestureRecognizer(tapGesture)

        contentView.addSubview(titleLabel)
        contentView.addSubview(chevronImageView)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(4)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(chevronImageView.snp.leading).offset(-8)
        }

        chevronImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-4)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(14)
        }
    }

    func configure(title: String, isExpanded: Bool, hasUnread: Bool = false) {
        titleLabel.text = title
        chevronImageView.image = isExpanded
            ? LucideIcon.chevronDown.templateImage(pointSize: 14)
            : LucideIcon.chevronRight.templateImage(pointSize: 14)
    }

    @objc private func handleTap() {
        onTap?()
    }
}

// MARK: - InboxMessageCell

class InboxMessageCell: UITableViewCell {

    static let identifier = "InboxMessageCell"

    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeColors.current.cardBackground
        view.layer.cornerRadius = ThemeTokens.CornerRadius.lg
        let shadow = ThemeTokens.Shadows.Card
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: shadow.offsetX, height: shadow.offsetY)
        view.layer.shadowRadius = shadow.radius
        view.layer.shadowOpacity = Float(shadow.opacity)
        return view
    }()

    private let typeIconContainer: UIView = {
        let view = UIView()
        view.layer.cornerRadius = ThemeTokens.CornerRadius.md
        view.clipsToBounds = true
        return view
    }()

    private let typeIconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .white
        iv.accessibilityLabel = "消息类型图标"
        return iv
    }()

    private let unreadDot: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeTokens.Color.error
        view.layer.cornerRadius = ThemeTokens.CornerRadius.sm
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let sourceContainer: UIView = {
        let view = UIView()
        view.layer.cornerRadius = ThemeTokens.CornerRadius.sm
        view.clipsToBounds = true
        return view
    }()

    private let sourceLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 10, weight: .bold)
        label.numberOfLines = 1
        return label
    }()

    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.caption2
        label.textColor = ThemeColors.current.textSecondary
        return label
    }()

    private let bodyLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = ThemeColors.current.textSecondary
        label.numberOfLines = 2
        return label
    }()

    private let chevronImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = LucideIcon.chevronRight.image(pointSize: 16, weight: .medium)
        iv.tintColor = ThemeTokens.Color.textTertiary
        iv.contentMode = .scaleAspectFit
        iv.accessibilityLabel = "查看详情"
        return iv
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(cardView)
        cardView.addSubview(typeIconContainer)
        typeIconContainer.addSubview(typeIconView)
        cardView.addSubview(unreadDot)
        cardView.addSubview(titleLabel)
        cardView.addSubview(bodyLabel)
        cardView.addSubview(sourceContainer)
        sourceContainer.addSubview(sourceLabel)
        cardView.addSubview(timeLabel)
        cardView.addSubview(chevronImageView)

        cardView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(2)
            make.bottom.equalToSuperview().offset(-2)
            make.leading.trailing.equalToSuperview()
        }

        typeIconContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.top.equalToSuperview().offset(12)
            make.width.height.equalTo(40)
        }

        typeIconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(20)
        }

        unreadDot.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.trailing.equalToSuperview().offset(-12)
            make.width.height.equalTo(10)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(typeIconContainer.snp.trailing).offset(12)
            make.top.equalToSuperview().offset(12)
            make.trailing.lessThanOrEqualTo(chevronImageView.snp.leading).offset(-8)
        }

        bodyLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.trailing.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
        }

        sourceContainer.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(bodyLabel.snp.bottom).offset(4)
            make.bottom.equalToSuperview().offset(-12)
        }

        sourceLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 1, left: 6, bottom: 1, right: 6))
        }

        timeLabel.snp.makeConstraints { make in
            make.leading.equalTo(sourceContainer.snp.trailing).offset(6)
            make.centerY.equalTo(sourceContainer)
        }

        chevronImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }
    }

    func configure(with message: StoredMessage) {
        titleLabel.text = message.payload.title
        bodyLabel.text = message.payload.body

        let isUnread = !message.isRead
        titleLabel.font = isUnread
            ? ThemeTokens.Typography.subheadline
            : ThemeTokens.Typography.subheadline
        unreadDot.alpha = isUnread ? 1 : 0

        let channel = message.payload.channel.uppercased()
        sourceLabel.text = channel

        let primaryColor = ThemeTokens.Color.primary
        let accentColor = ThemeTokens.Color.success
        let warningColor = ThemeTokens.Color.warning
        let grayColor = ThemeTokens.Color.textSecondary

        switch channel {
        case "APNS", "APN":
            typeIconContainer.backgroundColor = primaryColor.withAlphaComponent(0.12)
            typeIconView.tintColor = primaryColor
            typeIconView.image = UIImage(lucideId: "package") ?? LucideIcon.appFill.image(pointSize: 20)
            sourceContainer.backgroundColor = primaryColor.withAlphaComponent(0.12)
            sourceLabel.textColor = primaryColor
        case "BARK":
            typeIconContainer.backgroundColor = accentColor.withAlphaComponent(0.12)
            typeIconView.tintColor = accentColor
            typeIconView.image = LucideIcon.link.templateImage(pointSize: 20)
            sourceContainer.backgroundColor = accentColor.withAlphaComponent(0.12)
            sourceLabel.textColor = accentColor
        case "BRIDGE":
            typeIconContainer.backgroundColor = warningColor.withAlphaComponent(0.12)
            typeIconView.tintColor = warningColor
            typeIconView.image = LucideIcon.bell.templateImage(pointSize: 20)
            sourceContainer.backgroundColor = warningColor.withAlphaComponent(0.12)
            sourceLabel.textColor = warningColor
        case "SYSTEM", "LOCAL":
            typeIconContainer.backgroundColor = grayColor.withAlphaComponent(0.12)
            typeIconView.tintColor = grayColor
            typeIconView.image = LucideIcon.settings.templateImage(pointSize: 20)
            sourceContainer.backgroundColor = grayColor.withAlphaComponent(0.12)
            sourceLabel.textColor = grayColor
        default:
            typeIconContainer.backgroundColor = grayColor.withAlphaComponent(0.12)
            typeIconView.tintColor = grayColor
            typeIconView.image = LucideIcon.settings.templateImage(pointSize: 20)
            sourceContainer.backgroundColor = grayColor.withAlphaComponent(0.12)
            sourceLabel.textColor = grayColor
        }

        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"
        timeLabel.text = timeFmt.string(from: message.receivedAt)
    }
}

// MARK: - InboxEmptyStateView

class InboxEmptyStateView: UIView {

    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = ThemeTokens.Color.textTertiary
        iv.accessibilityLabel = "空收件箱"
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.title3
        label.textColor = ThemeColors.current.text
        label.textAlignment = .center
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.subheadline
        label.textColor = ThemeColors.current.textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .clear
        accessibilityIdentifier = "InboxEmptyStateView"

        addSubview(iconImageView)
        addSubview(titleLabel)
        addSubview(subtitleLabel)

        iconImageView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.width.height.equalTo(80)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconImageView.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview()
        }

        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }

    func configure(iconName: String, title: String, subtitle: String) {
        let config = UIImage.SymbolConfiguration(pointSize: 36, weight: .light)
        iconImageView.image = UIImage(systemName: iconName, withConfiguration: config)
        titleLabel.text = title
        subtitleLabel.text = subtitle
    }
}
