//
//  SettingsHeaderView.swift
//  SuperApp
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit
import WebBridgeKit

/// 设置页面头部视图
class SettingsHeaderView: UIView {

    // MARK: - UI Components

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = ThemeColors.current.primary
        return imageView
    }()

    private let appNameLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.title3
        label.textColor = ThemeColors.current.text
        label.textAlignment = .center
        return label
    }()

    private let versionLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.body
        label.textColor = ThemeColors.current.textSecondary
        label.textAlignment = .center
        return label
    }()

    private let deviceIDTitleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTokens.Typography.footnote
        label.textColor = ThemeTokens.Color.textTertiary
        label.text = "设备 ID"
        label.textAlignment = .center
        return label
    }()

    private let deviceIDLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        label.textColor = ThemeColors.current.textSecondary
        label.textAlignment = .center
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        return label
    }()

    private let copyButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let image = UIImage(systemName: "doc.on.doc", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = ThemeColors.current.primary
        return button
    }()

    private let separatorLine: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeTokens.Color.separator
        return view
    }()

    // MARK: - Properties

    var onCopyTapped: (() -> Void)?

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        loadAppInfo()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = ThemeColors.current.background

        addSubview(iconImageView)
        addSubview(appNameLabel)
        addSubview(versionLabel)
        addSubview(deviceIDTitleLabel)
        addSubview(deviceIDLabel)
        addSubview(copyButton)
        addSubview(separatorLine)

        iconImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(24)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(64)
        }

        appNameLabel.snp.makeConstraints { make in
            make.top.equalTo(iconImageView.snp.bottom).offset(12)
            make.left.equalToSuperview().offset(32)
            make.right.equalToSuperview().offset(-32)
        }

        versionLabel.snp.makeConstraints { make in
            make.top.equalTo(appNameLabel.snp.bottom).offset(4)
            make.left.equalToSuperview().offset(32)
            make.right.equalToSuperview().offset(-32)
        }

        deviceIDTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(versionLabel.snp.bottom).offset(20)
            make.left.equalToSuperview().offset(32)
            make.right.equalToSuperview().offset(-32)
        }

        deviceIDLabel.snp.makeConstraints { make in
            make.top.equalTo(deviceIDTitleLabel.snp.bottom).offset(4)
            make.left.equalToSuperview().offset(32)
            make.right.equalTo(copyButton.snp.left).offset(-8)
        }

        copyButton.snp.makeConstraints { make in
            make.centerY.equalTo(deviceIDLabel)
            make.right.equalToSuperview().offset(-32)
            make.width.height.equalTo(28)
        }

        separatorLine.snp.makeConstraints { make in
            make.top.equalTo(deviceIDLabel.snp.bottom).offset(20)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.height.equalTo(0.5)
            make.bottom.equalToSuperview().offset(-1)
        }

        // 按钮事件
        copyButton.addTarget(self, action: #selector(copyButtonTapped), for: .touchUpInside)
    }

    private func loadAppInfo() {
        // App 图标
        if let appIcon = UIImage(named: "AppIcon") {
            iconImageView.image = appIcon
        } else {
            // 使用默认图标
            let config = UIImage.SymbolConfiguration(pointSize: 40, weight: .regular)
            iconImageView.image = UIImage(systemName: "app.dashed", withConfiguration: config)
        }

        // App 名称
        appNameLabel.text = getAppName()

        // 版本号
        versionLabel.text = "版本 \(getAppVersion())"

        // 设备 ID
        if let deviceID = UIDevice.current.identifierForVendor?.uuidString {
            deviceIDLabel.text = deviceID
        }
    }

    // MARK: - Actions

    @objc private func copyButtonTapped() {
        guard let deviceID = deviceIDLabel.text else { return }

        UIPasteboard.general.string = deviceID

        // 显示提示
        showAlert(title: "已复制", message: "设备 ID 已复制到剪贴板")

        onCopyTapped?()
    }

    private func showAlert(title: String, message: String) {
        // 找到当前显示的 ViewController
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }

        var topViewController = rootViewController
        while let presentedViewController = topViewController.presentedViewController {
            topViewController = presentedViewController
        }

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        topViewController.present(alert, animated: true)
    }

    // MARK: - Private Methods

    private func getAppName() -> String {
        if let displayName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String {
            return displayName
        }
        if let name = Bundle.main.infoDictionary?["CFBundleName"] as? String {
            return name
        }
        return "SuperApp"
    }

    private func getAppVersion() -> String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        return "1.0"
    }

    // MARK: - Layout

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let width = size.width
        let height: CGFloat = 24 + 64 + 12 + 20 + 4 + 20 + 13 + 4 + 12 + 20 + 1
        return CGSize(width: width, height: height)
    }
}
