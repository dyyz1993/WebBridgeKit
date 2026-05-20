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

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeColors.current.cardBackground
        view.layer.cornerRadius = ThemeTokens.CornerRadius.xl
        let shadow = ThemeTokens.Shadows.Card
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: shadow.offsetX, height: shadow.offsetY)
        view.layer.shadowRadius = shadow.radius
        view.layer.shadowOpacity = Float(shadow.opacity)
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.footnote
        label.textColor = ThemeColors.current.textSecondary
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let countLabel: UILabel = {
        let label = UILabel()
        label.font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 11, weight: .medium))
        label.textColor = ThemeTokens.Color.text
        label.textAlignment = .center
        return label
    }()

    private let countContainer: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeTokens.Color.primary.withAlphaComponent(0.12)
        view.layer.cornerRadius = ThemeTokens.CornerRadius.sm
        return view
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

        contentView.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(countContainer)
        countContainer.addSubview(countLabel)
        containerView.addSubview(chevronImageView)

        containerView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(4)
            make.bottom.equalToSuperview().offset(-4)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(44)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(countContainer.snp.leading).offset(-8)
        }

        countContainer.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(chevronImageView.snp.leading).offset(-8)
            make.height.equalTo(20)
        }

        countLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6))
        }

        chevronImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(14)
        }
    }

    func configure(title: String, count: Int, isExpanded: Bool, hasUnread: Bool = false) {
        titleLabel.text = title
        countLabel.text = "\(count)"
        countContainer.isHidden = count == 0
        titleLabel.font = hasUnread
            ? ThemeTokens.Typography.headline
            : ThemeTokens.Typography.footnote
        titleLabel.textColor = hasUnread
            ? ThemeColors.current.text
            : ThemeColors.current.textSecondary

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

    private let unreadDot: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeTokens.Color.primary
        view.layer.cornerRadius = 5
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
        label.font = UIFontMetrics.default.scaledFont(for: UIFont.systemFont(ofSize: 10, weight: .bold))
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
        label.font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14))
        label.textColor = ThemeColors.current.textSecondary
        label.numberOfLines = 2
        return label
    }()

    private let chevronImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = LucideIcon.chevronRight.image(pointSize: 16, weight: .medium)
        iv.tintColor = ThemeTokens.Color.textSecondary
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
        cardView.addSubview(unreadDot)
        cardView.addSubview(titleLabel)
        cardView.addSubview(sourceContainer)
        sourceContainer.addSubview(sourceLabel)
        cardView.addSubview(bodyLabel)
        cardView.addSubview(timeLabel)
        cardView.addSubview(chevronImageView)

        cardView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(2)
            make.bottom.equalToSuperview().offset(-2)
            make.leading.trailing.equalToSuperview().inset(16)
        }

        unreadDot.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.top.equalToSuperview().offset(16)
            make.width.height.equalTo(10)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(unreadDot.snp.trailing).offset(8)
            make.top.equalToSuperview().offset(12)
            make.trailing.lessThanOrEqualTo(timeLabel.snp.leading).offset(-8)
        }

        timeLabel.snp.makeConstraints { make in
            make.trailing.equalTo(chevronImageView.snp.leading).offset(-4)
            make.top.equalToSuperview().offset(12)
        }

        chevronImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }

        bodyLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.trailing.equalTo(chevronImageView.snp.leading).offset(-8)
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
        }

        sourceContainer.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(bodyLabel.snp.bottom).offset(6)
            make.bottom.equalToSuperview().offset(-12)
        }

        sourceLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6))
        }
    }

    func configure(with message: StoredMessage) {
        titleLabel.text = message.payload.title
        bodyLabel.text = message.payload.body

        let isUnread = !message.isRead
        titleLabel.font = isUnread
            ? UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 15, weight: .semibold))
            : UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 15, weight: .regular))
        unreadDot.isHidden = !isUnread

        let channel = message.payload.channel.uppercased()
        sourceLabel.text = channel

        switch channel {
        case "APNS", "APN":
            sourceContainer.backgroundColor = ThemeTokens.Color.primary.withAlphaComponent(0.1)
            sourceLabel.textColor = ThemeTokens.Color.primary
        case "BARK":
            sourceContainer.backgroundColor = ThemeTokens.Color.success.withAlphaComponent(0.1)
            sourceLabel.textColor = ThemeTokens.Color.success
        case "BRIDGE":
            sourceContainer.backgroundColor = ThemeTokens.Color.warning.withAlphaComponent(0.1)
            sourceLabel.textColor = ThemeTokens.Color.warning
        case "SYSTEM", "LOCAL":
            sourceContainer.backgroundColor = ThemeTokens.Color.textSecondary.withAlphaComponent(0.1)
            sourceLabel.textColor = ThemeTokens.Color.textSecondary
        default:
            sourceContainer.backgroundColor = ThemeTokens.Color.textSecondary.withAlphaComponent(0.1)
            sourceLabel.textColor = ThemeTokens.Color.textSecondary
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
        iv.tintColor = ThemeTokens.Color.textSecondary
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
