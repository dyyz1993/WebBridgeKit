//
//  SettingsViewModel.swift
//  DemoApp
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
    }

    struct Output {
        let navigateToTokenManage: Driver<Void>
        let navigateToServerConfig: Driver<Void>
        let navigateToAPIKeyManage: Driver<Void>
        let navigateToAbout: Driver<Void>
    }

    // MARK: - Properties

    private let menuItems: [SettingsMenuItem] = [
        SettingsMenuItem(icon: "text.command", title: "口令管理", action: .tokenManage),
        SettingsMenuItem(icon: "server.rack", title: "服务器配置", action: .serverConfig),
        SettingsMenuItem(icon: "key", title: "密钥管理", action: .apiKeyManage),
        SettingsMenuItem(icon: "info.circle", title: "关于", action: .about)
    ]

    private let navigateToTokenManageRelay = PublishRelay<Void>()
    private let navigateToServerConfigRelay = PublishRelay<Void>()
    private let navigateToAPIKeyManageRelay = PublishRelay<Void>()
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
            navigateToAbout: navigateToAboutRelay.asDriver(onErrorJustReturn: ())
        )
    }
}

// MARK: - Settings Menu Item

enum SettingsMenuAction {
    case tokenManage
    case serverConfig
    case apiKeyManage
    case about
}

struct SettingsMenuItem {
    let icon: String
    let title: String
    let action: SettingsMenuAction
}
