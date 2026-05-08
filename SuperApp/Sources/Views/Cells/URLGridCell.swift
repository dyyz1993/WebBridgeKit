import UIKit
import SnapKit
import WebBridgeKit

class URLGridCell: UICollectionViewCell {

    static let identifier = "URLGridCell"

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeColors.current.cardBackground
        view.layer.cornerRadius = 14
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 12
        view.layer.shadowOpacity = 0.08
        return view
    }()

    private let iconContainer: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 11
        v.layer.masksToBounds = true
        return v
    }()

    private let iconGradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.cornerRadius = 11
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
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.textColor = ThemeColors.current.text
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let statusDot: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 3
        v.backgroundColor = ThemeTokens.Colors.Light.success
        return v
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        label.textColor = ThemeTokens.Colors.Light.textTertiary
        return label
    }()

    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        label.textColor = ThemeTokens.Colors.Light.textTertiary
        return label
    }()

    private var currentHistory: WebPageHistory?

    var onPinToggle: (() -> Void)?
    var onFavoriteToggle: (() -> Void)?

    private static let gradients: [[UIColor]] = [
        [UIColor(red: 0.4, green: 0.494, blue: 0.918, alpha: 1), UIColor(red: 0.463, green: 0.294, blue: 0.635, alpha: 1)],
        [UIColor(red: 0.941, green: 0.576, blue: 0.984, alpha: 1), UIColor(red: 0.961, green: 0.341, blue: 0.424, alpha: 1)],
        [UIColor(red: 0.310, green: 0.671, blue: 0.992, alpha: 1), UIColor(red: 0.0, green: 0.949, blue: 0.996, alpha: 1)],
        [UIColor(red: 0.263, green: 0.914, blue: 0.482, alpha: 1), UIColor(red: 0.220, green: 0.976, blue: 0.843, alpha: 1)]
    ]

    private static let lucideIcons: [LucideIcon] = [
        .globe, .appFill, .doc, .settings
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
            statusDot.backgroundColor = ThemeTokens.Colors.Light.success
            statusLabel.text = L10n.tr("discover.badge.offline")
            statusLabel.textColor = ThemeTokens.Colors.Light.success
        } else if history.cachedSize > 0 {
            statusDot.backgroundColor = ThemeTokens.Colors.Light.warning
            statusLabel.text = L10n.tr("discover.badge.needs_update")
            statusLabel.textColor = ThemeTokens.Colors.Light.warning
        } else {
            statusDot.backgroundColor = ThemeTokens.Colors.Light.textTertiary
            statusLabel.text = L10n.tr("discover.badge.not_cached")
            statusLabel.textColor = ThemeTokens.Colors.Light.textTertiary
        }

        let elapsed = Date().timeIntervalSince(history.lastVisitDate)
        if elapsed < 60 {
            timeLabel.text = "just now"
        } else if elapsed < 3600 {
            timeLabel.text = "\(Int(elapsed / 60)) min ago"
        } else if elapsed < 86400 {
            timeLabel.text = "\(Int(elapsed / 3600))h ago"
        } else {
            timeLabel.text = "\(Int(elapsed / 86400))d ago"
        }
    }
}
