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

/// 设置中心 ViewModel
class SettingsViewModel: ViewModel {

    // MARK: - Input & Output

    struct Input {
        let itemSelect: Driver<IndexPath>
        let lastAppMemoryToggle: Driver<Bool>
    }

    struct Output {
        let navigateToTokenManage: Driver<Void>
        let navigateToServerConfig: Driver<Void>
        let navigateToAPIKeyManage: Driver<Void>
        let navigateToManagement: Driver<Void>
        let navigateToAbout: Driver<Void>
        let storageSize: Driver<String>
        let lastAppMemoryEnabled: Driver<Bool>
    }

    // MARK: - Properties

    private let menuItems: [SettingsMenuItem] = [
        SettingsMenuItem(icon: "text.command", title: "口令管理", action: .tokenManage),
        SettingsMenuItem(icon: "server.rack", title: "服务器配置", action: .serverConfig),
        SettingsMenuItem(icon: "key", title: "密钥管理", action: .apiKeyManage),
        SettingsMenuItem(icon: "archivebox", title: "资源管理", action: .management),
        SettingsMenuItem(icon: "arrow.counterclockwise", title: "记忆上次应用", action: .lastAppMemory),
        SettingsMenuItem(icon: "info.circle", title: "关于", action: .about)
    ]

    private let storageSizeRelay = BehaviorRelay<String>(value: "计算中...")
    private let lastAppMemoryEnabledRelay = BehaviorRelay<Bool>(value: UserDefaults.standard.bool(forKey: "EnableLastAppMemory"))

    private let navigateToTokenManageRelay = PublishRelay<Void>()
    private let navigateToServerConfigRelay = PublishRelay<Void>()
    private let navigateToAPIKeyManageRelay = PublishRelay<Void>()
    private let navigateToManagementRelay = PublishRelay<Void>()
    private let navigateToAboutRelay = PublishRelay<Void>()

    // MARK: - Public Methods

    func menuItem(at indexPath: IndexPath) -> SettingsMenuItem {
        return menuItems[indexPath.row]
    }

    func numberOfItems() -> Int {
        return menuItems.count
    }

    // MARK: - Transform

    func transform(input: Input) -> Output {
        // 处理开关
        input.lastAppMemoryToggle
            .do(onNext: { enabled in
                UserDefaults.standard.set(enabled, forKey: "EnableLastAppMemory")
                UserDefaults.standard.synchronize()
            })
            .drive(lastAppMemoryEnabledRelay)
            .disposed(by: rx)

        // 定时更新存储空间显示
        Observable<Int>.interval(.seconds(5), scheduler: MainScheduler.instance)
            .startWith(0)
            .observe(on: ConcurrentDispatchQueueScheduler(qos: .background)) // 在后台线程计算
            .map { _ in
                let totalSize = ManifestCacheManager.shared.calculateTotalCacheSize()
                return ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
            }
            .observe(on: MainScheduler.instance) // 回到主线程更新 UI
            .bind(to: storageSizeRelay)
            .disposed(by: rx)

        // 处理项目选择
        input.itemSelect
            .do(onNext: { [weak self] indexPath in
                guard let self = self else { return }
                let item = self.menuItem(at: indexPath)

                switch item.action {
                case .tokenManage:
                    self.navigateToTokenManageRelay.accept(())
                case .serverConfig:
                    self.navigateToServerConfigRelay.accept(())
                case .apiKeyManage:
                    self.navigateToAPIKeyManageRelay.accept(())
                case .management:
                    self.navigateToManagementRelay.accept(())
                case .lastAppMemory:
                    // 开关在 Cell 内部处理，这里不处理跳转
                    break
                case .about:
                    self.navigateToAboutRelay.accept(())
                }
            })
            .drive()
            .disposed(by: rx)

        return Output(
            navigateToTokenManage: navigateToTokenManageRelay.asDriver(onErrorJustReturn: ()),
            navigateToServerConfig: navigateToServerConfigRelay.asDriver(onErrorJustReturn: ()),
            navigateToAPIKeyManage: navigateToAPIKeyManageRelay.asDriver(onErrorJustReturn: ()),
            navigateToManagement: navigateToManagementRelay.asDriver(onErrorJustReturn: ()),
            navigateToAbout: navigateToAboutRelay.asDriver(onErrorJustReturn: ()),
            storageSize: storageSizeRelay.asDriver(),
            lastAppMemoryEnabled: lastAppMemoryEnabledRelay.asDriver()
        )
    }
}

// MARK: - Settings Menu Item

enum SettingsMenuAction {
    case tokenManage
    case serverConfig
    case apiKeyManage
    case management
    case lastAppMemory
    case about
}

struct SettingsMenuItem {
    let icon: String
    let title: String
    let action: SettingsMenuAction
}
