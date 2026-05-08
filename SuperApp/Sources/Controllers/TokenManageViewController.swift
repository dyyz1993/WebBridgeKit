//
//  TokenManageViewController.swift
//  SuperApp
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa
import WebBridgeKit

class TokenManageViewController: BaseViewController<TokenManageViewModel> {

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.alwaysBounceVertical = true
        return sv
    }()

    private let stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 16
        return sv
    }()

    private let pushURLCard = TokenManageViewController.makeCard()
    private let pushURLLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        label.textColor = ThemeColors.current.text
        label.numberOfLines = 0
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()

    private let copyButton: UIButton = {
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.image = LucideIcon.copy.image(pointSize: 16)
            config.title = L10n.tr("common.copy")
            config.imagePadding = 4
            config.baseForegroundColor = .white
            let button = UIButton(configuration: config)
            button.backgroundColor = ThemeColors.current.primary
            button.layer.cornerRadius = ThemeTokens.CornerRadius.sm
            button.layer.masksToBounds = true
            button.titleLabel?.font = ThemeTokens.Typography.subheadline
            button.tintColor = .white
            return button
        } else {
            let button = UIButton(type: .system)
            button.setImage(LucideIcon.copy.image(pointSize: 16), for: .normal)
            button.setTitle(L10n.tr("common.copy"), for: .normal)
            button.backgroundColor = ThemeColors.current.primary
            button.layer.cornerRadius = ThemeTokens.CornerRadius.sm
            button.layer.masksToBounds = true
            button.titleLabel?.font = ThemeTokens.Typography.subheadline
            button.tintColor = .white
            return button
        }
    }()

    private let shareButton: UIButton = {
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.image = LucideIcon.share.image(pointSize: 16)
            config.title = L10n.tr("common.share")
            config.imagePadding = 4
            config.baseForegroundColor = .white
            let button = UIButton(configuration: config)
            button.backgroundColor = ThemeColors.current.surface
            button.layer.cornerRadius = ThemeTokens.CornerRadius.sm
            button.layer.masksToBounds = true
            button.titleLabel?.font = ThemeTokens.Typography.subheadline
            button.tintColor = .white
            return button
        } else {
            let button = UIButton(type: .system)
            button.setImage(LucideIcon.share.image(pointSize: 16), for: .normal)
            button.setTitle(L10n.tr("common.share"), for: .normal)
            button.backgroundColor = ThemeColors.current.surface
            button.layer.cornerRadius = ThemeTokens.CornerRadius.sm
            button.layer.masksToBounds = true
            button.titleLabel?.font = ThemeTokens.Typography.subheadline
            button.tintColor = .white
            return button
        }
    }()

    private let qrCard = TokenManageViewController.makeCard()
    private let qrImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.layer.cornerRadius = ThemeTokens.CornerRadius.sm
        iv.layer.masksToBounds = true
        return iv
    }()

    private let tokenCard = TokenManageViewController.makeCard()
    private let tokenLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        label.textColor = ThemeColors.current.textSecondary
        label.numberOfLines = 0
        label.lineBreakMode = .byCharWrapping
        return label
    }()

    private let statsCard = TokenManageViewController.makeCard()
    private let statsLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.body
        label.textColor = ThemeColors.current.textSecondary
        label.numberOfLines = 0
        return label
    }()

    private static func makeCard() -> UIView {
        let view = UIView()
        view.backgroundColor = ThemeColors.current.cardBackground
        view.layer.cornerRadius = ThemeTokens.CornerRadius.lg
        return view
    }

    private static func makeCardHeader(_ text: String) -> UILabel {
        let label = UILabel()
        label.font = ThemeTokens.Typography.footnote
        label.textColor = ThemeColors.current.textSecondary
        label.text = text
        return label
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.tr("token.manage.title")
        setupUI()
        updateData()
    }

    private func setupUI() {
        view.backgroundColor = ThemeColors.current.background

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)

        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        stackView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.left.right.equalToSuperview().inset(16)
            make.width.equalTo(view).offset(-32)
            make.bottom.equalToSuperview().offset(-16)
        }

        setupPushURLCard()
        setupQRCard()
        setupTokenCard()
        setupStatsCard()
    }

    private func setupPushURLCard() {
        let header = TokenManageViewController.makeCardHeader(L10n.tr("token.manage.push_url"))
        let buttonStack = UIStackView(arrangedSubviews: [copyButton, shareButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 12
        buttonStack.distribution = .fillEqually

        pushURLCard.addSubview(header)
        pushURLCard.addSubview(pushURLLabel)
        pushURLCard.addSubview(buttonStack)

        header.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.left.right.equalToSuperview().inset(16)
        }
        pushURLLabel.snp.makeConstraints { make in
            make.top.equalTo(header.snp.bottom).offset(8)
            make.left.right.equalToSuperview().inset(16)
        }
        buttonStack.snp.makeConstraints { make in
            make.top.equalTo(pushURLLabel.snp.bottom).offset(12)
            make.left.right.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().offset(-16)
            make.height.equalTo(44)
        }

        stackView.addArrangedSubview(pushURLCard)

        copyButton.addTarget(self, action: #selector(copyPushURL), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(sharePushURL), for: .touchUpInside)
    }

    private func setupQRCard() {
        let header = TokenManageViewController.makeCardHeader(L10n.tr("token.manage.qr_code"))

        qrCard.addSubview(header)
        qrCard.addSubview(qrImageView)

        header.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.left.right.equalToSuperview().inset(16)
        }
        qrImageView.snp.makeConstraints { make in
            make.top.equalTo(header.snp.bottom).offset(12)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(200)
            make.bottom.equalToSuperview().offset(-16)
        }

        stackView.addArrangedSubview(qrCard)
    }

    private func setupTokenCard() {
        let header = TokenManageViewController.makeCardHeader(L10n.tr("token.manage.device_token"))

        tokenCard.addSubview(header)
        tokenCard.addSubview(tokenLabel)

        header.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.left.right.equalToSuperview().inset(16)
        }
        tokenLabel.snp.makeConstraints { make in
            make.top.equalTo(header.snp.bottom).offset(8)
            make.left.right.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().offset(-16)
        }

        stackView.addArrangedSubview(tokenCard)
    }

    private func setupStatsCard() {
        let header = TokenManageViewController.makeCardHeader(L10n.tr("token.manage.statistics"))

        statsCard.addSubview(header)
        statsCard.addSubview(statsLabel)

        header.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.left.right.equalToSuperview().inset(16)
        }
        statsLabel.snp.makeConstraints { make in
            make.top.equalTo(header.snp.bottom).offset(8)
            make.left.right.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().offset(-16)
        }

        stackView.addArrangedSubview(statsCard)
    }

    private func updateData() {
        let server = UserDefaults.standard.string(forKey: "com.webbridgekit.bark.server") ?? "https://api.day.app"
        let key = UserDefaults.standard.string(forKey: "com.webbridgekit.bark.key") ?? ""
        let pushURL = key.isEmpty ? server : "\(server)/\(key)"

        pushURLLabel.text = pushURL
        tokenLabel.text = PushNotificationManager.shared.deviceToken ?? L10n.tr("token.manage.not_registered")
        qrImageView.image = generateQRCode(from: pushURL)

        Task {
            let stats = await MessageEngine.shared.getStatistics()
            let total = stats.totalReceived + stats.totalSent
            await MainActor.run {
                self.statsLabel.text = L10n.tr("token.manage.stats_format", "\(total)", "\(stats.totalReceived)", "\(stats.totalSent)", "\(stats.totalFailed)")
            }
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let data = string.data(using: .utf8)
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: 8, y: 8)
        let scaledImage = output.transformed(by: transform)
        return UIImage(ciImage: scaledImage)
    }

    @objc private func copyPushURL() {
        let server = UserDefaults.standard.string(forKey: "com.webbridgekit.bark.server") ?? "https://api.day.app"
        let key = UserDefaults.standard.string(forKey: "com.webbridgekit.bark.key") ?? ""
        let pushURL = key.isEmpty ? server : "\(server)/\(key)"
        UIPasteboard.general.string = pushURL

        let alert = UIAlertController(title: L10n.tr("token.manage.copied_title"), message: L10n.tr("token.manage.copied_message"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
        present(alert, animated: true)
    }

    @objc private func sharePushURL() {
        let server = UserDefaults.standard.string(forKey: "com.webbridgekit.bark.server") ?? "https://api.day.app"
        let key = UserDefaults.standard.string(forKey: "com.webbridgekit.bark.key") ?? ""
        let pushURL = key.isEmpty ? server : "\(server)/\(key)"

        let activityVC = UIActivityViewController(activityItems: [pushURL], applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = shareButton
            popover.sourceRect = shareButton.bounds
        }
        present(activityVC, animated: true)
    }
}
