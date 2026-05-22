//
//  InboxViewController+Cells.swift
//  SuperApp
//
//  Inbox cell components extracted from InboxViewController.
//

import UIKit
import SnapKit
import WebBridgeKit

// MARK: - InboxMessageCellWrapper

class InboxMessageCellWrapper: UITableViewCell {

    static let identifier = "InboxMessageCellWrapper"

    private let messageCell: WBKMessageCell

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        messageCell = WBKMessageCell(title: "", body: "", style: .default)
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = ThemeTokens.Color.background
        selectionStyle = .none
        contentView.backgroundColor = ThemeTokens.Color.background
        accessibilityIdentifier = "InboxMessageCell"

        contentView.addSubview(messageCell)
        messageCell.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func configure(with message: StoredMessage) {
        messageCell.title = message.payload.title
        messageCell.body = message.payload.body
        messageCell.isRead = message.isRead

        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"
        messageCell.timestamp = timeFmt.string(from: message.receivedAt)

        let channel = message.payload.channel.uppercased()
        switch channel {
        case "APNS", "APN":
            messageCell.icon = .bell
        case "BARK":
            messageCell.icon = .volume
        case "BRIDGE":
            messageCell.icon = .globe
        default:
            messageCell.icon = .inbox
        }
    }
}

// MARK: - InboxGroupHeaderCell

class InboxGroupHeaderCell: UITableViewCell {

    static let identifier = "InboxGroupHeaderCell"

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeTokens.Color.surface
        view.layer.cornerRadius = ThemeTokens.CornerRadius.row
        let shadow = ThemeTokens.Shadows.card
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: shadow.offsetX, height: shadow.offsetY)
        view.layer.shadowRadius = shadow.radius
        view.layer.shadowOpacity = Float(shadow.opacity)
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.metadata
        label.textColor = ThemeTokens.Color.textSecondary
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let countLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.tabLabel
        label.textColor = ThemeTokens.Color.text
        label.textAlignment = .center
        return label
    }()

    private let countContainer: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeTokens.Color.primary.withAlphaComponent(ThemeTokens.Opacity.badgeFill)
        view.layer.cornerRadius = ThemeTokens.CornerRadius.xs
        return view
    }()

    private let chevronImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = LucideIcon.chevronDown.templateImage(pointSize: ThemeTokens.Icons.Sizes.xs)
        iv.tintColor = ThemeTokens.Color.textSecondary
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
        backgroundColor = ThemeTokens.Color.background
        selectionStyle = .none
        contentView.backgroundColor = ThemeTokens.Color.background

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        contentView.addGestureRecognizer(tapGesture)

        contentView.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(countContainer)
        countContainer.addSubview(countLabel)
        containerView.addSubview(chevronImageView)

        containerView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(ThemeTokens.Spacing.xxs)
            make.bottom.equalToSuperview().offset(-ThemeTokens.Spacing.xxs)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(44)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(ThemeTokens.Spacing.lg)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(countContainer.snp.leading).offset(-ThemeTokens.Spacing.sm)
        }

        countContainer.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(chevronImageView.snp.leading).offset(-ThemeTokens.Spacing.sm)
            make.height.equalTo(20)
        }

        countLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6))
        }

        chevronImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-ThemeTokens.Spacing.lg)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(ThemeTokens.Icons.Sizes.xs)
        }
    }

    func configure(title: String, count: Int, isExpanded: Bool, hasUnread: Bool = false) {
        titleLabel.text = title
        countLabel.text = "\(count)"
        countContainer.isHidden = count == 0
        titleLabel.font = hasUnread
            ? ThemeTokens.Typography.sectionTitle
            : ThemeTokens.Typography.metadata
        titleLabel.textColor = hasUnread
            ? ThemeTokens.Color.text
            : ThemeTokens.Color.textSecondary

        UIView.animate(withDuration: ThemeTokens.Animation.normal.duration) {
            self.chevronImageView.transform = isExpanded
                ? .identity
                : CGAffineTransform(rotationAngle: -.pi / 2)
        }
    }

    @objc private func handleTap() {
        onTap?()
    }
}
