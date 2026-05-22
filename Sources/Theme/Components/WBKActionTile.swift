import UIKit
import SnapKit

public final class WBKActionTile: UIView {

    public enum Style: Equatable {
        case `default`
        case success
        case warning
        case error
        case primary
    }

    public var icon: LucideIcon {
        didSet { updateIcon() }
    }

    public var title: String {
        didSet { titleLabel.text = title }
    }

    public var subtitle: String? {
        didSet {
            subtitleLabel.text = subtitle
            subtitleLabel.isHidden = subtitle == nil
        }
    }

    public var badge: String? {
        didSet { updateBadge() }
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
            containerView.alpha = isLoading ? 0 : 1
            containerView.isUserInteractionEnabled = !isLoading
            if isLoading {
                activityIndicator.startAnimating()
            } else {
                activityIndicator.stopAnimating()
            }
        }
    }

    public var onTap: (() -> Void)?

    private let containerView = UIView()
    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = ThemeTokens.Color.textTertiary
        indicator.hidesWhenStopped = true
        return indicator
    }()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let badgeView = UILabel()

    public init(icon: LucideIcon, title: String, style: Style = .default) {
        self.icon = icon
        self.title = title
        self.style = style
        super.init(frame: .zero)
        accessibilityIdentifier = "wbk_action_tile"
        setupUI()
        applyStyle()
        updateIcon()
        updateBadge()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        addSubview(containerView)
        addSubview(activityIndicator)
        containerView.addSubview(iconImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)
        containerView.addSubview(badgeView)

        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.greaterThanOrEqualTo(72)
            make.height.equalTo(72)
        }

        containerView.layer.cornerRadius = ThemeTokens.CornerRadius.card
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        containerView.layer.shadowRadius = 8
        containerView.layer.shadowOpacity = 0.08
        containerView.clipsToBounds = false

        iconImageView.contentMode = .scaleAspectFit
        iconImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(14)
            make.width.height.equalTo(22)
        }

        titleLabel.font = ThemeTokens.Typography.caption1
        titleLabel.textColor = ThemeTokens.Color.text
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.text = title
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(6)
            make.top.equalTo(iconImageView.snp.bottom).offset(6)
        }

        subtitleLabel.font = ThemeTokens.Typography.caption1
        subtitleLabel.textColor = ThemeTokens.Color.textTertiary
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 1
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.isHidden = true
        subtitleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(6)
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
            make.bottom.lessThanOrEqualToSuperview().offset(-6)
        }

        badgeView.font = ThemeTokens.Typography.badge
        badgeView.textColor = ThemeTokens.Color.surface
        badgeView.textAlignment = .center
        badgeView.numberOfLines = 1
        badgeView.backgroundColor = ThemeTokens.Color.error
        badgeView.layer.cornerRadius = 8
        badgeView.clipsToBounds = true
        badgeView.isHidden = true
        badgeView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(6)
            make.trailing.equalToSuperview().offset(-6)
            make.width.height.greaterThanOrEqualTo(16)
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true

        activityIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    private func applyStyle() {
        containerView.backgroundColor = ThemeTokens.Color.surface

        let iconColor: UIColor
        switch style {
        case .default:
            iconColor = ThemeTokens.Color.primary
        case .success:
            iconColor = ThemeTokens.Color.success
        case .warning:
            iconColor = ThemeTokens.Color.warning
        case .error:
            iconColor = ThemeTokens.Color.error
        case .primary:
            containerView.backgroundColor = ThemeTokens.Color.primary
            iconColor = ThemeTokens.Color.surface
        }
        iconImageView.tintColor = iconColor
    }

    private func updateIcon() {
        iconImageView.image = icon.templateImage(pointSize: 22)
    }

    private func updateBadge() {
        if let badge = badge, !badge.isEmpty {
            badgeView.text = badge
            badgeView.isHidden = false
            badgeView.snp.updateConstraints { make in
                make.width.height.greaterThanOrEqualTo(16)
            }
            let textWidth = (badge as NSString).size(withAttributes: [.font: badgeView.font!]).width + 10
            badgeView.snp.remakeConstraints { make in
                make.top.equalToSuperview().offset(6)
                make.trailing.equalToSuperview().offset(-6)
                make.height.greaterThanOrEqualTo(16)
                make.width.greaterThanOrEqualTo(max(16, textWidth))
            }
        } else {
            badgeView.isHidden = true
        }
    }

    @objc private func handleTap() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        UIView.animate(
            withDuration: 0.1,
            animations: {
                self.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
                self.alpha = ThemeTokens.Opacity.pressed
            },
            completion: { _ in
                UIView.animate(withDuration: 0.1) {
                    self.transform = .identity
                    self.alpha = 1.0
                }
            }
        )

        onTap?()
    }
}
