import UIKit
import SnapKit

public final class WBKFilterPill: UIView {

    public enum Style {
        case `default`
        case withIcon(icon: LucideIcon)
        case withCount(count: Int)
        case destructive
    }

    private let titleLabel = UILabel()
    private let iconView = UIImageView()
    private let countLabel = UILabel()
    private var currentStyle: Style = .default

    public var isSelected: Bool = false {
        didSet { updateAppearance() }
    }

    public var isEnabled: Bool = true {
        didSet {
            alpha = isEnabled ? 1.0 : ThemeTokens.Opacity.disabled
            isUserInteractionEnabled = isEnabled
        }
    }

    public var onTap: ((WBKFilterPill) -> Void)?

    public var title: String {
        get { titleLabel.text ?? "" }
        set { titleLabel.text = newValue }
    }

    public init(title: String, style: Style = .default) {
        self.currentStyle = style
        super.init(frame: .zero)
        accessibilityIdentifier = "wbk_filter_pill"
        isAccessibilityElement = true
        accessibilityTraits = .button
        setupUI(title: title, style: style)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateAppearance()
    }

    public override var intrinsicContentSize: CGSize {
        let titleWidth = titleLabel.intrinsicContentSize.width
        let iconWidth: CGFloat
        let countWidth: CGFloat

        switch currentStyle {
        case .withIcon:
            iconWidth = 14 + 4
            countWidth = 0
        case .withCount(let count):
            iconWidth = 0
            countWidth = count > 0 ? 16 + 4 : 0
        default:
            iconWidth = 0
            countWidth = 0
        }

        let contentWidth = iconWidth + titleWidth + countWidth + ThemeTokens.ComponentContract.FilterPill.horizontalPadding * 2
        return CGSize(width: max(contentWidth, ThemeTokens.ComponentContract.FilterPill.minWidth), height: ThemeTokens.ComponentContract.FilterPill.height)
    }

    private func setupUI(title: String, style: Style) {
        layer.cornerRadius = ThemeTokens.ComponentContract.FilterPill.height / 2
        clipsToBounds = true
        isUserInteractionEnabled = true
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))

        titleLabel.font = ThemeTokens.Typography.caption
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.text = title

        iconView.contentMode = .scaleAspectFit
        iconView.isHidden = true

        countLabel.font = ThemeTokens.Typography.caption1
        countLabel.textAlignment = .center
        countLabel.numberOfLines = 1
        countLabel.isHidden = true

        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(countLabel)

        switch style {
        case .withIcon(let icon):
            iconView.isHidden = false
            iconView.image = icon.templateImage(pointSize: 14)

            iconView.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(ThemeTokens.ComponentContract.FilterPill.horizontalPadding)
                make.centerY.equalToSuperview()
                make.width.height.equalTo(14)
            }
            titleLabel.snp.makeConstraints { make in
                make.leading.equalTo(iconView.snp.trailing).offset(ThemeTokens.Spacing.xs)
                make.trailing.equalToSuperview().offset(-ThemeTokens.ComponentContract.FilterPill.horizontalPadding)
                make.centerY.equalToSuperview()
            }

        case .withCount(let count):
            if count > 0 {
                countLabel.isHidden = false
                countLabel.text = "\(count)"

                titleLabel.snp.makeConstraints { make in
                    make.leading.equalToSuperview().offset(ThemeTokens.ComponentContract.FilterPill.horizontalPadding)
                    make.centerY.equalToSuperview()
                }
                countLabel.snp.makeConstraints { make in
                    make.leading.equalTo(titleLabel.snp.trailing).offset(ThemeTokens.Spacing.xs)
                    make.trailing.equalToSuperview().offset(-ThemeTokens.ComponentContract.FilterPill.horizontalPadding)
                    make.centerY.equalToSuperview()
                }
            } else {
                titleLabel.snp.makeConstraints { make in
                    make.leading.equalToSuperview().offset(ThemeTokens.ComponentContract.FilterPill.horizontalPadding)
                    make.trailing.equalToSuperview().offset(-ThemeTokens.ComponentContract.FilterPill.horizontalPadding)
                    make.centerY.equalToSuperview()
                }
            }

        default:
            titleLabel.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(ThemeTokens.ComponentContract.FilterPill.horizontalPadding)
                make.trailing.equalToSuperview().offset(-ThemeTokens.ComponentContract.FilterPill.horizontalPadding)
                make.centerY.equalToSuperview()
            }
        }

        snp.makeConstraints { make in
            make.height.equalTo(ThemeTokens.ComponentContract.FilterPill.height)
        }

        updateAppearance()
    }

    @objc private func handleTap() {
        isSelected.toggle()
        onTap?(self)
    }

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        alpha = ThemeTokens.Opacity.pressed
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        UIView.animate(withDuration: ThemeTokens.Animation.fast.duration) {
            self.alpha = 1.0
        }
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        UIView.animate(withDuration: ThemeTokens.Animation.fast.duration) {
            self.alpha = 1.0
        }
    }

    private func updateAppearance() {
        let isDestructive: Bool
        if case .destructive = currentStyle {
            isDestructive = true
        } else {
            isDestructive = false
        }

        if isDestructive {
            if isSelected {
                backgroundColor = ThemeTokens.Color.error.withAlphaComponent(0.12)
                layer.borderWidth = 1
                layer.borderColor = ThemeTokens.Color.error.cgColor
                titleLabel.textColor = ThemeTokens.Color.error
                iconView.tintColor = ThemeTokens.Color.error
                countLabel.textColor = ThemeTokens.Color.error
            } else {
                backgroundColor = ThemeTokens.Color.surface
                layer.borderWidth = 1
                layer.borderColor = ThemeTokens.Color.border.cgColor
                titleLabel.textColor = ThemeTokens.Color.textSecondary
                iconView.tintColor = ThemeTokens.Color.textSecondary
                countLabel.textColor = ThemeTokens.Color.textSecondary
            }
        } else {
            if isSelected {
                backgroundColor = ThemeTokens.Color.primarySoft
                layer.borderWidth = 1
                layer.borderColor = ThemeTokens.Color.primary.cgColor
                titleLabel.textColor = ThemeTokens.Color.primary
                iconView.tintColor = ThemeTokens.Color.primary
                countLabel.textColor = ThemeTokens.Color.primary
            } else {
                backgroundColor = ThemeTokens.Color.surface
                layer.borderWidth = 1
                layer.borderColor = ThemeTokens.Color.border.cgColor
                titleLabel.textColor = ThemeTokens.Color.textSecondary
                iconView.tintColor = ThemeTokens.Color.textSecondary
                countLabel.textColor = ThemeTokens.Color.textSecondary
            }
        }

        invalidateIntrinsicContentSize()
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }
}
