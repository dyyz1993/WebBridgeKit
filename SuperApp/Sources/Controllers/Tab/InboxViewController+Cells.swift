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

    private let cardView = UIView()
    private let iconContainer = UIView()
    private let iconImageView = UIImageView()
    private let unreadAccent = UIView()
    private let unreadDot = UIView()
    private let sourceLabel = UILabel()
    private let timestampLabel = UILabel()
    private let titleLabel = UILabel()
    private let previewLabel = UILabel()
    private let stateBadge = UILabel()
    private let chevronImageView = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Cancels any in-flight group-entrance animation so a cell reused while
    /// animating never renders with a stale alpha/transform. A collapsed
    /// row's cached identity must not leak into the next configuration.
    override func prepareForReuse() {
        super.prepareForReuse()
        contentView.layer.removeAllAnimations()
        contentView.alpha = 1
        contentView.transform = .identity
        collapsedIdentity = nil
    }

    private func setupUI() {
        backgroundColor = ThemeTokens.Color.background
        selectionStyle = .none
        contentView.backgroundColor = ThemeTokens.Color.background
        // The accordion collapses rows by animating their height to zero; the
        // card content must be clipped so the compression reads as folding.
        contentView.clipsToBounds = true
        accessibilityIdentifier = "InboxMessageCell"

        cardView.layer.cornerRadius = ThemeTokens.CornerRadius.row
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = ThemeTokens.Color.separator.cgColor
        cardView.clipsToBounds = true
        contentView.addSubview(cardView)
        cardView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            // During accordion height animation the cell can be shorter than
            // the card's natural height; pinning both edges with required
            // equalities creates negative-height conflicts mid-animation and
            // the engine breaks layout arbitrarily (cards stick to one edge).
            // Instead: keep the card centered, let inequalities cap its size,
            // and let the low-priority height yield while compressing.
            make.centerY.equalToSuperview()
            make.top.greaterThanOrEqualToSuperview().offset(ThemeTokens.Spacing.xs)
            make.bottom.lessThanOrEqualToSuperview().offset(-ThemeTokens.Spacing.xs)
            make.height.equalTo(92 - ThemeTokens.Spacing.xs * 2).priority(.low)
        }

        unreadAccent.isHidden = true

        iconContainer.layer.cornerRadius = ThemeTokens.CornerRadius.avatar
        cardView.addSubview(iconContainer)
        iconContainer.addSubview(iconImageView)
        iconContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(ThemeTokens.Spacing.md)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(40)
        }
        iconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(ThemeTokens.Icons.Sizes.md)
        }

        unreadDot.layer.cornerRadius = 3
        unreadDot.backgroundColor = ThemeTokens.Color.primary
        cardView.addSubview(unreadDot)
        unreadDot.snp.makeConstraints { make in
            make.top.equalTo(iconContainer.snp.top).offset(-1)
            make.trailing.equalTo(iconContainer.snp.trailing).offset(1)
            make.width.height.equalTo(6)
        }

        sourceLabel.font = ThemeTokens.Typography.metadata
        sourceLabel.textColor = ThemeTokens.Color.textSecondary
        sourceLabel.lineBreakMode = .byTruncatingTail
        timestampLabel.font = ThemeTokens.Typography.metadata
        timestampLabel.textColor = ThemeTokens.Color.textTertiary
        timestampLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        stateBadge.font = ThemeTokens.Typography.caption
        stateBadge.textAlignment = .center
        stateBadge.layer.cornerRadius = ThemeTokens.CornerRadius.xs
        stateBadge.clipsToBounds = true
        stateBadge.snp.makeConstraints { make in
            make.height.equalTo(18)
        }

        let sourceRow = UIStackView(arrangedSubviews: [sourceLabel, stateBadge, UIView(), timestampLabel])
        sourceRow.axis = .horizontal
        sourceRow.alignment = .center
        sourceRow.spacing = ThemeTokens.Spacing.sm

        titleLabel.font = ThemeTokens.Typography.rowTitle
        titleLabel.textColor = ThemeTokens.Color.text
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail

        previewLabel.font = ThemeTokens.Typography.subheadline
        previewLabel.textColor = ThemeTokens.Color.textSecondary
        previewLabel.numberOfLines = 1
        previewLabel.lineBreakMode = .byTruncatingTail

        let textStack = UIStackView(arrangedSubviews: [sourceRow, titleLabel, previewLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        cardView.addSubview(textStack)
        textStack.snp.makeConstraints { make in
            make.leading.equalTo(iconContainer.snp.trailing).offset(ThemeTokens.Spacing.md)
            make.top.bottom.equalToSuperview().inset(ThemeTokens.Spacing.md)
            make.trailing.equalToSuperview().inset(ThemeTokens.Spacing.xxxl)
        }

        chevronImageView.image = LucideIcon.chevronRight.templateImage(pointSize: ThemeTokens.Icons.Sizes.xs)
        chevronImageView.tintColor = ThemeTokens.Color.textTertiary
        cardView.addSubview(chevronImageView)
        chevronImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(ThemeTokens.Spacing.md)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(ThemeTokens.Icons.Sizes.xs)
        }

    }

    /// Collapsed rows persist at zero height (content clipped away, impossible
    /// to hit-test); their accessibility subtree is additionally hidden and
    /// identifiers stripped so hidden cards are not exposed to VoiceOver or UI
    /// tests. Both matter: zero-frame descendant elements can break assistive
    /// snapshots when enough of them accumulate. Visual hiding is NOT needed —
    /// zero height plus clipping already renders nothing.
    func setCollapsedAccessibility(_ collapsed: Bool) {
        accessibilityElementsHidden = collapsed
        if collapsed {
            if accessibilityIdentifier != nil {
                collapsedIdentity = accessibilityIdentifier
            }
            accessibilityIdentifier = nil
            cardView.accessibilityIdentifier = nil
        } else if let identity = collapsedIdentity {
            accessibilityIdentifier = identity
            cardView.accessibilityIdentifier = "\(identity).content"
        }
        collapsedIdentity = collapsed ? collapsedIdentity : nil
    }

    private var collapsedIdentity: String?

    func configure(with message: StoredMessage) {
        collapsedIdentity = nil
        let presentation = NotificationPresentation(message: message)
        accessibilityIdentifier = "notification.card.\(message.id)"
        cardView.accessibilityIdentifier = "notification.card.\(message.id).content"
        cardView.backgroundColor = ThemeTokens.Color.surface
        unreadAccent.isHidden = true

        iconContainer.backgroundColor = presentation.tintColor.withAlphaComponent(0.12)
        iconImageView.image = presentation.icon.templateImage(pointSize: ThemeTokens.Icons.Sizes.md)
        iconImageView.tintColor = presentation.tintColor
        unreadDot.isHidden = message.isRead
        sourceLabel.text = presentation.source
        timestampLabel.text = Self.timeText(for: message.receivedAt)
        titleLabel.text = message.payload.title
        titleLabel.font = message.isRead ? ThemeTokens.Typography.rowTitle : ThemeTokens.Typography.sectionTitle
        previewLabel.text = presentation.preview
        previewLabel.accessibilityIdentifier = "notification.preview.\(message.id)"

        configureBadge(stateBadge, title: presentation.stateLabel, color: presentation.tintColor)
        stateBadge.accessibilityIdentifier = presentation.stateLabel == nil
            ? nil
            : "notification.state.\(message.id)"
    }

    private func configureBadge(_ badge: UILabel, title: String?, color: UIColor) {
        badge.text = title.map { "  \($0)  " }
        badge.isHidden = title == nil
        badge.textColor = color
        badge.backgroundColor = color.withAlphaComponent(0.10)
    }

    private static func timeText(for date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = calendar.isDateInToday(date) ? "HH:mm" : "M/d"
        return formatter.string(from: date)
    }
}

