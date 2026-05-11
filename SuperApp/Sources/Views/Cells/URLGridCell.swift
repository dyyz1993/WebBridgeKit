import UIKit
import SnapKit
import WebBridgeKit

class URLGridCell: UICollectionViewCell {

    static let identifier = "URLGridCell"

    private let containerView: UIView = {
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

    private let iconContainer: UIView = {
        let v = UIView()
        v.layer.cornerRadius = ThemeTokens.CornerRadius.lg
        v.layer.masksToBounds = true
        return v
    }()

    private let iconGradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.cornerRadius = ThemeTokens.CornerRadius.lg
        layer.startPoint = CGPoint(x: 0, y: 0)
        layer.endPoint = CGPoint(x: 1, y: 1)
        return layer
    }()

    private let faviconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .white
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.footnote
        label.textColor = ThemeColors.current.text
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let statusDot: UIView = {
        let v = UIView()
        v.layer.cornerRadius = ThemeTokens.CornerRadius.xs
        v.backgroundColor = ThemeTokens.Color.success
        return v
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.caption1
        label.textColor = ThemeTokens.Color.textTertiary
        return label
    }()

    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.caption2
        label.textColor = ThemeTokens.Color.textTertiary
        return label
    }()

    private let tokenBadge: UIView = {
        let v = UIView()
        v.backgroundColor = ThemeColors.current.primary.withAlphaComponent(0.08)
        v.layer.cornerRadius = ThemeTokens.CornerRadius.sm
        v.clipsToBounds = true
        v.isHidden = true
        return v
    }()

    private let tokenKeyIcon: UIImageView = {
        let iv = UIImageView()
        iv.image = LucideIcon.key.templateImage(pointSize: 10, weight: .medium)
        iv.tintColor = ThemeColors.current.primary
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let tokenLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        label.textColor = ThemeColors.current.primary
        label.numberOfLines = 1
        return label
    }()

    private var currentHistory: WebPageHistory?

    var onPinToggle: (() -> Void)?
    var onFavoriteToggle: (() -> Void)?

    private static let gradients: [[UIColor]] = [
        [ThemeTokens.Color.gradientStart, ThemeTokens.Color.gradientEnd],
        [ThemeTokens.Color.gradientEnd, ThemeTokens.Color.error],
        [ThemeTokens.Color.info, ThemeTokens.Color.success],
        [ThemeTokens.Color.success, ThemeTokens.Color.info],
        [ThemeTokens.Color.error, ThemeTokens.Color.warning],
        [ThemeTokens.Color.gradientEnd, ThemeTokens.Color.gradientEnd.withAlphaComponent(0.6)],
        [ThemeTokens.Color.warning, ThemeTokens.Color.warning.withAlphaComponent(0.7)],
        [ThemeTokens.Color.success, ThemeTokens.Color.success.withAlphaComponent(0.7)]
    ]

    private static let lucideIcons: [LucideIcon] = [
        .globe, .appFill, .doc, .settings, .star, .folder, .bell, .hardDrive
    ]

    var history: WebPageHistory? {
        didSet {
            currentHistory = history
            updateUI()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        iconGradientLayer.frame = iconContainer.bounds
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        currentHistory = nil
        faviconImageView.image = nil
        tokenBadge.isHidden = true
    }

    private func setupUI() {
        contentView.backgroundColor = .clear
        backgroundColor = .clear

        contentView.addSubview(containerView)
        iconContainer.layer.insertSublayer(iconGradientLayer, at: 0)
        iconContainer.addSubview(faviconImageView)

        containerView.addSubview(iconContainer)
        containerView.addSubview(titleLabel)
        containerView.addSubview(statusDot)
        containerView.addSubview(statusLabel)
        containerView.addSubview(timeLabel)
        containerView.addSubview(tokenBadge)
        tokenBadge.addSubview(tokenKeyIcon)
        tokenBadge.addSubview(tokenLabel)

        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        iconContainer.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(14)
            make.left.equalToSuperview().offset(14)
            make.width.height.equalTo(42)
        }

        faviconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(20)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconContainer.snp.bottom).offset(10)
            make.left.equalToSuperview().offset(12)
            make.right.equalToSuperview().offset(-12)
        }

        statusDot.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(6)
            make.left.equalToSuperview().offset(12)
            make.width.height.equalTo(6)
        }

        statusLabel.snp.makeConstraints { make in
            make.centerY.equalTo(statusDot)
            make.left.equalTo(statusDot.snp.right).offset(5)
        }

        timeLabel.snp.makeConstraints { make in
            make.centerY.equalTo(statusDot)
            make.right.equalToSuperview().offset(-12)
        }

        tokenBadge.snp.makeConstraints { make in
            make.bottom.equalToSuperview().offset(-10)
            make.left.equalToSuperview().offset(12)
            make.height.equalTo(18)
        }

        tokenKeyIcon.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalToSuperview().offset(5)
            make.width.height.equalTo(10)
        }

        tokenLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalTo(tokenKeyIcon.snp.right).offset(3)
            make.right.equalToSuperview().offset(-5)
        }
    }

    private func updateUI() {
        guard let history = currentHistory else { return }

        let titleText = history.title ?? (URL(string: history.url)?.host ?? history.url)
        titleLabel.text = titleText

        if let favicon = history.favicon, let image = UIImage(data: favicon) {
            faviconImageView.image = image.withRenderingMode(.alwaysTemplate)
            faviconImageView.isHidden = false
        } else {
            let iconIndex = abs(titleText.hashValue) % Self.lucideIcons.count
            let icon = Self.lucideIcons[iconIndex]
            faviconImageView.image = icon.image(pointSize: 20, weight: .medium)
            faviconImageView.isHidden = false
        }

        let colors = Self.gradients[abs(titleText.hashValue) % Self.gradients.count]
        iconGradientLayer.colors = colors.map { $0.cgColor }

        if history.isCached && history.cachedSize > 0 {
            statusDot.backgroundColor = ThemeTokens.Color.success
            statusLabel.text = L10n.tr("discover.badge.offline")
            statusLabel.textColor = ThemeTokens.Color.success
        } else if history.cachedSize > 0 {
            statusDot.backgroundColor = ThemeTokens.Color.warning
            statusLabel.text = L10n.tr("discover.badge.needs_update")
            statusLabel.textColor = ThemeTokens.Color.warning
        } else {
            statusDot.backgroundColor = ThemeTokens.Color.textTertiary
            statusLabel.text = L10n.tr("discover.badge.not_cached")
            statusLabel.textColor = ThemeTokens.Color.textTertiary
        }

        let elapsed = Date().timeIntervalSince(history.lastVisitDate)
        if elapsed < 60 {
            timeLabel.text = L10n.tr("discover.time.just_now")
        } else if elapsed < 3600 {
            timeLabel.text = L10n.tr("discover.time.min_ago", "\(Int(elapsed / 60))")
        } else if elapsed < 86400 {
            timeLabel.text = L10n.tr("discover.time.hour_ago", "\(Int(elapsed / 3600))")
        } else {
            timeLabel.text = L10n.tr("discover.time.days_ago", "\(Int(elapsed / 86400))")
        }

        if let token = getMaskedToken() {
            tokenLabel.text = token
            tokenBadge.isHidden = false
        } else {
            tokenBadge.isHidden = true
        }
    }

    private func getMaskedToken() -> String? {
        let key = UserDefaults.standard.string(forKey: "com.webbridgekit.bark.key") ?? ""
        guard key.count > 8 else { return nil }
        let prefix = key.prefix(4)
        let suffix = key.suffix(4)
        return "\(prefix)...\(suffix)"
    }
}
