//
//  TokenCardSection.swift
//  SuperApp
//

import UIKit
import SnapKit
import WebBridgeKit

extension ComponentCatalogViewController {

    // MARK: - Section 13: Token Card

    func buildTokenCardSection() {
        let header = makeSectionHeader(
            title: "Token Card (PushTokenCardCell)",
            tokenInfo: "PushTokenCardCell — gradient background, URL, device token, copy button"
        )

        let container = UIView()
        container.accessibilityIdentifier = "CatalogSection_TokenCard"

        let cardView = TokenCardDemoView()
        container.addSubview(cardView)
        cardView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(4)
        }

        container.snp.makeConstraints { make in
            make.height.equalTo(110)
        }
        addSection(header, container)
    }
}

// MARK: - Token Card Demo View

class TokenCardDemoView: UIView {

    private let gradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = ThemeTokens.CornerRadius.xl
        clipsToBounds = true
        gradientLayer.colors = [
            ThemeColors.current.gradientStart.cgColor,
            ThemeColors.current.gradientEnd.cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = ThemeTokens.CornerRadius.xl
        layer.insertSublayer(gradientLayer, at: 0)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            gradientLayer.colors = [
                ThemeColors.current.gradientStart.cgColor,
                ThemeColors.current.gradientEnd.cgColor
            ]
        }
    }

    private func setupUI() {
        let titleLabel = UILabel()
        titleLabel.text = "Push Token"
        titleLabel.font = ThemeTokens.Typography.footnote
        titleLabel.textColor = ThemeTokens.Color.background.withAlphaComponent(0.9)

        let urlLabel = UILabel()
        urlLabel.text = "https://api.day.app"
        urlLabel.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        urlLabel.textColor = ThemeTokens.Color.background.withAlphaComponent(0.85)
        urlLabel.numberOfLines = 1

        let tokenLabel = UILabel()
        tokenLabel.text = "Device: a1b2c3d4e5f6..."
        tokenLabel.font = UIFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        tokenLabel.textColor = ThemeTokens.Color.background.withAlphaComponent(0.7)

        let copyButton = UIButton(type: .system)
        copyButton.setImage(LucideIcon.copy.templateImage(pointSize: 16, weight: .semibold), for: .normal)
        copyButton.tintColor = ThemeTokens.Color.background
        copyButton.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        copyButton.layer.cornerRadius = ThemeTokens.CornerRadius.xl

        addSubview(titleLabel)
        addSubview(urlLabel)
        addSubview(tokenLabel)
        addSubview(copyButton)

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.left.equalToSuperview().offset(16)
        }
        urlLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.left.equalToSuperview().offset(16)
            make.right.equalTo(copyButton.snp.left).offset(-12)
        }
        tokenLabel.snp.makeConstraints { make in
            make.top.equalTo(urlLabel.snp.bottom).offset(4)
            make.left.equalToSuperview().offset(16)
            make.right.equalTo(copyButton.snp.left).offset(-12)
            make.bottom.equalToSuperview().offset(-16)
        }
        copyButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(32)
        }
    }
}