private struct NotificationPresentation {
    let source: String
    let preview: String
    let stateLabel: String?
    let icon: LucideIcon
    let tintColor: UIColor

    init(message: StoredMessage) {
        let payload = message.payload
        source = Self.source(for: payload)
        preview = Self.preview(for: message)
        stateLabel = Self.stateLabel(payload: payload)
        (icon, tintColor) = Self.style(for: payload)
    }

    private static func source(for payload: MessagePayload) -> String {
        if let subtitle = payload.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines), !subtitle.isEmpty {
            return subtitle
        }
        if let appID = payload.targetAppId, !appID.isEmpty {
            return "PWA · \(appID)"
        }
        switch payload.channel.lowercased() {
        case "apns", "apn": return "应用推送"
        case "bark": return "服务推送"
        case "bridge": return "PWA"
        case "system": return "WebBridgeKit"
        default: return payload.channel.uppercased()
        }
    }

    private static func preview(for message: StoredMessage) -> String {
        let raw = message.bodyType == "markdown" ? (message.payload.markdown ?? message.payload.body) : message.payload.body
        return raw
            .replacingOccurrences(of: "[#*_>`]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func categoryLabel(_ category: String?) -> String? {
        switch category?.lowercased() {
        case "verification", "otp": return "验证码"
        case "approval", "permission": return "审批"
        case "task", "deployment": return "任务"
        case "security": return "安全"
        case "alert": return "告警"
        case "order": return "订单"
        case "chat": return "聊天"
        case "promotion": return "活动"
        case "weather": return "天气"
        default: return nil
        }
    }

    private static func stateLabel(payload: MessagePayload) -> String? {
        if let actionState = payload.actionState {
            switch actionState {
            case .pending: return "待确认"
            case .approved, .rejected, .cancelled, .expired: return nil
            @unknown default: return nil
            }
        }
        return payload.priority == .critical ? "紧急" : nil
    }

    private static func style(for payload: MessagePayload) -> (LucideIcon, UIColor) {
        if let actionState = payload.actionState {
            switch actionState {
            case .pending: return (.clock, ThemeTokens.Color.warning)
            case .approved: return (.success, ThemeTokens.Color.success)
            case .rejected, .cancelled, .expired: return (.clipboard, ThemeTokens.Color.textSecondary)
            @unknown default: return (.clipboard, ThemeTokens.Color.textSecondary)
            }
        }
        switch payload.contentType {
        case .markdown: return (.docText, ThemeTokens.Color.accent)
        case .image: return (.image, ThemeTokens.Color.primary)
        case .qr: return (.qrCode, ThemeTokens.Color.info)
        case .otp: return (.key, ThemeTokens.Color.primary)
        case .chat: return (.paperplane, ThemeTokens.Color.info)
        case .approval: return (.clipboard, ThemeTokens.Color.warning)
        case .plain, nil: break
        case .some: return (.inbox, ThemeTokens.Color.primary)
        }
        if payload.contentType == .qr || payload.qrPayload != nil {
            return (.qrCode, ThemeTokens.Color.info)
        }
        switch payload.category?.lowercased() {
        case "verification", "otp": return (.key, ThemeTokens.Color.primary)
        case "security": return (.shield, ThemeTokens.Color.error)
        case "alert": return (.warning, ThemeTokens.Color.warning)
        case "approval", "permission": return (.clipboard, ThemeTokens.Color.info)
        case "task", "deployment": return (.success, ThemeTokens.Color.success)
        case "chat": return (.paperplane, ThemeTokens.Color.info)
        case "promotion": return (.tag, ThemeTokens.Color.warning)
        default:
            switch payload.channel.lowercased() {
            case "apns", "apn": return (.bell, ThemeTokens.Color.primary)
            case "bark": return (.volume, ThemeTokens.Color.warning)
            case "bridge": return (.globe, ThemeTokens.Color.info)
            case "system": return (.info, ThemeTokens.Color.textSecondary)
            default: return (.inbox, ThemeTokens.Color.primary)
            }
        }
    }
}

