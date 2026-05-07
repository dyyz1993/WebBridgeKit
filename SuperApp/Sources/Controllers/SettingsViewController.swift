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

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.backgroundColor = ThemeColors.current.background
        table.register(MenuCell.self, forCellReuseIdentifier: MenuCell.identifier)
        table.separatorStyle = .singleLine
        table.separatorInset = UIEdgeInsets(top: 0, left: 52, bottom: 0, right: 0)
        table.tableFooterView = UIView()
        table.delegate = self
        table.dataSource = self
        return table
    }()

    private let itemSelectRelay = PublishRelay<IndexPath>()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.tr("settings.title")
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = ThemeColors.current.background
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        view.accessibilityIdentifier = "SettingsViewController"
        tableView.accessibilityIdentifier = "settings.tableView"
        tableView.accessibilityLabel = "Settings Table View"
    }

    override func bindViewModel() {
        tableView.rx.itemSelected
            .do(onNext: { [weak self] indexPath in
                self?.tableView.deselectRow(at: indexPath, animated: true)
            })
            .bind(to: itemSelectRelay)
            .disposed(by: rx)

        let input = SettingsViewModel.Input(
            itemSelect: itemSelectRelay.asDriver(onErrorJustReturn: IndexPath(row: 0, section: 0))
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

        output.navigateToManagement
            .drive(onNext: { [weak self] in self?.navigateToManagement() })
            .disposed(by: rx)

        output.navigateToAbout
            .drive(onNext: { [weak self] in self?.navigateToAbout() })
            .disposed(by: rx)

        output.navigateToDebugPanel
            .drive(onNext: { [weak self] in self?.navigateToDebugPanel() })
            .disposed(by: rx)

        output.openNotificationSettings
            .drive(onNext: { [weak self] in self?.openNotificationSettings() })
            .disposed(by: rx)

        output.navigateToUIDebug
            .drive(onNext: { [weak self] in self?.navigateToUIDebug() })
            .disposed(by: rx)

        output.clearCache
            .drive(onNext: { [weak self] in self?.showClearCacheConfirm() })
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

    private func navigateToManagement() {
        let vc = ManagementViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    private func navigateToAbout() {
        let vc = AboutViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    private func navigateToDebugPanel() {
        let debugPanel = DebugPanelViewController()
        let nav = UINavigationController(rootViewController: debugPanel)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    private func navigateToUIDebug() {
        let vc = NotificationDebugViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    private func openNotificationSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func showClearCacheConfirm() {
        let alert = UIAlertController(title: L10n.tr("settings.clear_cache.title"), message: L10n.tr("settings.clear_cache.message"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.tr("common.cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: L10n.tr("settings.clear_cache.confirm"), style: .destructive) { _ in
            WebCacheManager.shared.clearAll()
        })
        present(alert, animated: true)
    }
}

extension SettingsViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.sections[section].items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: MenuCell.identifier, for: indexPath) as! MenuCell
        let item = viewModel.sections[indexPath.section].items[indexPath.row]
        cell.configure(icon: item.icon, title: item.title, value: item.value, showArrow: item.showArrow)
        cell.accessibilityIdentifier = "settings.cell.\(item.action.rawValue)"
        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return viewModel.sections[section].header
    }
}

extension SettingsViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        itemSelectRelay.accept(indexPath)
    }
}
