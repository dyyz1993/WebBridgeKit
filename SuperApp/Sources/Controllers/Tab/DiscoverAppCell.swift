import UIKit
import SnapKit
import WebBridgeKit

class DiscoverAppCell: UICollectionViewCell {

    static let identifier = "DiscoverAppCell"

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

    private let topRowStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.alignment = .center
        sv.spacing = ThemeTokens.Spacing.sm
        return sv
    }()

    private let iconContainer: UIView = {
        let view = UIView()
        view.layer.cornerRadius = ThemeTokens.CornerRadius.md
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

    private let textStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = ThemeTokens.Spacing.xs
        sv.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return sv
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = ThemeColors.current.text
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    private let sizeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .regular)
        label.textColor = ThemeColors.current.textSecondary
        label.numberOfLines = 1
        return label
    }()

    private let badgeView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = ThemeTokens.CornerRadius.md
        return view
    }()

    private let badgeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 10, weight: .bold)
        label.textAlignment = .center
        return label
    }()

    private let bottomRowStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.alignment = .center
        sv.spacing = ThemeTokens.Spacing.xs
        return sv
    }()

    private let detailLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .regular)
        label.textColor = ThemeColors.current.textSecondary
        label.numberOfLines = 1
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = ThemeColors.current.textSecondary
        label.numberOfLines = 2
        return label
    }()

    private let statusDot: UIView = {
        let v = UIView()
        v.layer.cornerRadius = ThemeTokens.CornerRadius.xs
        v.clipsToBounds = true
        return v
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

    private func setupUI() {
        contentView.backgroundColor = .clear
        contentView.addSubview(cardView)

        iconContainer.layer.addSublayer(gradientLayer)
        iconContainer.addSubview(iconImageView)
        textStack.addArrangedSubview(nameLabel)
        textStack.addArrangedSubview(sizeLabel)
        badgeView.addSubview(badgeLabel)
        bottomRowStack.addArrangedSubview(statusDot)
        bottomRowStack.addArrangedSubview(detailLabel)

        topRowStack.addArrangedSubview(iconContainer)
        topRowStack.addArrangedSubview(textStack)
        topRowStack.addArrangedSubview(badgeView)

        let mainStack = UIStackView(arrangedSubviews: [topRowStack, bottomRowStack, descriptionLabel])
        mainStack.axis = .vertical
        mainStack.spacing = ThemeTokens.Spacing.sm
        cardView.addSubview(mainStack)

        cardView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(4)
        }

        iconContainer.snp.makeConstraints { make in
            make.width.height.equalTo(32)
        }

        iconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(16)
        }

        badgeView.snp.makeConstraints { make in
            make.height.equalTo(18)
        }

        badgeLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 3, left: 6, bottom: 3, right: 6))
        }

        statusDot.snp.makeConstraints { make in
            make.width.height.equalTo(6)
        }

        mainStack.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(14)
            make.bottom.lessThanOrEqualToSuperview().offset(-14)
        }
    }

    func configure(with item: DiscoverItem) {
        nameLabel.text = item.name
        sizeLabel.text = item.cacheSize
        badgeLabel.text = item.cacheStatus.displayText
        badgeLabel.textColor = item.cacheStatus.color
        badgeView.backgroundColor = item.cacheStatus.color.withAlphaComponent(ThemeTokens.Opacity.badge)

        let gradient = Self.gradientColors(for: item.name)
        gradientLayer.colors = [gradient.0.cgColor, gradient.1.cgColor]
        iconImageView.image = Self.icon(for: item.name).image(pointSize: 18)

        statusDot.backgroundColor = item.cacheStatus.color

        if let lastAccessed = item.lastAccessed {
            detailLabel.text = "\(item.cacheStatus.statusTypeText) · \(lastAccessed)"
        } else {
            detailLabel.text = item.cacheStatus.statusTypeText
        }

        if let desc = item.descriptionText, !desc.isEmpty {
            descriptionLabel.text = desc
            descriptionLabel.isHidden = false
        } else {
            descriptionLabel.isHidden = true
        }
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
