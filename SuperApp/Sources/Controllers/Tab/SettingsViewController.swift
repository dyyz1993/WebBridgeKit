//
//  SettingsViewController.swift
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

class SettingsViewController: BaseViewController<SettingsViewModel> {

    private let scaffold = WBKScreenScaffold(style: .scrollable)

    private let itemSelectRelay = PublishRelay<IndexPath>()
    private let copyTokenTapRelay = PublishRelay<Void>()
    private let rememberToggleRelay = PublishRelay<Bool>()

    private var sectionRows: [[(indexPath: IndexPath, item: SettingsViewModel.SettingsItem)]] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = ThemeTokens.Color.background
        view.addSubview(scaffold)
        scaffold.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let titleLabel = UILabel()
        titleLabel.text = L10n.tr("tab.settings")
        titleLabel.font = ThemeTokens.Typography.screenTitle
        titleLabel.textColor = ThemeTokens.Color.text
        titleLabel.numberOfLines = 1
        titleLabel.accessibilityIdentifier = "settings.title"
        scaffold.addSection(titleLabel, spacing: ThemeTokens.Spacing.lg)

        let sections = viewModel.sections
        for (sectionIndex, section) in sections.enumerated() {
            if let header = section.header {
                let sectionHeader = WBKSectionHeader(
                    title: header.uppercased(),
                    style: .compact
                )
                sectionHeader.accessibilityIdentifier = "settings.section.\(sectionIndex)"
                scaffold.addSection(sectionHeader, spacing: ThemeTokens.Spacing.sm)
            }

            let cardWrapper = UIView()
            cardWrapper.backgroundColor = ThemeTokens.Color.surface
            cardWrapper.layer.cornerRadius = ThemeTokens.CornerRadius.card
            cardWrapper.clipsToBounds = true

            let rowsStack = UIStackView()
            rowsStack.axis = .vertical
            rowsStack.alignment = .fill
            cardWrapper.addSubview(rowsStack)
            rowsStack.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }

            var rowEntries: [(indexPath: IndexPath, item: SettingsViewModel.SettingsItem)] = []

            for (rowIndex, item) in section.items.enumerated() {
                let indexPath = IndexPath(row: rowIndex, section: sectionIndex)

                if item.cellKind == .hero {
                    let heroRow = makeHeroRow(item: item, indexPath: indexPath)
                    rowsStack.addArrangedSubview(heroRow)
                    rowEntries.append((indexPath, item))
                    continue
                }

                let row = makeListRow(item: item, indexPath: indexPath)
                rowsStack.addArrangedSubview(row)

                if rowIndex < section.items.count - 1 {
                    let sep = UIView()
                    sep.backgroundColor = ThemeTokens.Color.separator
                    rowsStack.addArrangedSubview(sep)
                    sep.snp.makeConstraints { make in
                        make.height.equalTo(0.5)
                        make.leading.trailing.equalToSuperview().inset(ThemeTokens.ComponentContract.SettingsRow.horizontalPadding)
                    }
                }

                rowEntries.append((indexPath, item))
            }

