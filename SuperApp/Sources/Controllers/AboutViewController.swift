//
//  AboutViewController.swift
//  SuperApp
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit
import WebBridgeKit

/// 关于视图控制器
class AboutViewController: UIViewController {

    // MARK: - UI Components

    /// 顶部容器视图
    private let headerContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeColors.current.background
        return view
    }()

    /// App 图标
    private let appIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = 22
        imageView.layer.masksToBounds = true
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = UIColor.separator.cgColor
        return imageView
    }()

    /// App 名称
    private let appNameLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = ThemeTokens.Typography.title3
        label.textColor = ThemeColors.current.text
        return label
    }()

    /// 版本号
    private let versionLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = ThemeTokens.Typography.body
        label.textColor = ThemeColors.current.textSecondary
        return label
    }()

    /// TableView
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.backgroundColor = ThemeColors.current.background
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.separatorStyle = .singleLine
        return tableView
    }()

    /// 底部版权信息
    private let footerLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = ThemeTokens.Typography.caption2
        label.textColor = ThemeTokens.Colors.Light.textTertiary
        label.numberOfLines = 0
        label.text = "WebBridgeKit © 2025"
        return label
    }()

    // MARK: - Data

    /// 表格数据源
    private enum Section: CaseIterable {
        case introduction
        case features
        case license
        case feedback

        var title: String? {
            switch self {
            case .introduction: return L10n.tr("about.section.introduction")
            case .features: return L10n.tr("about.section.features")
            case .license: return L10n.tr("about.section.license")
            case .feedback: return L10n.tr("about.section.feedback")
            }
        }

        var items: [String] {
            switch self {
            case .introduction:
                return [L10n.tr("about.introduction")]
            case .features:
                return [L10n.tr("about.feature.cache"), L10n.tr("about.feature.favorite"), L10n.tr("about.feature.token"), L10n.tr("about.feature.api_key")]
            case .license:
                return ["MIT License"]
            case .feedback:
                return [L10n.tr("about.feedback.github"), L10n.tr("about.feedback.email")]
            }
        }
    }

    /// MIT 协议文本
    private let mitLicenseText = """
    MIT License

    Copyright (c) 2025 WebBridgeKit

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
    """

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.tr("about.title")
        setupUI()
        loadAppInfo()
    }

    // MARK: - Setup UI

    private func setupUI() {
        view.backgroundColor = ThemeColors.current.background

        // 添加子视图
        view.addSubview(headerContainerView)
        headerContainerView.addSubview(appIconImageView)
        headerContainerView.addSubview(appNameLabel)
        headerContainerView.addSubview(versionLabel)
        view.addSubview(tableView)
        view.addSubview(footerLabel)

        // 布局
        headerContainerView.snp.makeConstraints { make in
            make.top.left.right.equalTo(view.safeAreaLayoutGuide)
            make.height.equalTo(180)
        }

        appIconImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(24)
            make.width.height.equalTo(100)
        }

        appNameLabel.snp.makeConstraints { make in
            make.top.equalTo(appIconImageView.snp.bottom).offset(12)
            make.left.right.equalToSuperview().inset(20)
        }

        versionLabel.snp.makeConstraints { make in
            make.top.equalTo(appNameLabel.snp.bottom).offset(4)
            make.left.right.equalToSuperview().inset(20)
        }

        tableView.snp.makeConstraints { make in
            make.top.equalTo(headerContainerView.snp.bottom)
            make.left.right.equalToSuperview()
            make.bottom.equalTo(footerLabel.snp.top).offset(-16)
        }

        footerLabel.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(20)
            make.bottom.lessThanOrEqualTo(view.safeAreaLayoutGuide).offset(-16)
        }
    }

    // MARK: - Load App Info

    private func loadAppInfo() {
        // 加载 App 图标
        if let appIcon = Bundle.main.icon {
            appIconImageView.image = appIcon
        } else {
            // 如果无法获取 App 图标，使用系统图标
            let config = UIImage.SymbolConfiguration(pointSize: 60, weight: .light)
            appIconImageView.image = UIImage(systemName: "app.fill", withConfiguration: config)
                appIconImageView.tintColor = ThemeColors.current.primary
        }

        // 加载 App 名称
        appNameLabel.text = Bundle.main.displayName

        // 加载版本号
        if let version = Bundle.main.version,
           let build = Bundle.main.build {
            versionLabel.text = L10n.tr("about.version_format", version, build)
        } else {
            versionLabel.text = L10n.tr("about.version_default")
        }
    }

    // MARK: - Helper Methods

    private func showLicenseAlert() {
        let alert = UIAlertController(title: "MIT License", message: nil, preferredStyle: .alert)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineSpacing = 4

        let attributedString = NSAttributedString(
            string: mitLicenseText,
            attributes: [
                .font: ThemeTokens.Typography.caption2,
                .paragraphStyle: paragraphStyle,
                .foregroundColor: ThemeColors.current.text
            ]
        )

        alert.setValue(attributedString, forKey: "attributedMessage")

        alert.addAction(UIAlertAction(title: L10n.tr("about.close"), style: .default))

        present(alert, animated: true)
    }

    private func openGitHubIssues() {
        let githubURL = "https://github.com/yourusername/WebBridgeKit/issues"
        if let url = URL(string: githubURL) {
            UIApplication.shared.open(url)
        }
    }

    private func openEmail() {
        let email = "support@webbridgekit.com"
        if let url = URL(string: "mailto:\(email)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - UITableViewDataSource

extension AboutViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Section.allCases[section].items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let section = Section.allCases[indexPath.section]
        let item = section.items[indexPath.row]

        var content = cell.defaultContentConfiguration()
        content.text = item
            content.textProperties.font = ThemeTokens.Typography.callout
            content.textProperties.numberOfLines = 0

            switch section {
        case .introduction:
            content.textProperties.color = ThemeColors.current.textSecondary
            content.textProperties.alignment = .natural
            cell.selectionStyle = .none
            cell.accessoryType = .none
        case .features:
            content.textProperties.color = ThemeColors.current.text
            cell.selectionStyle = .none
            cell.accessoryType = .none
        case .license:
            content.textProperties.color = ThemeColors.current.primary
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
        case .feedback:
            content.textProperties.color = ThemeColors.current.primary
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
        }

        cell.contentConfiguration = content

        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return Section.allCases[section].title
    }
}

// MARK: - UITableViewDelegate

extension AboutViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let section = Section.allCases[indexPath.section]

        switch section {
        case .license:
            showLicenseAlert()
        case .feedback:
            if indexPath.row == 0 {
                openGitHubIssues()
            } else {
                openEmail()
            }
        default:
            break
        }
    }
}

// MARK: - String Extension for Height Calculation

extension String {
    func height(withConstrainedWidth width: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(
            with: constraintRect,
            options: .usesLineFragmentOrigin,
            attributes: [.font: font],
            context: nil
        )
        return ceil(boundingBox.height)
    }
}

// MARK: - Bundle Extension

extension Bundle {
    /// 获取 App 显示名称
    var displayName: String {
        return object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
            object(forInfoDictionaryKey: "CFBundleName") as? String ??
            "SuperApp"
    }

    /// 获取版本号
    var version: String? {
        return object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    /// 获取构建号
    var build: String? {
        return object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }

    /// 获取 App 图标
    var icon: UIImage? {
        if let icons = object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last {
            return UIImage(named: lastIcon)
        }

        // 尝试从 Assets.xcassets 加载 AppIcon
        #if DEBUG
        if let icon = UIImage(named: "AppIcon60x60") {
            return icon
        }
        #endif

        return nil
    }
}
