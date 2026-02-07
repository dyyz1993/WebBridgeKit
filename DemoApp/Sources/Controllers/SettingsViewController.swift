//
//  SettingsViewController.swift
//  DemoApp
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa
import WebBridgeKit

/// 设置中心视图控制器
class SettingsViewController: BaseViewController<SettingsViewModel> {

    // MARK: - UI Components

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .grouped)
        table.backgroundColor = UIColor.systemGroupedBackground
        table.register(MenuCell.self, forCellReuseIdentifier: MenuCell.identifier)
        table.register(SwitchCell.self, forCellReuseIdentifier: SwitchCell.identifier)
        table.separatorStyle = .singleLine
        table.separatorInset = UIEdgeInsets(top: 0, left: 52, bottom: 0, right: 0)
        table.tableFooterView = UIView()
        return table
    }()

    private let headerView = SettingsHeaderView()

    private let itemSelectRelay = PublishRelay<IndexPath>()
    private let lastAppMemoryToggleRelay = PublishRelay<Bool>()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "设置"
        setupUI()
    }

    // MARK: - Setup UI

    private func setupUI() {
        view.backgroundColor = UIColor.systemGroupedBackground

        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // 设置 header view
        let headerHeight = headerView.sizeThatFits(CGSize(width: view.bounds.width, height: CGFloat.greatestFiniteMagnitude)).height
        headerView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: headerHeight)
        tableView.tableHeaderView = headerView

        // Header view 回调
        headerView.onCopyTapped = { [weak self] in
            self?.showCopySuccess()
        }

        // Accessibility identifiers for testing
        view.accessibilityIdentifier = "SettingsViewController"
        tableView.accessibilityIdentifier = "settings.tableView"
        tableView.accessibilityLabel = "Settings Table View"
    }

    // MARK: - Bind ViewModel

    override func bindViewModel() {
        tableView.rx.itemSelected
            .do(onNext: { [weak self] indexPath in
                self?.tableView.deselectRow(at: indexPath, animated: true)
            })
            .bind(to: itemSelectRelay)
            .disposed(by: rx)

        let input = SettingsViewModel.Input(
            itemSelect: itemSelectRelay.asDriver(onErrorJustReturn: IndexPath(row: 0, section: 0)),
            lastAppMemoryToggle: lastAppMemoryToggleRelay.asDriver(onErrorJustReturn: false)
        )

        let output = viewModel.transform(input: input)

        // 绑定数据
        Observable.just((0..<viewModel.numberOfItems()).map { $0 })
            .bind(to: tableView.rx.items) { (tv: UITableView, index: Int, _) -> UITableViewCell in
                let indexPath = IndexPath(row: index, section: 0)
                let menuItem = self.viewModel.menuItem(at: indexPath)
                
                if menuItem.action == .lastAppMemory {
                    let cell = tv.dequeueReusableCell(withIdentifier: SwitchCell.identifier, for: indexPath) as! SwitchCell
                    cell.configure(
                        title: menuItem.title,
                        description: "自动打开上次访问的应用",
                        isOn: UserDefaults.standard.bool(forKey: "EnableLastAppMemory")
                    )
                    // 监听开关变化并反馈给 ViewModel
                    cell.switchControl.rx.isOn
                        .skip(1) // 跳过初始值的绑定
                        .distinctUntilChanged()
                        .bind(to: self.lastAppMemoryToggleRelay)
                        .disposed(by: cell.prepareForReuseBag)
                    return cell
                } else {
                    let cell = tv.dequeueReusableCell(withIdentifier: MenuCell.identifier, for: indexPath) as! MenuCell
                    
                    var value: String? = nil
                    if menuItem.action == .storageManage {
                        output.storageSize
                            .drive(onNext: { size in
                                cell.configure(icon: menuItem.icon, title: menuItem.title, value: size, showArrow: true)
                            })
                            .disposed(by: cell.prepareForReuseBag)
                    }
                    
                    cell.configure(
                        icon: menuItem.icon,
                        title: menuItem.title,
                        value: value,
                        showArrow: true
                    )

                    // Accessibility identifiers
                    switch menuItem.action {
                    case .tokenManage:
                        cell.accessibilityIdentifier = "settings.cell.tokenManage"
                    case .serverConfig:
                        cell.accessibilityIdentifier = "settings.cell.serverConfig"
                    case .apiKeyManage:
                        cell.accessibilityIdentifier = "settings.cell.apiKeyManage"
                    case .storageManage:
                        cell.accessibilityIdentifier = "settings.cell.storageManage"
                    case .about:
                        cell.accessibilityIdentifier = "settings.cell.about"
                    default:
                        break
                    }
                    return cell
                }
            }
            .disposed(by: rx)

        // 导航处理
        output.navigateToAPIKeyManage
            .drive(onNext: { [weak self] in
                let vc = APIKeyManagementViewController()
                self?.navigationController?.pushViewController(vc, animated: true)
            })
            .disposed(by: rx)

        output.navigateToTokenManage
            .drive(onNext: { [weak self] in
                // TODO: 实现 Token 管理页
                print("Navigating to Token Manage")
            })
            .disposed(by: rx)

        output.navigateToServerConfig
            .drive(onNext: { [weak self] in
                // TODO: 实现服务器配置页
                print("Navigating to Server Config")
            })
            .disposed(by: rx)
    }

    // MARK: - Private Methods

    private func showCopySuccess() {
        // 复制成功的提示已经在 header view 中处理
    }

    // MARK: - Navigation

    private func navigateToTokenManage() {
        let tokenManageVC = TokenManageViewController(viewModel: TokenManageViewModel())
        navigationController?.pushViewController(tokenManageVC, animated: true)
    }

    private func navigateToServerConfig() {
        let serverConfigViewModel = ServerConfigViewModel()
        let serverConfigVC = ServerConfigViewController(viewModel: serverConfigViewModel)
        navigationController?.pushViewController(serverConfigVC, animated: true)
    }

    private func navigateToAPIKeyManage() {
        let apiKeyManageVC = APIKeyManageViewController(viewModel: APIKeyManageViewModel())
        navigationController?.pushViewController(apiKeyManageVC, animated: true)
    }

    private func navigateToAbout() {
        let aboutVC = AboutViewController()
        navigationController?.pushViewController(aboutVC, animated: true)
    }
}
