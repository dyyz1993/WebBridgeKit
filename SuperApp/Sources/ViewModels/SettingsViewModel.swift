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
        case about
        case versionInfo
    }

    struct SettingsItem {
        let icon: String
        let title: String
        let action: SettingsAction
        var value: String? = nil
        var showArrow: Bool = true
    }

    struct SettingsSection {
        let header: String
        let items: [SettingsItem]
    }

    let sections: [SettingsSection] = {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

        return [
            SettingsSection(header: L10n.tr("settings.section.server"), items: [
                SettingsItem(icon: "server.rack", title: L10n.tr("settings.server.config"), action: .serverConfig),
                SettingsItem(icon: "key", title: L10n.tr("settings.key.manage"), action: .apiKeyManage)
            ]),
            SettingsSection(header: L10n.tr("settings.section.notification"), items: [
                SettingsItem(icon: "bell", title: L10n.tr("settings.notification.settings"), action: .notificationSettings),
                SettingsItem(icon: "text.command", title: L10n.tr("settings.token.manage"), action: .tokenManage)
            ]),
            SettingsSection(header: L10n.tr("settings.section.cache"), items: [
                SettingsItem(icon: "archivebox", title: L10n.tr("settings.cache.manage"), action: .management),
                SettingsItem(icon: "trash", title: L10n.tr("settings.cache.clear"), action: .clearCache, showArrow: false)
            ]),
            SettingsSection(header: L10n.tr("settings.section.developer"), items: [
                SettingsItem(icon: "ladybug", title: L10n.tr("settings.debug.panel"), action: .debugPanel),
                SettingsItem(icon: "paintbrush", title: L10n.tr("settings.debug.ui"), action: .uiDebug),
                SettingsItem(icon: "square.grid.2x2", title: "框架展示", action: .showcase)
            ]),
            SettingsSection(header: L10n.tr("settings.section.about"), items: [
                SettingsItem(icon: "info.circle", title: L10n.tr("settings.about"), action: .about),
                SettingsItem(icon: "number", title: L10n.tr("settings.version"), action: .versionInfo, value: "v\(version) (\(build))", showArrow: false)
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
            clearCache: clearCacheRelay.asDriver(onErrorJustReturn: ())
        )
    }
}
