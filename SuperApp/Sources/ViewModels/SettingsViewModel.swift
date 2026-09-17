//
//  SettingsViewModel.swift
//  SuperApp
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import UIKit
import WebBridgeKit

/// 设置页数据源：提供 SwiftUI `SettingsView` 渲染所需的分组与行定义。
/// 导航分发由 `SettingsView.handleAction` -> `TabBarController.handleSettingsNavigation` 完成。
class SettingsViewModel {

    enum SettingsAction: String {
        case serverConfig
        case tokenManager
        case apiKeyManage
        case webGrants
        case cacheManager
        case favorites
        case history
        case notificationSettings
        case pushEncryption
        case defaultStartupApp
        case appearance
        case debugPanel
        case debugCenter
        case deepLinks
        case cacheDashboard
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

    static var defaultStartupAppName: String {
        guard let appID = UserDefaults.standard.string(forKey: SettingsPreferenceKeys.defaultStartupAppID),
              !appID.isEmpty else {
            return L10n.tr("settings.default.startup.app.unset")
        }
        return HTMLAppRuntimeCenter.shared.trustRegistry.manifest(for: appID)?.name
            ?? L10n.tr("settings.default.startup.app.unset")
    }

    let sections: [SettingsSection] = {
        let defaultStartupAppName = SettingsViewModel.defaultStartupAppName
        let cacheSize = SettingsViewModel.calculateCacheSize()

        let pb = ThemeTokens.Color.primary.withAlphaComponent(0.1)
        let pt = ThemeTokens.Color.primary
        let eb = ThemeTokens.Color.error.withAlphaComponent(0.1)
        let et = ThemeTokens.Color.error
        let pubg = ThemeTokens.Color.gradientEnd.withAlphaComponent(0.1)
        let put = ThemeTokens.Color.gradientEnd
        let sb = ThemeTokens.Color.success.withAlphaComponent(0.1)
        let st = ThemeTokens.Color.success
        let wb = ThemeTokens.Color.warning.withAlphaComponent(0.1)
        let wt = ThemeTokens.Color.warning
        let tb = ThemeTokens.Color.info.withAlphaComponent(0.1)
        let tt = ThemeTokens.Color.info
        let ob = ThemeTokens.Color.primary.withAlphaComponent(0.1)
        let ot = ThemeTokens.Color.primary
        let gb = ThemeTokens.Color.textSecondary.withAlphaComponent(0.1)
        let gt = ThemeTokens.Color.textSecondary

        var sections: [SettingsSection] = []

        // The public Drel address lives on Home. The legacy Bark identity card
        // must not appear in the minimal Store settings surface.
        #if !DREL_RELEASE_MINIMAL_SETTINGS
        sections.append(SettingsSection(header: nil, items: [
            SettingsItem(
                icon: nil,
                lucideIcon: .globe,
                title: L10n.tr("settings.hero.token_masked"),
                action: nil,
                iconBackgroundColor: nil,
                iconTintColor: nil,
                cellKind: .hero
            )
        ], isHeroSection: true))

        // S5: the local API-key manager has no Drel counterpart — its keys are
        // device-local and no Drel server consumes them — so container builds
        // drop the whole row instead of exposing a no-op page.
        var securityItems: [SettingsItem] = []
        #if !DREL_CONTAINER_ONLY
        securityItems.append(
            SettingsItem(
                icon: "key.radiowaves.forward",
                lucideIcon: nil,
                title: L10n.tr("settings.apikey.manager"),
                action: .apiKeyManage,
                iconBackgroundColor: pubg,
                iconTintColor: put
            )
        )
        securityItems.insert(
            SettingsItem(
                icon: nil,
                lucideIcon: .key,
                title: L10n.tr("settings.token.manager"),
                action: .tokenManager,
                iconBackgroundColor: sb,
                iconTintColor: st
            ),
            at: 0
        )
        securityItems.append(
            SettingsItem(
                icon: nil,
                lucideIcon: .globe,
                title: "网页授权管理",
                action: .webGrants,
                iconBackgroundColor: sb,
                iconTintColor: st
            )
        )
        #endif
        if !securityItems.isEmpty {
            sections.append(SettingsSection(header: L10n.tr("settings.section.security"), items: securityItems))
        }
        #endif

        var storageItems: [SettingsItem] = [
                SettingsItem(
                    icon: nil,
                    lucideIcon: .hardDrive,
                    title: L10n.tr("settings.cache.manage"),
                    action: .cacheManager,
                    value: cacheSize,
                    iconBackgroundColor: ob,
                    iconTintColor: ot
                )
        ]
        #if !DREL_RELEASE_MINIMAL_SETTINGS
        storageItems.append(contentsOf: [
                SettingsItem(
                    icon: nil,
                    lucideIcon: .star,
                    title: L10n.tr("settings.favorites"),
                    action: .favorites,
                    iconBackgroundColor: sb,
                    iconTintColor: st
                ),
                SettingsItem(
                    icon: nil,
                    lucideIcon: .clock,
                    title: "最近访问",
                    action: .history,
                    iconBackgroundColor: wb,
                    iconTintColor: wt
                )
        ])
        #endif
        sections.append(SettingsSection(header: L10n.tr("settings.section.storage"), items: storageItems))

        var notificationItems: [SettingsItem] = [
                SettingsItem(
                    icon: nil,
                    lucideIcon: .bell,
                    title: L10n.tr("settings.notification.settings"),
                    action: .notificationSettings,
                    value: "系统权限",
                    iconBackgroundColor: eb,
                    iconTintColor: et
                )
        ]
        // Drel's optional self-hosted APNs relay is not the old HTML-app
        // gateway: it is safe for the Store container and needs to stay
        // visible so open-source deployments can be paired after install.
        notificationItems.append(
            SettingsItem(
                icon: nil,
                lucideIcon: .server,
                title: "推送通道",
                action: .serverConfig,
                value: SelfHostedPushConfiguration.load()?.name ?? "官方 Drel",
                iconBackgroundColor: pb,
                iconTintColor: pt
            )
        )
        #if !DREL_RELEASE_MINIMAL_SETTINGS && !DREL_CONTAINER_ONLY
        notificationItems.append(
                SettingsItem(
                    icon: nil,
                    lucideIcon: .key,
                    title: "推送加密",
                    action: .pushEncryption,
                    iconBackgroundColor: eb,
                    iconTintColor: et
                )
        )
        #endif
        sections.append(SettingsSection(header: L10n.tr("settings.section.notification"), items: notificationItems))

        #if !DREL_RELEASE_MINIMAL_SETTINGS
        sections.append(
            SettingsSection(header: L10n.tr("settings.section.preferences"), items: [
                SettingsItem(
                    icon: nil,
                    lucideIcon: .appFill,
                    title: L10n.tr("settings.default.startup.app"),
                    action: .defaultStartupApp,
                    value: defaultStartupAppName,
                    iconBackgroundColor: pb,
                    iconTintColor: pt
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
            ])
        )
        #else
        sections.append(
            SettingsSection(header: L10n.tr("settings.section.preferences"), items: [
                SettingsItem(
                    icon: "paintpalette.fill",
                    lucideIcon: nil,
                    title: L10n.tr("settings.appearance"),
                    action: .appearance,
                    value: L10n.tr("settings.appearance.system"),
                    iconBackgroundColor: pubg,
                    iconTintColor: put
                )
            ])
        )
        #endif

        #if !DREL_RELEASE_MINIMAL_SETTINGS && !DREL_CONTAINER_ONLY
        sections.append(SettingsSection(header: L10n.tr("settings.section.developer"), items: [
                    SettingsItem(
                        icon: nil,
                        lucideIcon: .bug,
                        title: "调试中心",
                        action: .debugCenter,
                        iconBackgroundColor: gb,
                        iconTintColor: gt,
                        badge: L10n.tr("settings.debug.badge")
                    ),
                    SettingsItem(
                        icon: nil,
                        lucideIcon: .terminal,
                        title: L10n.tr("settings.debug.panel"),
                        action: .debugPanel,
                        iconBackgroundColor: gb,
                        iconTintColor: gt
                    ),
                    SettingsItem(
                        icon: nil,
                        lucideIcon: .link,
                        title: "协议跳转工具",
                        action: .deepLinks,
                        iconBackgroundColor: pb,
                        iconTintColor: pt
                    ),
                    SettingsItem(
                        icon: nil,
                        lucideIcon: .download,
                        title: L10n.tr("settings.export.diagnostics"),
                        action: .exportDiagnostics,
                        iconBackgroundColor: tb,
                        iconTintColor: tt
                    ),
                    SettingsItem(
                        icon: nil,
                        lucideIcon: .chartBar,
                        title: L10n.tr("settings.cache.dashboard"),
                        action: .cacheDashboard,
                        value: nil,
                        showArrow: true,
                        hasToggle: false
                    )
                ]))
        #endif

        sections.append(
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
        )

        return sections
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
}
