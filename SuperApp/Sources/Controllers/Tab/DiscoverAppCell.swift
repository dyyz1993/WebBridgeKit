import UIKit
import SnapKit
import WebBridgeKit

class DiscoverAppCell: UICollectionViewCell {

    static let identifier = "DiscoverAppCell"

    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeTokens.Color.cardBackground
        view.layer.cornerRadius = ThemeTokens.CornerRadius.xl
        let shadow = ThemeTokens.Shadows.Card
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: shadow.offsetX, height: shadow.offsetY)
        view.layer.shadowRadius = shadow.radius
        view.layer.shadowOpacity = Float(shadow.opacity)
        view.clipsToBounds = false
        return view
    }()

    private let iconContainer: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 22
        view.clipsToBounds = true
        return view
    }()

    private let gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.startPoint = CGPoint(x: 0, y: 0)
        layer.endPoint = CGPoint(x: 1, y: 1)
        return layer
    }()

    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .white
        iv.accessibilityLabel = "应用图标"
        return iv
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = ThemeTokens.Color.text
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        label.textAlignment = .center
        return label
    }()

    private let badgeView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = ThemeTokens.CornerRadius.sm
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        return view
    }()

    private let badgeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 9, weight: .bold)
        label.textAlignment = .center
        return label
    }()

    private let detailLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 10, weight: .regular)
        label.textColor = ThemeTokens.Color.textSecondary
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.textAlignment = .center
        return label
    }()

    private let contentStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.alignment = .center
        sv.spacing = ThemeTokens.Spacing.xs
        return sv
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = iconContainer.bounds
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        detailLabel.text = nil
        nameLabel.text = nil
        badgeLabel.text = nil
    }

    private func setupUI() {
        contentView.backgroundColor = .clear
        contentView.addSubview(cardView)

        iconContainer.layer.addSublayer(gradientLayer)
        iconContainer.addSubview(iconImageView)

        badgeView.addSubview(badgeLabel)

        contentStack.addArrangedSubview(iconContainer)
        contentStack.addArrangedSubview(nameLabel)
        contentStack.addArrangedSubview(badgeView)
        contentStack.addArrangedSubview(detailLabel)
        contentStack.setCustomSpacing(ThemeTokens.Spacing.xs, after: iconContainer)
        contentStack.setCustomSpacing(2, after: nameLabel)

        cardView.addSubview(contentStack)

        cardView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        iconContainer.snp.makeConstraints { make in
            make.width.height.equalTo(44)
        }

        iconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(22)
        }

        badgeView.snp.makeConstraints { make in
            make.height.equalTo(16)
        }

        badgeLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6))
        }

        contentStack.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(ThemeTokens.Spacing.md)
            make.bottom.lessThanOrEqualToSuperview().offset(-ThemeTokens.Spacing.md).priority(.high)
        }
    }

    func configure(with item: DiscoverItem) {
        nameLabel.text = item.name
        badgeLabel.text = item.cacheStatus.displayText
        badgeLabel.textColor = item.cacheStatus.color
        badgeView.backgroundColor = item.cacheStatus.color.withAlphaComponent(ThemeTokens.Opacity.badge)

        let gradient = Self.gradientColors(for: item.name)
        gradientLayer.colors = [gradient.0.cgColor, gradient.1.cgColor]
        iconImageView.image = Self.icon(for: item.name).image(pointSize: 22)

        if let lastAccessed = item.lastAccessed {
            detailLabel.text = "\(item.cacheSize) · \(lastAccessed)"
        } else {
            detailLabel.text = item.cacheSize
        }

        detailLabel.isHidden = (detailLabel.text ?? "").isEmpty
        badgeView.isHidden = (badgeLabel.text ?? "").isEmpty
    }

    private static let gradients: [(UIColor, UIColor)] = [
        (ThemeTokens.Color.gradientStart, ThemeTokens.Color.gradientEnd),
        (ThemeTokens.Color.primary, ThemeTokens.Color.gradientEnd),
        (ThemeTokens.Color.primary, ThemeTokens.Color.info),
        (ThemeTokens.Color.success, ThemeTokens.Color.primary),
        (ThemeTokens.Color.error, ThemeTokens.Color.warning),
        (ThemeTokens.Color.gradientEnd, ThemeTokens.Color.gradientStart)
    ]

    private static let icons: [LucideIcon] = [
        .globe,
        .appFill,
        .hardDrive,
        .doc,
        .star,
        .folder,
        .bell,
        .settings
    ]

    private static func gradientColors(for name: String) -> (UIColor, UIColor) {
        gradients[abs(name.hashValue) % gradients.count]
    }

    private static func icon(for name: String) -> LucideIcon {
        icons[abs(name.hashValue) % icons.count]
    }
}