// MARK: - GroupChevronIndicator

/// Self-drawn chevron for the group header. A UIImageView loaded from the
/// Lucide catalog fails to rasterize inside a cell dequeued as a section
/// header (it renders fine in normal cells), so the indicator draws its own
/// vector path and stays animatable via `transform`.
final class GroupChevronIndicator: UIView {

    private let shapeLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = nil
        layer.lineWidth = 2.5
        layer.lineCap = .round
        layer.lineJoin = .round
        return layer
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isAccessibilityElement = true
        accessibilityLabel = "展开收起"
        layer.addSublayer(shapeLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width
        let height = bounds.height
        let path = UIBezierPath()
        path.move(to: CGPoint(x: width * 0.2, y: height * 0.32))
        path.addLine(to: CGPoint(x: width * 0.5, y: height * 0.68))
        path.addLine(to: CGPoint(x: width * 0.8, y: height * 0.32))
        shapeLayer.frame = bounds
        shapeLayer.path = path.cgPath
        updateStrokeColor()
    }

    override func tintColorDidChange() {
        super.tintColorDidChange()
        updateStrokeColor()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateStrokeColor()
    }

    private func updateStrokeColor() {
        shapeLayer.strokeColor = ThemeTokens.Color.textSecondary
            .resolvedColor(with: traitCollection)
            .cgColor
    }
}

