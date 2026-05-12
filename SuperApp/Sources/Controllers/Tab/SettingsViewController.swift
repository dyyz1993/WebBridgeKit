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
        table.delegate = self
        table.dataSource = self
        return table
    }()

    private let itemSelectRelay = PublishRelay<IndexPath>()
    private let copyTokenTapRelay = PublishRelay<Void>()
    private let rememberToggleRelay = PublishRelay<Bool>()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupVersionFooter()
    }

    private func setupUI() {
        view.backgroundColor = ThemeColors.current.background
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        tableView.contentInsetAdjustmentBehavior = .always
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 50, right: 0)
        view.accessibilityIdentifier = "SettingsViewController"
        tableView.accessibilityIdentifier = "settings.tableView"
        tableView.accessibilityLabel = "Settings Table View"
    }

    private func setupVersionFooter() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let footerLabel = UILabel()
        footerLabel.text = "WebBridgeKit v\(version) (Build \(build))"
        footerLabel.font = .systemFont(ofSize: 12, weight: .regular)
        footerLabel.textColor = ThemeTokens.Color.textTertiary
        footerLabel.textAlignment = .center
        footerLabel.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 44)
        tableView.tableFooterView = footerLabel
    }

    override func bindViewModel() {
        tableView.rx.itemSelected
            .do(onNext: { [weak self] indexPath in
                self?.tableView.deselectRow(at: indexPath, animated: true)
            })
            .bind(to: itemSelectRelay)
            .disposed(by: rx)

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

        output.navigateToManagement
            .drive(onNext: { [weak self] in self?.navigateToManagement() })
            .disposed(by: rx)

        output.navigateToAbout
            .drive(onNext: { [weak self] in self?.navigateToAbout() })
            .disposed(by: rx)

        output.navigateToDebugPanel
            .drive(onNext: { [weak self] in self?.navigateToDebugPanel() })
            .disposed(by: rx)

        output.navigateToCacheDashboard
            .drive(onNext: { [weak self] in
                self?.navigateToCacheDashboard()
            })
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
        let alert = UIAlertController(
            title: L10n.tr("settings.hero.copied_title"),
            message: L10n.tr("settings.export.diagnostics"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.tr("common.ok"), style: .default))
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

        cell.configure(
            icon: item.icon,
            title: item.title,
            value: item.value,
            showArrow: item.showArrow,
            iconBackgroundColor: item.iconBackgroundColor,
            iconTintColor: item.iconTintColor,
            lucideIcon: item.lucideIcon,
            hasToggle: item.hasToggle,
            toggleIsOn: item.toggleIsOn,
            badge: item.badge,
            isHero: item.cellKind == .hero
        )

        if item.cellKind == .hero {
            cell.copyTokenButton.rx.tap
                .bind(to: copyTokenTapRelay)
                .disposed(by: cell.prepareForReuseBag)
        }

        if item.hasToggle {
            cell.toggleSwitch.rx.isOn
                .skip(1)
                .bind(to: rememberToggleRelay)
                .disposed(by: cell.prepareForReuseBag)
        }

        cell.accessibilityIdentifier = item.action.map { "settings.cell.\($0.rawValue)" } ?? "settings.cell.hero"
        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return viewModel.sections[section].header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if viewModel.sections[section].header == nil {
            return 0.01
        }
        return UITableView.automaticDimension
    }
}

extension SettingsViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.textLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        header.textLabel?.textColor = ThemeColors.current.textSecondary
        header.textLabel?.text = header.textLabel?.text?.uppercased()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = viewModel.sections[indexPath.section].items[indexPath.row]
        if item.hasToggle { return }
        if item.cellKind == .hero { return }
        itemSelectRelay.accept(indexPath)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let item = viewModel.sections[indexPath.section].items[indexPath.row]
        return item.cellKind == .hero ? 96 : 44
    }
}
