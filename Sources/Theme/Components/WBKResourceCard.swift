import UIKit
import SnapKit

public final class WBKResourceCard: UIView {

    public enum Style {
        case `default`
        case compact
        case withAction
    }

    public enum Status {
        case normal
        case cached
        case pending
        case error
        case offline
    }

    public var icon: UIImage? {
        didSet { iconImageView.image = icon }
    }

    public var title: String {
        didSet { titleLabel.text = title }
    }

    public var metadata: String? {
        didSet {
            metadataLabel.text = metadata
            metadataLabel.isHidden = metadata == nil
        }
    }

    public var subtitle: String? {
        didSet {
            subtitleLabel.text = subtitle
            subtitleLabel.isHidden = subtitle == nil
        }
    }

    public var status: Status {
        didSet { updateStatus() }
    }

    public var trailingBadge: WBKStatusBadge? {
        didSet { updateTrailingBadge() }
    }

    public var trailingAction: (() -> Void)?

    public var isEnabled: Bool = true {
        didSet {
            alpha = isEnabled ? 1.0 : ThemeTokens.Opacity.disabled
            isUserInteractionEnabled = isEnabled
        }
    }

    public var isLoading: Bool = false {
        didSet {
            if isLoading {
                cardView.alpha = 0
                shimmerSkeleton.isHidden = false
                shimmerSkeleton.configure(shapes: [
                    .roundedRect(
                        frame: bounds.isEmpty
                            ? CGRect(x: 0, y: 0, width: 300, height: ThemeTokens.ComponentContract.ResourceCard.minHeight)
                            : bounds,
                        cornerRadius: ThemeTokens.ComponentContract.ResourceCard.cornerRadius
                    )
                ])
                shimmerSkeleton.startShimmer()
            } else {
                cardView.alpha = 1
                shimmerSkeleton.stopShimmer()
            }
        }
    }

    public var onTap: (() -> Void)?

    private let cardView = UIView()
    private let shimmerSkeleton = WBKSkeletonView()
    private let iconImageView = UIImageView()
    private let textStack = UIStackView()
    private let titleLabel = UILabel()
    private let metadataLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let badgeContainer = UIView()
    private let actionButton = UIButton(type: .system)
    private var badgeView: WBKStatusBadge?

    public init(title: String, style: Style = .default) {
        self.title = title
        self.style = style
        self.status = .normal
        super.init(frame: .zero)
        accessibilityIdentifier = "wbk_resource_card"
        setupUI()
        applyStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public let style: Style

    private func setupUI() {
        addSubview(cardView)
        addSubview(shimmerSkeleton)
        cardView.addSubview(iconImageView)

        textStack.axis = .vertical
        textStack.spacing = ThemeTokens.Spacing.xxs
        textStack.alignment = .leading
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(metadataLabel)
        textStack.addArrangedSubview(subtitleLabel)
        cardView.addSubview(textStack)

        cardView.addSubview(badgeContainer)
        cardView.addSubview(actionButton)

        cardView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        shimmerSkeleton.isHidden = true
        shimmerSkeleton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        cardView.backgroundColor = ThemeTokens.Color.cardBackground
        cardView.layer.cornerRadius = ThemeTokens.ComponentContract.ResourceCard.cornerRadius
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOffset = CGSize(width: ThemeTokens.Shadows.card.offsetX, height: ThemeTokens.Shadows.card.offsetY)
        cardView.layer.shadowRadius = ThemeTokens.Shadows.card.radius
        cardView.layer.shadowOpacity = Float(ThemeTokens.Shadows.card.opacity)

        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = ThemeTokens.Color.primary
        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(ThemeTokens.ComponentContract.ResourceCard.padding)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(ThemeTokens.ComponentContract.ResourceCard.iconSize)
        }

        titleLabel.font = ThemeTokens.Typography.cardTitle
        titleLabel.textColor = ThemeTokens.Color.text
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.text = title

        metadataLabel.font = ThemeTokens.Typography.metadata
        metadataLabel.textColor = ThemeTokens.Color.textTertiary
        metadataLabel.numberOfLines = 1
        metadataLabel.lineBreakMode = .byTruncatingTail
        metadataLabel.isHidden = true

        subtitleLabel.font = ThemeTokens.Typography.body
        subtitleLabel.textColor = ThemeTokens.Color.textSecondary
        subtitleLabel.numberOfLines = 2
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.isHidden = true

        textStack.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(ThemeTokens.Spacing.md)
            make.top.equalToSuperview().offset(ThemeTokens.Spacing.md)
            make.bottom.equalToSuperview().offset(-ThemeTokens.Spacing.md)
            make.trailing.lessThanOrEqualTo(badgeContainer.snp.leading).offset(-ThemeTokens.Spacing.sm)
        }

