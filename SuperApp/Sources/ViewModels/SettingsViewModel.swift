//
//  SettingsViewModel.swift
//  SuperApp
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import RxCocoa
import RxSwift
import UIKit
import WebBridgeKit

class SettingsViewModel: ViewModel {

    struct Input {
        let itemSelect: Driver<IndexPath>
        let copyTokenTap: Driver<Void>
        let rememberToggle: Driver<Bool>
    }

    struct Output {
        let navigateToServerConfig: Driver<Void>
        let navigateToAPIKeyManage: Driver<Void>
        let navigateToTokenManage: Driver<Void>
        let navigateToFavorites: Driver<Void>
        let navigateToManagement: Driver<Void>
        let navigateToAbout: Driver<Void>
        let navigateToDebugPanel: Driver<Void>
        let navigateToAppearance: Driver<Void>
        let openNotificationSettings: Driver<Void>
        let clearCache: Driver<Void>
        let exportDiagnostics: Driver<Void>
        let copyTokenResult: Driver<Void>
    }

    enum SettingsAction: String {
        case serverConfig
        case tokenManager
        case apiKeyManage
        case cacheManager
        case favorites
        case notificationSettings
        case rememberLastApp
        case appearance
        case debugPanel
        case exportDiagnostics
        case about
    }

    enum CellKind {
        case hero
        case menuItem
    }

    struct SettingsItem {
        let icon: String?
        let lucideIcon: LucideIcon?
        let title: String
        let action: SettingsAction?
        var value: String?
        var showArrow: Bool = true
        var iconBackgroundColor: UIColor?
        var iconTintColor: UIColor?
        var hasToggle: Bool = false
        var toggleIsOn: Bool = false
        var badge: String?
        var cellKind: CellKind = .menuItem
    }

    struct SettingsSection {
        let header: String?
        let items: [SettingsItem]
        var isHeroSection: Bool = false
    }

    private static func makeColor(_ base: UIColor, alpha: CGFloat = 0.1) -> UIColor { base.withAlphaComponent(alpha) }

