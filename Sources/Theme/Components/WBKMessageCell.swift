import UIKit
import SnapKit

public final class WBKMessageCell: UIView {

    public enum Style {
        case `default`
        case compact
        case withAvatar
    }

    public var icon: LucideIcon? {
        didSet { updateIcon() }
    }

    public var title: String {
        get { titleLabel.text ?? "" }
        set { titleLabel.text = newValue }
    }

    public var body: String {
        get { bodyLabel.text ?? "" }
        set {
            bodyLabel.text = newValue
            bodyLabel.isHidden = (style == .compact) || newValue.isEmpty
            updateBodyConstraints()
        }
    }

    public var timestamp: String? {
        get { timestampLabel.text }
        set {
            timestampLabel.text = newValue
            timestampLabel.isHidden = newValue == nil
        }
    }

    public var isRead: Bool = false {
        didSet { updateReadState() }
    }

    public var style: Style {
        didSet { applyStyle() }
    }

    public var isEnabled: Bool = true {
        didSet {
            alpha = isEnabled ? 1.0 : ThemeTokens.Opacity.disabled
            isUserInteractionEnabled = isEnabled
        }
    }

    public var isLoading: Bool = false {
        didSet {
            if isLoading {
                containerView.alpha = 0
                skeletonView.isHidden = false
                skeletonView.alpha = 1
                UIView.animate(
                    withDuration: 1.0,
                    delay: 0,
                    options: [.repeat, .autoreverse],
                    animations: { self.skeletonView.alpha = 0.4 }
                )
            } else {
                containerView.alpha = 1
                skeletonView.isHidden = true
                skeletonView.layer.removeAllAnimations()
            }
        }
    }

    public var onTap: (() -> Void)?

    private let containerView = UIView()
    private let skeletonView = UIView()
    private let unreadDotView = UIView()
    private let avatarView = UIView()
    private let avatarLabel = UILabel()
    private let iconImageView = UIImageView()
    private let textStack = UIStackView()
    private let titleRow = UIStackView()
    private let titleLabel = UILabel()
    private let timestampLabel = UILabel()
    private let bodyLabel = UILabel()
    private let separatorView = UIView()

    public init(title: String, body: String = "", style: Style = .default) {
        self.style = style
        super.init(frame: .zero)
        accessibilityIdentifier = "wbk_message_cell"
        setupUI()
        self.title = title
        self.body = body
        applyStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        addSubview(containerView)
        addSubview(skeletonView)
        containerView.addSubview(unreadDotView)
        containerView.addSubview(avatarView)
        avatarView.addSubview(avatarLabel)
        containerView.addSubview(iconImageView)
        containerView.addSubview(textStack)
        addSubview(separatorView)

        backgroundColor = .clear

        skeletonView.backgroundColor = ThemeTokens.Color.border
        skeletonView.layer.cornerRadius = ThemeTokens.CornerRadius.card
        skeletonView.isHidden = true
        skeletonView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(80)
        }