// MARK: - InboxGroupHeaderCell

class InboxGroupHeaderCell: UITableViewCell {

    static let identifier = "InboxGroupHeaderCell"

    /// Tracks the last applied expand state so the chevron only animates on a
    /// real state change; reconfigured cells during scroll must not spin.
    private var appliedExpandedState: Bool?

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.sectionTitle
        label.textColor = ThemeTokens.Color.text
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

    private let chevronIndicator = GroupChevronIndicator()

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
        accessibilityIdentifier = "InboxGroupHeaderCell"
        contentView.accessibilityIdentifier = "InboxGroupHeaderCell.content"
        containerView.accessibilityIdentifier = "InboxGroupHeaderCell.container"

        // A zero-delay long-press acts as a press tracker: it gives touch-down
        // highlight feedback and fires the toggle on release, matching the
        // accordion feel of system grouped lists.
        let pressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handlePress(_:)))
        pressGesture.minimumPressDuration = 0
        contentView.addGestureRecognizer(pressGesture)

        contentView.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(countContainer)
        countContainer.addSubview(countLabel)
        containerView.addSubview(chevronIndicator)

        containerView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(ThemeTokens.Spacing.sm)
            make.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview()
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(ThemeTokens.Spacing.xs)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(countContainer.snp.leading).offset(-ThemeTokens.Spacing.sm)
        }

        countContainer.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            // Anchored right next to the chevron; a lessThanOrEqualTo here
            // left the badge underconstrained and drifting beside the title.
            make.trailing.equalTo(chevronIndicator.snp.leading).offset(-ThemeTokens.Spacing.sm)
            make.height.equalTo(20)
        }

        countLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6))
        }

        chevronIndicator.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-ThemeTokens.Spacing.xs)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(ThemeTokens.Icons.Sizes.xs)
        }
    }

    func configure(
        title: String,
        count: Int,
        isExpanded: Bool,
        hasUnread: Bool = false,
        accessibilityIdentifier: String
    ) {
        self.accessibilityIdentifier = accessibilityIdentifier
        self.accessibilityLabel = title
        self.accessibilityValue = isExpanded ? "expanded" : "collapsed"
        self.accessibilityTraits = .button
        titleLabel.text = title
        countLabel.text = "\(count)"
        countContainer.isHidden = count == 0
        titleLabel.font = hasUnread
            ? ThemeTokens.Typography.sectionTitle
            : ThemeTokens.Typography.rowTitle
        titleLabel.textColor = hasUnread
            ? ThemeTokens.Color.text
            : ThemeTokens.Color.textSecondary

        let shouldAnimate = appliedExpandedState != nil && appliedExpandedState != isExpanded
        appliedExpandedState = isExpanded
        let chevronTransform: CGAffineTransform = isExpanded
            ? .identity
            : CGAffineTransform(rotationAngle: -.pi / 2)
        if shouldAnimate {
            UIView.animate(
                withDuration: ThemeTokens.Animation.modal.duration,
                delay: 0,
                usingSpringWithDamping: 0.78,
                initialSpringVelocity: 0.6,
                options: [.allowUserInteraction, .beginFromCurrentState]
            ) {
                self.chevronIndicator.transform = chevronTransform
            }
        } else {
            chevronIndicator.transform = chevronTransform
        }
    }

    @objc private func handlePress(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            setPressed(true)
        case .ended:
            setPressed(false)
            onTap?()
        case .cancelled, .failed:
            setPressed(false)
        default:
            break
        }
    }

    private func setPressed(_ pressed: Bool) {
        let highlight = ThemeTokens.Color.backgroundSecondary
        UIView.animate(withDuration: ThemeTokens.Animation.fast.duration) {
            self.containerView.backgroundColor = pressed ? highlight : .clear
        }
    }
}
