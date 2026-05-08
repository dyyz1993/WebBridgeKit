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
    }

    struct Output {
        let navigateToServerConfig: Driver<Void>
        let navigateToAPIKeyManage: Driver<Void>
        let navigateToTokenManage: Driver<Void>
        let navigateToManagement: Driver<Void>
        let navigateToAbout: Driver<Void>
        let navigateToDebugPanel: Driver<Void>
        let navigateToUIDebug: Driver<Void>
        let navigateToShowcase: Driver<Void>
        let openNotificationSettings: Driver<Void>
        let clearCache: Driver<Void>
        let triggerUIAudit: Driver<Void>
    }

    enum SettingsAction: String {
        case serverConfig
        case apiKeyManage
        case notificationSettings
        case tokenManage
        case management
        case clearCache
        case debugPanel
        case uiDebug
        case showcase
        case uiAudit
        case about
        case versionInfo
    }

    struct SettingsItem {
        let icon: String?
        let lucideIcon: LucideIcon?
        let title: String
        let action: SettingsAction
        var value: String?
        var showArrow: Bool = true
        var iconBackgroundColor: UIColor?
        var iconTintColor: UIColor?
    }

    struct SettingsSection {
        let header: String
        let items: [SettingsItem]
    }

    private static func makeColor(_ base: UIColor, alpha: CGFloat = 0.1) -> UIColor { base.withAlphaComponent(alpha) }

    let sections: [SettingsSection] = {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

        let pb = ThemeTokens.Colors.Light.primary.withAlphaComponent(0.1)
        let pt = ThemeTokens.Colors.Light.primary
        let eb = ThemeTokens.Colors.Light.error.withAlphaComponent(0.1)
        let et = ThemeTokens.Colors.Light.error
        let sb = ThemeTokens.Colors.Light.success.withAlphaComponent(0.1)
        let st = ThemeTokens.Colors.Light.success
        let wb = ThemeTokens.Colors.Light.warning.withAlphaComponent(0.1)
        let wt = ThemeTokens.Colors.Light.warning
        let pubg = UIColor(red: 0.686, green: 0.322, blue: 0.878, alpha: 0.1)
        let put = UIColor(red: 0.686, green: 0.322, blue: 0.878, alpha: 1)
        let skb = UIColor(red: 0.353, green: 0.784, blue: 1, alpha: 0.1)
        let skt = UIColor(red: 0.353, green: 0.784, blue: 1, alpha: 1)
        let seb = ThemeTokens.Colors.Light.secondary.withAlphaComponent(0.1)
        let set_ = ThemeTokens.Colors.Light.secondary

        return [
            SettingsSection(header: L10n.tr("settings.section.server"), items: [
                SettingsItem(
                    icon: nil,
                    lucideIcon: .server,
                    title: L10n.tr("settings.server.config"),
                    action: .serverConfig,
                    iconBackgroundColor: pb,
                    iconTintColor: pt
                ),
                SettingsItem(
                    icon: nil,
                    lucideIcon: .key,
                    title: L10n.tr("settings.key.manage"),
                    action: .apiKeyManage,
                    iconBackgroundColor: pb,
                    iconTintColor: pt
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
                ),
                SettingsItem(
                    icon: nil,
                    lucideIcon: .terminal,
                    title: L10n.tr("settings.token.manage"),
                    action: .tokenManage,
                    iconBackgroundColor: pubg,
                    iconTintColor: put
                )
            ]),
            SettingsSection(header: L10n.tr("settings.section.cache"), items: [
                SettingsItem(
                    icon: nil,
                    lucideIcon: .hardDrive,
                    title: L10n.tr("settings.cache.manage"),
                    action: .management,
                    iconBackgroundColor: sb,
                    iconTintColor: st
                ),
                SettingsItem(
                    icon: nil,
                    lucideIcon: .trash,
                    title: L10n.tr("settings.cache.clear"),
                    action: .clearCache,
                    showArrow: false,
                    iconBackgroundColor: eb,
                    iconTintColor: et
                )
            ]),
            SettingsSection(header: L10n.tr("settings.section.developer"), items: [
                SettingsItem(
                    icon: nil,
                    lucideIcon: .bug,
                    title: L10n.tr("settings.debug.panel"),
                    action: .debugPanel,
                    iconBackgroundColor: wb,
                    iconTintColor: wt
                ),
                SettingsItem(
                    icon: nil,
                    lucideIcon: .edit,
                    title: L10n.tr("settings.debug.ui"),
                    action: .uiDebug,
                    iconBackgroundColor: sb,
                    iconTintColor: st
                ),
                SettingsItem(
                    icon: "square.grid.2x2",
                    lucideIcon: nil,
                    title: "框架展示",
                    action: .showcase,
                    iconBackgroundColor: skb,
                    iconTintColor: skt
                ),
                SettingsItem(
                    icon: nil,
                    lucideIcon: .search,
                    title: "UI 审查",
                    action: .uiAudit,
                    showArrow: false,
                    iconBackgroundColor: seb,
                    iconTintColor: set_
                )
            ]),
            SettingsSection(header: L10n.tr("settings.section.about"), items: [
                SettingsItem(
                    icon: nil,
                    lucideIcon: .info,
                    title: L10n.tr("settings.about"),
                    action: .about,
                    iconBackgroundColor: pb,
                    iconTintColor: pt
                ),
                SettingsItem(
                    icon: "number",
                    lucideIcon: nil,
                    title: L10n.tr("settings.version"),
                    action: .versionInfo,
                    value: "v\(version) (\(build))",
                    showArrow: false,
                    iconBackgroundColor: seb,
                    iconTintColor: set_
                )
            ])
        ]
    }()

    private let navigateToServerConfigRelay = PublishRelay<Void>()
    private let navigateToAPIKeyManageRelay = PublishRelay<Void>()
    private let navigateToTokenManageRelay = PublishRelay<Void>()
    private let navigateToManagementRelay = PublishRelay<Void>()
    private let navigateToAboutRelay = PublishRelay<Void>()
    private let navigateToDebugPanelRelay = PublishRelay<Void>()
    private let navigateToUIDebugRelay = PublishRelay<Void>()
    private let navigateToShowcaseRelay = PublishRelay<Void>()
    private let openNotificationSettingsRelay = PublishRelay<Void>()
    private let clearCacheRelay = PublishRelay<Void>()
    private let triggerUIAuditRelay = PublishRelay<Void>()

    func transform(input: Input) -> Output {
        input.itemSelect
            .do(onNext: { [weak self] indexPath in
                guard let self = self else { return }
                let item = self.sections[indexPath.section].items[indexPath.row]
                switch item.action {
                case .serverConfig: self.navigateToServerConfigRelay.accept(())
                case .apiKeyManage: self.navigateToAPIKeyManageRelay.accept(())
                case .notificationSettings: self.openNotificationSettingsRelay.accept(())
                case .tokenManage: self.navigateToTokenManageRelay.accept(())
                case .management: self.navigateToManagementRelay.accept(())
                case .clearCache: self.clearCacheRelay.accept(())
                case .debugPanel: self.navigateToDebugPanelRelay.accept(())
                case .uiDebug: self.navigateToUIDebugRelay.accept(())
                case .showcase: self.navigateToShowcaseRelay.accept(())
                case .uiAudit: self.triggerUIAuditRelay.accept(())
                case .about: self.navigateToAboutRelay.accept(())
                case .versionInfo: break
                }
            })
            .drive()
            .disposed(by: rx)

        return Output(
            navigateToServerConfig: navigateToServerConfigRelay.asDriver(onErrorJustReturn: ()),
            navigateToAPIKeyManage: navigateToAPIKeyManageRelay.asDriver(onErrorJustReturn: ()),
            navigateToTokenManage: navigateToTokenManageRelay.asDriver(onErrorJustReturn: ()),
            navigateToManagement: navigateToManagementRelay.asDriver(onErrorJustReturn: ()),
            navigateToAbout: navigateToAboutRelay.asDriver(onErrorJustReturn: ()),
            navigateToDebugPanel: navigateToDebugPanelRelay.asDriver(onErrorJustReturn: ()),
            navigateToUIDebug: navigateToUIDebugRelay.asDriver(onErrorJustReturn: ()),
            navigateToShowcase: navigateToShowcaseRelay.asDriver(onErrorJustReturn: ()),
            openNotificationSettings: openNotificationSettingsRelay.asDriver(onErrorJustReturn: ()),
            clearCache: clearCacheRelay.asDriver(onErrorJustReturn: ()),
            triggerUIAudit: triggerUIAuditRelay.asDriver(onErrorJustReturn: ())
        )
    }
}
