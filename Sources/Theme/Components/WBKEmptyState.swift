import UIKit
import SnapKit

public final class WBKEmptyState: UIView {

    public enum Style {
        case `default`
        case error
        case offline
        case loading
    }

    private let iconImageView = UIImageView()
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let actionButton = UIButton(type: .system)

    private var currentStyle: Style = .default

    public var onActionTapped: (() -> Void)?

    public var icon: LucideIcon = .info {
        didSet { updateIcon() }
    }

    public var title: String {
        get { titleLabel.text ?? "" }
        set { titleLabel.text = newValue }
    }

    public var message: String? {
        get { messageLabel.text }
        set {
            messageLabel.text = newValue
            messageLabel.isHidden = newValue == nil
        }
    }

    public var actionTitle: String? {
        get { actionButton.titleLabel?.text }
        set {
            actionButton.setTitle(newValue, for: .normal)
            actionButton.isHidden = newValue == nil
        }
    }

    public init(
        icon: LucideIcon,
        title: String,
        message: String? = nil,
        actionTitle: String? = nil,
        style: Style = .default
    ) {
        self.currentStyle = style
        self.icon = icon
        super.init(frame: .zero)
        setupUI(title: title, message: message, actionTitle: actionTitle)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI(title: String, message: String?, actionTitle: String?) {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 0

        iconImageView.contentMode = .scaleAspectFit
        iconImageView.isHidden = currentStyle == .loading

        activityIndicator.color = ThemeTokens.Color.textTertiary
        activityIndicator.hidesWhenStopped = false
        activityIndicator.isHidden = currentStyle != .loading
        if currentStyle == .loading {
            activityIndicator.startAnimating()
        }

        titleLabel.font = ThemeTokens.Typography.sectionTitle
        titleLabel.textColor = ThemeTokens.Color.text
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.text = title

        messageLabel.font = ThemeTokens.Typography.metadata
        messageLabel.textColor = ThemeTokens.Color.textSecondary
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 3
        messageLabel.lineBreakMode = .byTruncatingTail
        messageLabel.text = message
        messageLabel.isHidden = message == nil

        actionButton.titleLabel?.font = ThemeTokens.Typography.button
        actionButton.setTitleColor(ThemeTokens.Color.surface, for: .normal)
        actionButton.backgroundColor = ThemeTokens.Color.primary
        actionButton.layer.cornerRadius = ThemeTokens.CornerRadius.md
        actionButton.clipsToBounds = true
        actionButton.setTitle(actionTitle, for: .normal)
        actionButton.isHidden = actionTitle == nil
        actionButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 24)
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
        actionButton.snp.makeConstraints { make in
            make.height.equalTo(44)
        }

        let iconContainer = UIView()
        if currentStyle == .loading {
            iconContainer.addSubview(activityIndicator)
            activityIndicator.snp.makeConstraints { make in
                make.edges.equalToSuperview()
                make.width.height.equalTo(48)
            }
        } else {
            iconContainer.addSubview(iconImageView)
            iconImageView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
                make.width.height.equalTo(48)
            }
        }
        iconContainer.snp.makeConstraints { make in
            make.width.height.equalTo(48)
        }

        let titleSpacer = UIView()
        titleSpacer.snp.makeConstraints { make in
            make.height.equalTo(16)
        }

        let messageSpacer = UIView()
        messageSpacer.snp.makeConstraints { make in
            make.height.equalTo(8)
        }

        let buttonSpacer = UIView()
        buttonSpacer.snp.makeConstraints { make in
            make.height.equalTo(20)
        }

        stack.addArrangedSubview(iconContainer)
        stack.addArrangedSubview(titleSpacer)
        stack.addArrangedSubview(titleLabel)
        if message != nil {
            stack.addArrangedSubview(messageSpacer)
            stack.addArrangedSubview(messageLabel)
        }
        if actionTitle != nil {
            stack.addArrangedSubview(buttonSpacer)
            stack.addArrangedSubview(actionButton)
        }

        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.greaterThanOrEqualToSuperview()
            make.bottom.lessThanOrEqualToSuperview()
            make.centerY.equalToSuperview().priority(.medium)
            make.leading.greaterThanOrEqualToSuperview().offset(ThemeTokens.Spacing.xl)
            make.trailing.lessThanOrEqualToSuperview().offset(-ThemeTokens.Spacing.xl)
            make.width.lessThanOrEqualTo(280)
        }

        updateIcon()
    }

    private func updateIcon() {
        let iconColor: UIColor
        switch currentStyle {
        case .error:
            iconColor = ThemeTokens.Color.error
        case .offline:
            iconColor = ThemeTokens.Color.offline
        default:
            iconColor = ThemeTokens.Color.textTertiary
        }
        iconImageView.image = icon.templateImage(pointSize: 48, weight: .light)
        iconImageView.tintColor = iconColor
    }

    @objc private func actionTapped() {
        onActionTapped?()
    }
}