    static var rememberLastAppEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "settings.rememberLastApp") }
        set { UserDefaults.standard.set(newValue, forKey: "settings.rememberLastApp") }
    }

    let sections: [SettingsSection] = {
        let rememberOn = SettingsViewModel.rememberLastAppEnabled
        let cacheSize = SettingsViewModel.calculateCacheSize()

        let pb = ThemeTokens.Color.primary.withAlphaComponent(0.1)
        let pt = ThemeTokens.Color.primary
        let eb = ThemeTokens.Color.error.withAlphaComponent(0.1)
        let et = ThemeTokens.Color.error
        let sb = ThemeTokens.Color.success.withAlphaComponent(0.1)
        let st = ThemeTokens.Color.success
        let wb = ThemeTokens.Color.warning.withAlphaComponent(0.1)
        let wt = ThemeTokens.Color.warning
        let pubg = ThemeTokens.Color.info.withAlphaComponent(0.1)
        let put = ThemeTokens.Color.info
        let ob = ThemeTokens.Color.gradientStart.withAlphaComponent(0.1)
        let ot = ThemeTokens.Color.gradientStart
        let tb = ThemeTokens.Color.gradientEnd.withAlphaComponent(0.1)
        let tt = ThemeTokens.Color.gradientEnd
        let gb = ThemeTokens.Color.textSecondary.withAlphaComponent(0.1)
        let gt = ThemeTokens.Color.textSecondary

        let heroItem = SettingsItem(
            icon: nil,
            lucideIcon: .globe,
            title: L10n.tr("settings.hero.token_masked"),
            action: nil,
            iconBackgroundColor: nil,
            iconTintColor: nil,
            cellKind: .hero
        )

        return [
            SettingsSection(header: nil, items: [heroItem], isHeroSection: true),
            SettingsSection(header: L10n.tr("settings.section.server"), items: [
                SettingsItem(
                    icon: nil,
                    lucideIcon: .server,
                    title: L10n.tr("settings.server.config"),
                    action: .serverConfig,
                    value: "api.day.app",
                    iconBackgroundColor: pb,
                    iconTintColor: pt
                )
            ]),
            SettingsSection(header: L10n.tr("settings.section.security"), items: [
                SettingsItem(
                    icon: nil,
                    lucideIcon: .key,
                    title: L10n.tr("settings.token.manager"),
                    action: .tokenManager,
                    iconBackgroundColor: sb,
                    iconTintColor: st
                ),
                SettingsItem(
                    icon: "key.radiowaves.forward",
                    lucideIcon: nil,
                    title: L10n.tr("settings.apikey.manager"),
                    action: .apiKeyManage,
                    iconBackgroundColor: pubg,
                    iconTintColor: put
                )
            ]),
            SettingsSection(header: L10n.tr("settings.section.storage"), items: [
                SettingsItem(
                    icon: nil,
                    lucideIcon: .hardDrive,
                    title: L10n.tr("settings.cache.manage"),
                    action: .cacheManager,
                    value: cacheSize,
                    iconBackgroundColor: ob,
                    iconTintColor: ot
                ),
                SettingsItem(
                    icon: nil,
                    lucideIcon: .star,
                    title: L10n.tr("settings.favorites"),
                    action: .favorites,
                    iconBackgroundColor: tb,
                    iconTintColor: tt
                )
            ]),
            SettingsSection(header: L10n.tr("settings.section.notification"), items: [
                SettingsItem(
                    icon: nil,
                    lucideIcon: .bell,
                    title: L10n.tr("settings.notification.settings"),
                    action: .notificationSettings,
                    iconBackgroundColor: eb,
                    iconTintColor: et
                )
            ]),
            SettingsSection(header: L10n.tr("settings.section.preferences"), items: [
                SettingsItem(
                    icon: nil,
                    lucideIcon: .clock,
                    title: L10n.tr("settings.remember.last.app"),
                    action: .rememberLastApp,
                    showArrow: false,
                    iconBackgroundColor: pb,
                    iconTintColor: pt,
                    hasToggle: true,
                    toggleIsOn: rememberOn
                ),
                SettingsItem(
                    icon: "paintpalette.fill",
                    lucideIcon: nil,
                    title: L10n.tr("settings.appearance"),
                    action: .appearance,
                    value: L10n.tr("settings.appearance.system"),
                    iconBackgroundColor: pubg,
                    iconTintColor: put
                )
            ]),
            SettingsSection(header: L10n.tr("settings.section.developer"), items: [
                SettingsItem(
                    icon: nil,
                    lucideIcon: .bug,
                    title: L10n.tr("settings.debug.panel"),
                    action: .debugPanel,
                    iconBackgroundColor: gb,
                    iconTintColor: gt,
                    badge: L10n.tr("settings.debug.badge")
                ),
                SettingsItem(
                    icon: nil,
                    lucideIcon: .download,
                    title: L10n.tr("settings.export.diagnostics"),
                    action: .exportDiagnostics,
                    iconBackgroundColor: tb,
                    iconTintColor: tt
                )
            ]),
            SettingsSection(header: L10n.tr("settings.section.about"), items: [
                SettingsItem(
                    icon: nil,
                    lucideIcon: .info,
                    title: L10n.tr("settings.about"),
                    action: .about,
                    iconBackgroundColor: gb,
                    iconTintColor: gt
                )
            ])
        ]
    }()

    private static func calculateCacheSize() -> String {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        guard let dir = cacheDir else { return "0 B" }
        var totalSize: UInt64 = 0
        if let enumerator = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += UInt64(size)
                }
            }
        }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(totalSize))
    }

    private let navigateToServerConfigRelay = PublishRelay<Void>()
    private let navigateToAPIKeyManageRelay = PublishRelay<Void>()
    private let navigateToTokenManageRelay = PublishRelay<Void>()
    private let navigateToFavoritesRelay = PublishRelay<Void>()
    private let navigateToManagementRelay = PublishRelay<Void>()
    private let navigateToAboutRelay = PublishRelay<Void>()
    private let navigateToDebugPanelRelay = PublishRelay<Void>()
    private let navigateToAppearanceRelay = PublishRelay<Void>()
    private let openNotificationSettingsRelay = PublishRelay<Void>()
    private let clearCacheRelay = PublishRelay<Void>()
    private let exportDiagnosticsRelay = PublishRelay<Void>()
    private let copyTokenResultRelay = PublishRelay<Void>()

    func transform(input: Input) -> Output {
        input.itemSelect
            .do(onNext: { [weak self] indexPath in
                guard let self = self else { return }
                let item = self.sections[indexPath.section].items[indexPath.row]
                guard let action = item.action else { return }
                switch action {
                case .serverConfig: self.navigateToServerConfigRelay.accept(())
                case .tokenManager: self.navigateToTokenManageRelay.accept(())
                case .apiKeyManage: self.navigateToAPIKeyManageRelay.accept(())
                case .cacheManager: self.navigateToManagementRelay.accept(())
                case .favorites: self.navigateToFavoritesRelay.accept(())
                case .notificationSettings: self.openNotificationSettingsRelay.accept(())
                case .rememberLastApp: break
                case .appearance: self.navigateToAppearanceRelay.accept(())
                case .debugPanel: self.navigateToDebugPanelRelay.accept(())
                case .exportDiagnostics: self.exportDiagnosticsRelay.accept(())
                case .about: self.navigateToAboutRelay.accept(())
                }
            })
            .drive()
            .disposed(by: rx)

        input.rememberToggle
            .do(onNext: { isOn in
                SettingsViewModel.rememberLastAppEnabled = isOn
            })
            .drive()
            .disposed(by: rx)

        input.copyTokenTap
            .do(onNext: { [weak self] in
                UIPasteboard.general.string = "abcd1234efgh5678"
                self?.copyTokenResultRelay.accept(())
            })
            .drive()
            .disposed(by: rx)

        return Output(
            navigateToServerConfig: navigateToServerConfigRelay.asDriver(onErrorJustReturn: ()),
            navigateToAPIKeyManage: navigateToAPIKeyManageRelay.asDriver(onErrorJustReturn: ()),
            navigateToTokenManage: navigateToTokenManageRelay.asDriver(onErrorJustReturn: ()),
            navigateToFavorites: navigateToFavoritesRelay.asDriver(onErrorJustReturn: ()),
            navigateToManagement: navigateToManagementRelay.asDriver(onErrorJustReturn: ()),
            navigateToAbout: navigateToAboutRelay.asDriver(onErrorJustReturn: ()),
            navigateToDebugPanel: navigateToDebugPanelRelay.asDriver(onErrorJustReturn: ()),
            navigateToAppearance: navigateToAppearanceRelay.asDriver(onErrorJustReturn: ()),
            openNotificationSettings: openNotificationSettingsRelay.asDriver(onErrorJustReturn: ()),
            clearCache: clearCacheRelay.asDriver(onErrorJustReturn: ()),
            exportDiagnostics: exportDiagnosticsRelay.asDriver(onErrorJustReturn: ()),
            copyTokenResult: copyTokenResultRelay.asDriver(onErrorJustReturn: ())
        )
    }
}