        badgeContainer.snp.makeConstraints { make in
            make.trailing.equalTo(style == .withAction ? actionButton.snp.leading : cardView.snp.trailing).offset(-ThemeTokens.Spacing.md)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(0)
        }

        actionButton.isHidden = style != .withAction
        actionButton.setImage(LucideIcon.chevronRight.templateImage(pointSize: ThemeTokens.Icons.Sizes.sm), for: .normal)
        actionButton.tintColor = ThemeTokens.Color.textTertiary
        actionButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-ThemeTokens.Spacing.md)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(ThemeTokens.ComponentContract.TapTarget.minimumWidth)
        }
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        cardView.addGestureRecognizer(tap)
        cardView.isUserInteractionEnabled = true

        snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(ThemeTokens.ComponentContract.ResourceCard.minHeight)
            make.height.lessThanOrEqualTo(ThemeTokens.ComponentContract.ResourceCard.maxHeight)
        }
    }

    private func applyStyle() {
        if style == .compact {
            subtitleLabel.removeFromSuperview()
        }
    }

    private func updateStatus() {
        let badgeStyle: WBKStatusBadge.Style
        let badgeText: String

        switch status {
        case .normal:
            trailingBadge = nil
            return
        case .cached:
            badgeStyle = .success
            badgeText = "已缓存"
        case .pending:
            badgeStyle = .warning
            badgeText = "等待中"
        case .error:
            badgeStyle = .error
            badgeText = "错误"
        case .offline:
            badgeStyle = .offline
            badgeText = "离线"
        }

        if trailingBadge == nil {
            trailingBadge = WBKStatusBadge(text: badgeText, style: badgeStyle)
        }
    }

    private func updateTrailingBadge() {
        badgeView?.removeFromSuperview()
        badgeView = trailingBadge

        if let badge = trailingBadge {
            badgeContainer.addSubview(badge)
            badge.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            badgeContainer.snp.remakeConstraints { make in
                let trailingAnchor = style == .withAction ? actionButton.snp.leading : cardView.snp.trailing
                make.trailing.equalTo(trailingAnchor).offset(-ThemeTokens.Spacing.md)
                make.centerY.equalToSuperview()
            }
        } else {
            badgeContainer.snp.remakeConstraints { make in
                let trailingAnchor = style == .withAction ? actionButton.snp.leading : cardView.snp.trailing
                make.trailing.equalTo(trailingAnchor).offset(-ThemeTokens.Spacing.md)
                make.centerY.equalToSuperview()
                make.width.height.equalTo(0)
            }
        }
    }

    @objc private func handleTap() {
        UIView.animate(
            withDuration: ThemeTokens.Animation.fast.duration,
            animations: {
                self.alpha = ThemeTokens.Opacity.pressed
            },
            completion: { _ in
                UIView.animate(withDuration: ThemeTokens.Animation.fast.duration) {
                    self.alpha = 1.0
                }
            }
        )
        onTap?()
    }

    @objc private func actionTapped() {
        trailingAction?()
    }
}
