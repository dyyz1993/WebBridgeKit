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
        label.textColor = .label
        label.numberOfLines = 0
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()

    private let copyButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("复制", for: .normal)
        button.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.tintColor = .white
        button.layer.cornerRadius = 10
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        return button
    }()

    private let shareButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("分享", for: .normal)
        button.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        button.backgroundColor = .systemGray
        button.setTitleColor(.white, for: .normal)
        button.tintColor = .white
        button.layer.cornerRadius = 10
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        return button
    }()

    private let qrCard = TokenManageViewController.makeCard()
    private let qrImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.layer.cornerRadius = 8
        return iv
    }()

    private let tokenCard = TokenManageViewController.makeCard()
    private let tokenLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.lineBreakMode = .byCharWrapping
        return label
    }()

    private let statsCard = TokenManageViewController.makeCard()
    private let statsLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    private static func makeCard() -> UIView {
        let view = UIView()
        view.backgroundColor = .secondarySystemGroupedBackground
        view.layer.cornerRadius = 16
        return view
    }

    private static func makeCardHeader(_ text: String) -> UILabel {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .secondaryLabel
        label.text = text
        return label
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "口令管理"
        setupUI()
        updateData()
    }

    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground

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
        let header = TokenManageViewController.makeCardHeader("推送地址")
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
        let header = TokenManageViewController.makeCardHeader("二维码")

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
        let header = TokenManageViewController.makeCardHeader("设备 Token")

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
        let header = TokenManageViewController.makeCardHeader("统计")

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
        tokenLabel.text = PushNotificationManager.shared.deviceToken ?? "未注册"
        qrImageView.image = generateQRCode(from: pushURL)

        Task {
            let stats = await MessageEngine.shared.getStatistics()
            let total = stats.totalReceived + stats.totalSent
            await MainActor.run {
                self.statsLabel.text = "总消息数: \(total)\n已接收: \(stats.totalReceived)\n已发送: \(stats.totalSent)\n失败: \(stats.totalFailed)"
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

        let alert = UIAlertController(title: "已复制", message: "推送地址已复制到剪贴板", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
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
