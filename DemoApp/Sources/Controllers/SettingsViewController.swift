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
        table.separatorStyle = .singleLine
        table.separatorInset = UIEdgeInsets(top: 0, left: 52, bottom: 0, right: 0)
        table.tableFooterView = UIView()
        return table
    }()

    private let headerView = SettingsHeaderView()

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
        let itemSelect = tableView.rx.itemSelected
            .asDriver()
            .do(onNext: { [weak self] indexPath in
                self?.tableView.deselectRow(at: indexPath, animated: true)
            })

        let input = SettingsViewModel.Input(
            itemSelect: itemSelect
        )

        let output = viewModel.transform(input: input)

        // 绑定数据
        Observable.just((0..<viewModel.numberOfItems()).map { $0 })
            .bind(to: tableView.rx.items(cellIdentifier: MenuCell.identifier, cellType: MenuCell.self)) { [weak self] _, index, cell in
                guard let self = self else { return }
                let indexPath = IndexPath(row: index, section: 0)
                let menuItem = self.viewModel.menuItem(at: indexPath)
                cell.configure(
                    icon: menuItem.icon,
                    title: menuItem.title,
                    value: nil,
                    showArrow: true
                )

                // Set accessibility identifier for each menu item cell
                switch menuItem.action {
                case .tokenManage:
                    cell.accessibilityIdentifier = "settings.cell.tokenManage"
                    cell.accessibilityLabel = "口令管理"
                case .serverConfig:
                    cell.accessibilityIdentifier = "settings.cell.serverConfig"
                    cell.accessibilityLabel = "服务器配置"
                case .apiKeyManage:
                    cell.accessibilityIdentifier = "settings.cell.apiKeyManage"
                    cell.accessibilityLabel = "密钥管理"
                case .about:
                    cell.accessibilityIdentifier = "settings.cell.about"
                    cell.accessibilityLabel = "关于"
                }
            }
            .disposed(by: rx)

        // 导航到口令管理
        output.navigateToTokenManage
            .drive(onNext: { [weak self] in
                self?.navigateToTokenManage()
            })
            .disposed(by: rx)

        // 导航到服务器配置
        output.navigateToServerConfig
            .drive(onNext: { [weak self] in
                self?.navigateToServerConfig()
            })
            .disposed(by: rx)

        // 导航到密钥管理
        output.navigateToAPIKeyManage
            .drive(onNext: { [weak self] in
                self?.navigateToAPIKeyManage()
            })
            .disposed(by: rx)

        // 导航到关于
        output.navigateToAbout
            .drive(onNext: { [weak self] in
                self?.navigateToAbout()
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
