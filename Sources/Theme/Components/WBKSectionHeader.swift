import UIKit
import SnapKit

public final class WBKSectionHeader: UIView {

    public enum Style {
        case `default`
        case compact
        case withCount
    }

    private let style: Style

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.sectionTitle
        label.textColor = ThemeTokens.Color.text
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.metadata
        label.textColor = ThemeTokens.Color.textSecondary
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.isHidden = true
        return label
    }()

    private lazy var accessoryButtonImpl: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = ThemeTokens.Typography.metadata
        button.setTitleColor(ThemeTokens.Color.primary, for: .normal)
        button.isHidden = true
        return button
    }()

    private let countLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.metadata
        label.textColor = ThemeTokens.Color.textSecondary
        label.numberOfLines = 1
        label.isHidden = true
        return label
    }()

    private let textStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = ThemeTokens.Spacing.xxs
        return stack
    }()

    public var title: String {
        get { titleLabel.text ?? "" }
        set {
            titleLabel.text = newValue
            if style == .withCount {
                updateCountDisplay()
            }
        }
    }

    public var subtitle: String? {
        get { subtitleLabel.text }
        set {
            subtitleLabel.text = newValue
            subtitleLabel.isHidden = (newValue == nil || newValue!.isEmpty)
        }
    }

    public var accessoryButton: UIButton? {
        get { accessoryButtonImpl.isHidden ? nil : accessoryButtonImpl }
        set {
            if let button = newValue {
                accessoryButtonImpl.setTitle(button.title(for: .normal), for: .normal)
                accessoryButtonImpl.removeTarget(nil, action: nil, for: .touchUpInside)
                let targets = button.allTargets
                for target in targets {
                    if let action = button.actions(forTarget: target, forControlEvent: .touchUpInside)?.first {
                        accessoryButtonImpl.addTarget(target, action: Selector(action), for: .touchUpInside)
                    }
                }
                accessoryButtonImpl.isHidden = false
            } else {
                accessoryButtonImpl.isHidden = true
            }
        }
    }

    public init(title: String, style: Style = .default) {
        self.style = style
        super.init(frame: .zero)
        accessibilityIdentifier = "wbk_section_header"
        self.title = title
        setupUI()
    }

    required init?(coder: NSCoder) {
        self.style = .default
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        let bottomSpacing: CGFloat = (style == .compact) ? ThemeTokens.Spacing.xs : ThemeTokens.Spacing.sm

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)

        addSubview(textStack)
        addSubview(accessoryButtonImpl)
        addSubview(countLabel)

        textStack.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(ThemeTokens.Spacing.screenHorizontal)
            make.trailing.lessThanOrEqualTo(accessoryButtonImpl.snp.leading).offset(-ThemeTokens.Spacing.sm)
            make.trailing.lessThanOrEqualTo(countLabel.snp.leading).offset(-ThemeTokens.Spacing.sm)
            make.top.equalToSuperview()
            make.bottom.equalToSuperview().inset(bottomSpacing)
        }

        countLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(ThemeTokens.Spacing.screenHorizontal)
            make.centerY.equalTo(titleLabel)
        }

        accessoryButtonImpl.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(ThemeTokens.Spacing.screenHorizontal)
            make.centerY.equalTo(titleLabel)
        }

        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        subtitleLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        if style == .withCount {
            countLabel.isHidden = false
            updateCountDisplay()
        }
    }

    public func configure(title: String, subtitle: String? = nil, actionTitle: String? = nil, onAction: (() -> Void)? = nil) {
        self.title = title
        self.subtitle = subtitle

        if let actionTitle = actionTitle {
            accessoryButtonImpl.setTitle(actionTitle, for: .normal)
            accessoryButtonImpl.isHidden = false
            accessoryButtonImpl.addAction(UIAction { _ in onAction?() }, for: .touchUpInside)
        } else {
            accessoryButtonImpl.isHidden = true
        }
    }

    public func setCount(_ count: Int) {
        countLabel.text = "(\(count))"
        countLabel.isHidden = (count == 0 && style != .withCount)
    }

    private func updateCountDisplay() {
        guard style == .withCount else { return }
        countLabel.isHidden = false
    }
}