            sectionRows.append(rowEntries)
            scaffold.addSection(cardWrapper, spacing: ThemeTokens.Spacing.sm)
        }

        let versionLabel = UILabel()
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        versionLabel.text = "WebBridgeKit v\(version) (Build \(build))"
        versionLabel.font = ThemeTokens.Typography.metadata
        versionLabel.textColor = ThemeTokens.Color.textTertiary
        versionLabel.textAlignment = .center
        versionLabel.numberOfLines = 1
        scaffold.addSection(versionLabel, spacing: ThemeTokens.Spacing.xxl)

        view.accessibilityIdentifier = "SettingsViewController"
    }

    private func makeListRow(
        item: SettingsViewModel.SettingsItem,
        indexPath: IndexPath
    ) -> WBKListRow {
        let isDestructive = item.action == .cacheManager
        let rowStyle: WBKListRow.Style = isDestructive ? .destructive : (item.hasToggle ? .toggle : .default)

        let row = WBKListRow(style: rowStyle)
        row.accessibilityIdentifier = item.action.map { "settings.cell.\($0.rawValue)" } ?? "settings.cell.default"

        if let lucide = item.lucideIcon {
            row.setIcon(lucide)
            row.iconTintColor = item.iconTintColor ?? ThemeTokens.Color.primary
            row.setIconBoxBackgroundColor(item.iconBackgroundColor ?? .clear)
        } else if let iconName = item.icon {
            row.icon = LucideIcon.fallbackImage(sfName: iconName)
            row.iconTintColor = item.iconTintColor ?? ThemeTokens.Color.primary
            row.setIconBoxBackgroundColor(item.iconBackgroundColor ?? .clear)
        }

        row.title = item.title
        row.trailingText = item.value

        if item.hasToggle {
            row.isToggleOn = item.toggleIsOn
            row.onToggleChanged = { [weak self] isOn in
                self?.rememberToggleRelay.accept(isOn)
            }
        } else if item.showArrow {
            row.accessoryType = .chevron
        } else {
            row.accessoryType = .none
        }

        if !item.hasToggle && item.cellKind != .hero {
            row.onTap = { [weak self] in
                self?.itemSelectRelay.accept(indexPath)
            }
        }

        return row
    }

    private func makeHeroRow(
        item: SettingsViewModel.SettingsItem,
        indexPath: IndexPath
    ) -> UIView {
        let container = UIView()
        container.backgroundColor = ThemeTokens.Color.surface
        container.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(ThemeTokens.ComponentContract.SettingsRow.minHeight)
        }

        let iconBox = UIView()
        iconBox.backgroundColor = ThemeTokens.Color.primary.withAlphaComponent(0.1)
        iconBox.layer.cornerRadius = ThemeTokens.ComponentContract.SettingsRow.iconBox / 2
        iconBox.clipsToBounds = true
        container.addSubview(iconBox)

        let iconView = UIImageView()
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = ThemeTokens.Color.primary
        if let lucide = item.lucideIcon {
            iconView.image = lucide.templateImage(pointSize: ThemeTokens.ComponentContract.SettingsRow.iconSize)
        }
        container.addSubview(iconView)

        let titleLabel = UILabel()
        titleLabel.text = item.title
        titleLabel.font = ThemeTokens.Typography.rowTitle
        titleLabel.textColor = ThemeTokens.Color.text
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        container.addSubview(titleLabel)

        let copyButton = UIButton(type: .system)
        copyButton.setImage(
            LucideIcon.copy.templateImage(pointSize: ThemeTokens.Icons.Sizes.sm),
            for: .normal
        )
        copyButton.tintColor = ThemeTokens.Color.primary
        copyButton.accessibilityLabel = L10n.tr("settings.hero.copied_title")
        container.addSubview(copyButton)

        copyButton.rx.tap
            .bind(to: copyTokenTapRelay)
            .disposed(by: rx)

        let hPad = ThemeTokens.ComponentContract.SettingsRow.horizontalPadding
        let iconBoxSize = ThemeTokens.ComponentContract.SettingsRow.iconBox
        let iconSize = ThemeTokens.ComponentContract.SettingsRow.iconSize

        iconBox.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(hPad)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(iconBoxSize)
        }

        iconView.snp.makeConstraints { make in
            make.center.equalTo(iconBox)
            make.width.height.equalTo(iconSize)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconBox.snp.trailing).offset(ThemeTokens.Spacing.md)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(copyButton.snp.leading).offset(-ThemeTokens.Spacing.sm)
        }

        copyButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-hPad)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(44)
        }

        container.accessibilityIdentifier = "settings.cell.hero"
        return container
    }

    override func bindViewModel() {
        let input = SettingsViewModel.Input(
            itemSelect: itemSelectRelay.asDriver(onErrorJustReturn: IndexPath(row: 0, section: 0)),
            copyTokenTap: copyTokenTapRelay.asDriver(onErrorJustReturn: ()),
            rememberToggle: rememberToggleRelay.asDriver(onErrorJustReturn: false)
        )

        let output = viewModel.transform(input: input)

        output.navigateToServerConfig
            .drive(onNext: { [weak self] in self?.navigateToServerConfig() })
            .disposed(by: rx)

        output.navigateToAPIKeyManage
            .drive(onNext: { [weak self] in self?.navigateToAPIKeyManage() })
            .disposed(by: rx)

        output.navigateToTokenManage
            .drive(onNext: { [weak self] in self?.navigateToTokenManage() })
            .disposed(by: rx)

        output.navigateToFavorites
            .drive(onNext: { [weak self] in self?.navigateToFavorites() })
            .disposed(by: rx)

        output.navigateToHistory
            .drive(onNext: { [weak self] in self?.navigateToHistory() })
            .disposed(by: rx)

        output.navigateToManagement
            .drive(onNext: { [weak self] in self?.navigateToManagement() })
            .disposed(by: rx)

        output.navigateToAbout
            .drive(onNext: { [weak self] in self?.navigateToAbout() })
            .disposed(by: rx)

        #if DEBUG
        output.navigateToDebugPanel
            .drive(onNext: { [weak self] in self?.navigateToDebugPanel() })
            .disposed(by: rx)
        #endif

        output.navigateToCacheDashboard
            .drive(onNext: { [weak self] in self?.navigateToCacheDashboard() })
            .disposed(by: rx)

        output.openNotificationSettings
            .drive(onNext: { [weak self] in self?.openNotificationSettings() })
            .disposed(by: rx)

        output.exportDiagnostics
            .drive(onNext: { [weak self] in self?.handleExportDiagnostics() })
            .disposed(by: rx)

        output.copyTokenResult
            .drive(onNext: { [weak self] in
                let alert = UIAlertController(
                    title: L10n.tr("settings.hero.copied_title"),
                    message: L10n.tr("settings.hero.copied_message"),
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
                self?.present(alert, animated: true)
            })
            .disposed(by: rx)
    }

    private func navigateToTokenManage() {
        let vc = TokenManageViewController(viewModel: TokenManageViewModel())
        navigationController?.pushViewController(vc, animated: true)
    }

    private func navigateToServerConfig() {
        let vc = ServerConfigViewController(viewModel: ServerConfigViewModel())
        navigationController?.pushViewController(vc, animated: true)
    }

    private func navigateToAPIKeyManage() {
        let vc = APIKeyManageViewController(viewModel: APIKeyManageViewModel())
        navigationController?.pushViewController(vc, animated: true)
    }

    private func navigateToFavorites() {
        let vc = FavoriteViewController(viewModel: FavoriteViewModel())
        navigationController?.pushViewController(vc, animated: true)
    }

    private func navigateToHistory() {
        let vc = RecentAccessHistoryViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    private func navigateToManagement() {
        let vc = ManagementViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    private func navigateToAbout() {
        let vc = AboutViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    #if DEBUG
    private func navigateToDebugPanel() {
        let debugPanel = DebugPanelViewController()
        let nav = UINavigationController(rootViewController: debugPanel)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }
    #endif

    private func navigateToCacheDashboard() {
        let vc = CacheDashboardViewController(viewModel: CacheDashboardViewModel())
        navigationController?.pushViewController(vc, animated: true)
    }

    private func openNotificationSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func handleExportDiagnostics() {
        #if DEBUG
        let vc = DiagnosticsViewController()
        navigationController?.pushViewController(vc, animated: true)
        #else
        let alert = UIAlertController(
            title: L10n.tr("settings.hero.copied_title"),
            message: L10n.tr("settings.export.diagnostics"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
        present(alert, animated: true)
        #endif
    }
}