        containerView.backgroundColor = ThemeTokens.Color.surface
        containerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().priority(.high)
        }

        unreadDotView.backgroundColor = ThemeTokens.Color.unreadDot
        unreadDotView.layer.cornerRadius = 4
        unreadDotView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalToSuperview().offset(18)
            make.width.height.equalTo(8)
        }

        avatarView.backgroundColor = ThemeTokens.Color.primary
        avatarView.layer.cornerRadius = 20
        avatarView.isHidden = true
        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(40)
        }

        avatarLabel.font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 17, weight: .medium))
        avatarLabel.textColor = ThemeTokens.Color.text
        avatarLabel.textAlignment = .center
        avatarLabel.numberOfLines = 1
        avatarLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = ThemeTokens.Color.textTertiary
        iconImageView.isHidden = true
        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(ThemeTokens.Icons.Sizes.md)
        }

        titleRow.axis = .horizontal
        titleRow.alignment = .firstBaseline
        titleRow.spacing = ThemeTokens.Spacing.sm

        titleLabel.font = ThemeTokens.Typography.rowTitle
        titleLabel.textColor = ThemeTokens.Color.text
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        timestampLabel.font = ThemeTokens.Typography.metadata
        timestampLabel.textColor = ThemeTokens.Color.textTertiary
        timestampLabel.numberOfLines = 1
        timestampLabel.textAlignment = .right
        timestampLabel.lineBreakMode = .byTruncatingTail
        timestampLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        timestampLabel.setContentHuggingPriority(.required, for: .horizontal)

        titleRow.addArrangedSubview(titleLabel)
        titleRow.addArrangedSubview(timestampLabel)

        bodyLabel.font = ThemeTokens.Typography.subheadline
        bodyLabel.textColor = ThemeTokens.Color.textSecondary
        bodyLabel.numberOfLines = 2
        bodyLabel.lineBreakMode = .byTruncatingTail

        textStack.axis = .vertical
        textStack.spacing = ThemeTokens.Spacing.xs
        textStack.addArrangedSubview(titleRow)
        textStack.addArrangedSubview(bodyLabel)
        containerView.addSubview(textStack)

        textStack.snp.makeConstraints { make in
            make.leading.equalTo(containerView.snp.leading).offset(40)
            make.top.equalToSuperview().offset(12)
            make.bottom.equalToSuperview().offset(-12).priority(.high)
            make.trailing.equalToSuperview().offset(-16)
        }

        separatorView.backgroundColor = ThemeTokens.Color.separator
        separatorView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.trailing.bottom.equalToSuperview()
            make.height.equalTo(0.5)
        }

        snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(72)
            make.height.lessThanOrEqualTo(96)
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)

        updateBodyConstraints()
    }

    private func applyStyle() {
        switch style {
        case .default:
            avatarView.isHidden = true
            iconImageView.isHidden = icon == nil
            unreadDotView.isHidden = isRead
            bodyLabel.isHidden = body.isEmpty

        case .compact:
            avatarView.isHidden = true
            iconImageView.isHidden = icon == nil
            unreadDotView.isHidden = isRead
            bodyLabel.isHidden = true

        case .withAvatar:
            avatarView.isHidden = false
            iconImageView.isHidden = true
            unreadDotView.isHidden = isRead
            bodyLabel.isHidden = body.isEmpty
            updateAvatar()
        }

        updateLeadingConstraint()
        updateBodyConstraints()
        updateReadState()
    }

    private func updateLeadingConstraint() {
        let leadingView: UIView
        switch style {
        case .withAvatar:
            leadingView = avatarView
        case .default, .compact:
            if icon != nil {
                leadingView = iconImageView
            } else {
                leadingView = unreadDotView
            }
        }

        textStack.snp.remakeConstraints { make in
            make.leading.equalTo(leadingView.snp.trailing).offset(12)
            make.top.equalToSuperview().offset(12)
            make.bottom.equalToSuperview().offset(-12).priority(.high)
            make.trailing.equalToSuperview().offset(-16)
        }
    }

    private func updateBodyConstraints() {
        let hideBody = style == .compact || body.isEmpty
        bodyLabel.isHidden = hideBody

        if hideBody {
            textStack.snp.updateConstraints { make in
                make.top.equalToSuperview().offset(16)
                make.bottom.equalToSuperview().offset(-16).priority(.high)
            }
        } else {
            textStack.snp.updateConstraints { make in
                make.top.equalToSuperview().offset(12)
                make.bottom.equalToSuperview().offset(-12).priority(.high)
            }
        }
    }

    private func updateIcon() {
        if let icon = icon {
            iconImageView.image = icon.templateImage(pointSize: ThemeTokens.Icons.Sizes.md)
            iconImageView.isHidden = style == .withAvatar
        } else {
            iconImageView.image = nil
            iconImageView.isHidden = true
        }
        updateLeadingConstraint()
    }

    private func updateAvatar() {
        let first = title.first?.uppercased() ?? "?"
        avatarLabel.text = first
    }

    private func updateReadState() {
        if isRead {
            unreadDotView.isHidden = true
            titleLabel.font = ThemeTokens.Typography.rowTitle
            titleLabel.textColor = ThemeTokens.Color.textSecondary
            containerView.backgroundColor = ThemeTokens.Color.background
        } else {
            unreadDotView.isHidden = style == .withAvatar
            titleLabel.font = ThemeTokens.Typography.headline
            titleLabel.textColor = ThemeTokens.Color.text
            containerView.backgroundColor = ThemeTokens.Color.surface
        }
    }

    @objc private func handleTap() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        UIView.animate(
            withDuration: ThemeTokens.Animation.fast.duration,
            animations: {
                self.containerView.alpha = ThemeTokens.Opacity.pressed
            },
            completion: { _ in
                UIView.animate(withDuration: ThemeTokens.Animation.fast.duration) {
                    self.containerView.alpha = 1.0
                }
            }
        )
        onTap?()
    }

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        UIView.animate(withDuration: ThemeTokens.Animation.fast.duration) {
            self.containerView.alpha = ThemeTokens.Opacity.pressed
        }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        UIView.animate(withDuration: ThemeTokens.Animation.fast.duration) {
            self.containerView.alpha = 1.0
        }
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        UIView.animate(withDuration: ThemeTokens.Animation.fast.duration) {
            self.containerView.alpha = 1.0
        }
    }
}
