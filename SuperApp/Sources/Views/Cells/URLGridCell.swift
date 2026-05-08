//
//  URLGridCell.swift
//  SuperApp
//

import UIKit
import SnapKit
import WebBridgeKit

class URLGridCell: UICollectionViewCell {

    static let identifier = "URLGridCell"

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeColors.current.cardBackground
        view.layer.cornerRadius = ThemeTokens.CornerRadius.lg
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 8
        view.layer.shadowOpacity = 0.06
        return view
    }()

    private let iconContainer: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 22
        v.layer.masksToBounds = true
        return v
    }()

    private let iconGradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.cornerRadius = 22
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

    private let letterLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        label.textColor = ThemeColors.current.text
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let statusDot: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 3.5
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

    private let tokenPreviewLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        label.textColor = ThemeTokens.Colors.Light.textTertiary
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()

    private var currentHistory: WebPageHistory?

    var onPinToggle: (() -> Void)?
    var onFavoriteToggle: (() -> Void)?

    private static let gradients: [[UIColor]] = [
        [UIColor(red: 1.0, green: 0.4, blue: 0.6, alpha: 1), UIColor(red: 0.9, green: 0.3, blue: 0.5, alpha: 1)],
        [UIColor(red: 0.4, green: 0.5, blue: 1.0, alpha: 1), UIColor(red: 0.25, green: 0.35, blue: 0.95, alpha: 1)],
        [UIColor(red: 0.35, green: 0.8, blue: 0.5, alpha: 1), UIColor(red: 0.2, green: 0.65, blue: 0.4, alpha: 1)],
        [UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1), UIColor(red: 0.95, green: 0.45, blue: 0.1, alpha: 1)]
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
        letterLabel.text = nil
        tokenPreviewLabel.text = nil
        tokenPreviewLabel.isHidden = true
    }

    private func setupUI() {
        contentView.backgroundColor = .clear
        backgroundColor = .clear

        contentView.addSubview(containerView)

        iconContainer.layer.insertSublayer(iconGradientLayer, at: 0)
        iconContainer.addSubview(faviconImageView)
        iconContainer.addSubview(letterLabel)

        containerView.addSubview(iconContainer)
        containerView.addSubview(titleLabel)
        containerView.addSubview(statusDot)
        containerView.addSubview(statusLabel)
        containerView.addSubview(timeLabel)
        containerView.addSubview(tokenPreviewLabel)

        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(4)
        }

        iconContainer.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(14)
            make.left.equalToSuperview().offset(14)
            make.width.height.equalTo(44)
        }

        faviconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(24)
        }

        letterLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconContainer.snp.bottom).offset(10)
            make.left.equalToSuperview().offset(14)
            make.right.equalToSuperview().offset(-14)
        }

        statusDot.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.left.equalToSuperview().offset(14)
            make.width.height.equalTo(7)
        }

        statusLabel.snp.makeConstraints { make in
            make.centerY.equalTo(statusDot)
            make.left.equalTo(statusDot.snp.right).offset(6)
        }

        timeLabel.snp.makeConstraints { make in
            make.centerY.equalTo(statusDot)
            make.right.equalToSuperview().offset(-14)
        }

        tokenPreviewLabel.snp.makeConstraints { make in
            make.top.equalTo(statusDot.snp.bottom).offset(6)
            make.left.equalToSuperview().offset(14)
            make.right.equalToSuperview().offset(-14)
            make.bottom.lessThanOrEqualToSuperview().offset(-12)
        }
    }

    private func updateUI() {
        guard let history = currentHistory else { return }

        let titleText = history.title ?? (URL(string: history.url)?.host ?? history.url)
        titleLabel.text = titleText

        if let favicon = history.favicon, let image = UIImage(data: favicon) {
            faviconImageView.image = image.withRenderingMode(.alwaysTemplate)
            faviconImageView.isHidden = false
            letterLabel.isHidden = true
        } else {
            let firstLetter = String(titleText.prefix(1)).uppercased()
            letterLabel.text = firstLetter
            letterLabel.isHidden = false
            faviconImageView.isHidden = true
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
