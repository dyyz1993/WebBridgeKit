import UIKit
import SnapKit

public final class WBKListRow: UIView {

    public enum Style {
        case `default`
        case destructive
        case toggle
        case value
    }

    public enum AccessoryType {
        case none
        case chevron
        case disclosure
        case custom(UIView)
    }

    public var style: Style = .default {
        didSet { updateStyle() }
    }

    public var icon: UIImage? {
        get { iconImageView.image }
        set { iconImageView.image = newValue }
    }

    public var iconTintColor: UIColor? {
        get { iconImageView.tintColor }
        set { iconImageView.tintColor = newValue ?? ThemeTokens.Color.primary }
    }

    public var title: String {
        get { titleLabel.text ?? "" }
        set { titleLabel.text = newValue }
    }

    public var subtitle: String? {
        get { subtitleLabel.text }
        set {
            subtitleLabel.text = newValue
            subtitleLabel.isHidden = newValue == nil
        }
    }

    public var trailingText: String? {
        get { trailingLabel.text }
        set {
            trailingLabel.text = newValue
            trailingLabel.isHidden = newValue == nil
        }
    }

    public var accessoryType: AccessoryType = .chevron {
        didSet { updateAccessory() }
    }

    public var isToggleOn: Bool {
        get { toggleSwitch.isOn }
        set { toggleSwitch.setOn(newValue, animated: true) }
    }

    public var isEnabled: Bool = true {
        didSet {
            alpha = isEnabled ? 1.0 : ThemeTokens.Opacity.disabled
            isUserInteractionEnabled = isEnabled
        }
    }

    public var onToggleChanged: ((Bool) -> Void)?
    public var onTap: (() -> Void)?

    private let containerView = UIView()
    private let iconBoxView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let trailingLabel = UILabel()
    private let chevronImageView = UIImageView()
    private let separatorView = UIView()
    private let toggleSwitch = UISwitch()

    private var customAccessoryView: UIView?

    override public init(frame: CGRect) {
        super.init(frame: frame)
        accessibilityIdentifier = "wbk_list_row"
        setupUI()
    }

    public init(style: Style = .default) {
        self.style = style
        super.init(frame: .zero)
        accessibilityIdentifier = "wbk_list_row"
        setupUI()
        updateStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        addSubview(containerView)
        containerView.addSubview(iconBoxView)
        iconBoxView.addSubview(iconImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)
        containerView.addSubview(trailingLabel)
        containerView.addSubview(chevronImageView)
        containerView.addSubview(toggleSwitch)
        addSubview(separatorView)

        backgroundColor = .clear

        iconBoxView.backgroundColor = .clear
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = ThemeTokens.Color.primary

        titleLabel.font = ThemeTokens.Typography.rowTitle
        titleLabel.textColor = ThemeTokens.Color.text
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail

        subtitleLabel.font = ThemeTokens.Typography.metadata
        subtitleLabel.textColor = ThemeTokens.Color.textSecondary
        subtitleLabel.numberOfLines = 1
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.isHidden = true

        trailingLabel.font = ThemeTokens.Typography.metadata
        trailingLabel.textColor = ThemeTokens.Color.textTertiary
        trailingLabel.numberOfLines = 1
        trailingLabel.textAlignment = .right
        trailingLabel.lineBreakMode = .byTruncatingTail
        trailingLabel.isHidden = true

        chevronImageView.image = LucideIcon.chevronRight.templateImage(pointSize: ThemeTokens.Icons.Sizes.sm)
        chevronImageView.contentMode = .scaleAspectFit
        chevronImageView.tintColor = ThemeTokens.Color.textTertiary

        toggleSwitch.onTintColor = ThemeTokens.Color.primary
        toggleSwitch.isHidden = true
        toggleSwitch.addTarget(self, action: #selector(toggleValueChanged), for: .valueChanged)

        separatorView.backgroundColor = ThemeTokens.Color.separator

        containerView.backgroundColor = ThemeTokens.Color.surface
        containerView.layer.cornerRadius = ThemeTokens.CornerRadius.row
        containerView.clipsToBounds = true

        containerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().priority(.high)
        }

        iconBoxView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(32)
        }

        iconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(20)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconBoxView.snp.trailing).offset(12)
            make.top.equalToSuperview().offset(14)
            make.trailing.lessThanOrEqualTo(trailingLabel.snp.leading).offset(-8).priority(.high)
            make.trailing.lessThanOrEqualTo(chevronImageView.snp.leading).offset(-8).priority(.high)
            make.trailing.lessThanOrEqualTo(toggleSwitch.snp.leading).offset(-8).priority(.high)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
            make.trailing.lessThanOrEqualTo(titleLabel)
            make.bottom.equalToSuperview().offset(-14).priority(.high)
        }

        trailingLabel.snp.makeConstraints { make in
            make.trailing.equalTo(chevronImageView.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
            make.width.lessThanOrEqualTo(120)
        }

        chevronImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }

        toggleSwitch.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
        }

        separatorView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.trailing.bottom.equalToSuperview()
            make.height.equalTo(0.5)
        }

        snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(52)
            make.height.lessThanOrEqualTo(60)
        }

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)

        updateAccessory()
        updateStyle()
    }

    private func updateStyle() {
        switch style {
        case .default, .value:
            titleLabel.textColor = ThemeTokens.Color.text
            iconImageView.tintColor = iconTintColor ?? ThemeTokens.Color.primary
            toggleSwitch.isHidden = true
            chevronImageView.isHidden = false
        case .destructive:
            titleLabel.textColor = ThemeTokens.Color.error
            iconImageView.tintColor = ThemeTokens.Color.error
            toggleSwitch.isHidden = true
            chevronImageView.isHidden = false
        case .toggle:
            titleLabel.textColor = ThemeTokens.Color.text
            iconImageView.tintColor = iconTintColor ?? ThemeTokens.Color.primary
            toggleSwitch.isHidden = false
            chevronImageView.isHidden = true
        }

        updateBottomConstraint()
    }

    private func updateAccessory() {
        customAccessoryView?.removeFromSuperview()
        customAccessoryView = nil

        switch accessoryType {
        case .none:
            chevronImageView.isHidden = true
            trailingLabel.snp.remakeConstraints { make in
                make.trailing.equalToSuperview().offset(-16)
                make.centerY.equalToSuperview()
                make.width.lessThanOrEqualTo(120)
            }
        case .chevron:
            chevronImageView.isHidden = (style == .toggle)
            chevronImageView.image = LucideIcon.chevronRight.templateImage(pointSize: ThemeTokens.Icons.Sizes.sm)
            trailingLabel.snp.remakeConstraints { make in
                make.trailing.equalTo(chevronImageView.snp.leading).offset(-8)
                make.centerY.equalToSuperview()
                make.width.lessThanOrEqualTo(120)
            }
        case .disclosure:
            chevronImageView.isHidden = (style == .toggle)
            chevronImageView.image = LucideIcon.info.templateImage(pointSize: ThemeTokens.Icons.Sizes.sm)
            trailingLabel.snp.remakeConstraints { make in
                make.trailing.equalTo(chevronImageView.snp.leading).offset(-8)
                make.centerY.equalToSuperview()
                make.width.lessThanOrEqualTo(120)
            }
        case .custom(let view):
            chevronImageView.isHidden = true
            customAccessoryView = view
            containerView.addSubview(view)
            view.snp.makeConstraints { make in
                make.trailing.equalToSuperview().offset(-12)
                make.centerY.equalToSuperview()
            }
            trailingLabel.snp.remakeConstraints { make in
                make.trailing.equalTo(view.snp.leading).offset(-8)
                make.centerY.equalToSuperview()
                make.width.lessThanOrEqualTo(120)
            }
        }
    }

    private func updateBottomConstraint() {
        if subtitle != nil {
            subtitleLabel.isHidden = false
            titleLabel.snp.remakeConstraints { make in
                make.leading.equalTo(iconBoxView.snp.trailing).offset(12)
                make.top.equalToSuperview().offset(10)
                make.trailing.lessThanOrEqualTo(trailingLabel.snp.leading).offset(-8).priority(.high)
                make.trailing.lessThanOrEqualTo(chevronImageView.snp.leading).offset(-8).priority(.high)
                make.trailing.lessThanOrEqualTo(toggleSwitch.snp.leading).offset(-8).priority(.high)
            }
            subtitleLabel.snp.remakeConstraints { make in
                make.leading.equalTo(titleLabel)
                make.top.equalTo(titleLabel.snp.bottom).offset(2)
                make.trailing.lessThanOrEqualTo(titleLabel)
                make.bottom.equalToSuperview().offset(-10)
            }
        } else {
            titleLabel.snp.remakeConstraints { make in
                make.leading.equalTo(iconBoxView.snp.trailing).offset(12)
                make.top.equalToSuperview().offset(14)
                make.bottom.equalToSuperview().offset(-14)
                make.trailing.lessThanOrEqualTo(trailingLabel.snp.leading).offset(-8).priority(.high)
                make.trailing.lessThanOrEqualTo(chevronImageView.snp.leading).offset(-8).priority(.high)
                make.trailing.lessThanOrEqualTo(toggleSwitch.snp.leading).offset(-8).priority(.high)
            }
        }
    }

    public override func setNeedsLayout() {
        super.setNeedsLayout()
        updateBottomConstraint()
    }

    @objc private func handleTap() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        if style == .toggle {
            toggleSwitch.setOn(!toggleSwitch.isOn, animated: true)
            onToggleChanged?(toggleSwitch.isOn)
        } else {
            onTap?()
        }
    }

    @objc private func toggleValueChanged() {
        onToggleChanged?(toggleSwitch.isOn)
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

    public func setGroupedStyle(_ grouped: Bool) {
        containerView.backgroundColor = grouped ? .clear : ThemeTokens.Color.surface
        separatorView.isHidden = grouped
    }

    public func setIcon(_ lucideIcon: LucideIcon) {
        iconImageView.image = lucideIcon.templateImage(pointSize: 20)
    }

    public func setIconBoxBackgroundColor(_ color: UIColor) {
        iconBoxView.backgroundColor = color
    }
}
