//
//  CacheDashboardViewController.swift
//  SuperApp
//
//  Created on 2026-05-11.
//  Copyright © 2026年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa
import RxDataSources
import WebBridgeKit

class CacheDashboardViewController: BaseViewController<CacheDashboardViewModel> {

    // MARK: - UI Components

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .grouped)
        table.backgroundColor = ThemeTokens.Color.background
        table.separatorStyle = .singleLine
        table.separatorColor = ThemeTokens.Color.separator
        table.delegate = self
        table.register(SubsystemStatCell.self, forCellReuseIdentifier: SubsystemStatCell.reuseIdentifier)
        table.contentInsetAdjustmentBehavior = .always
        table.accessibilityIdentifier = "cacheDashboard.tableView"
        table.accessibilityLabel = "Cache Dashboard Table View"
        return table
    }()

    private let summaryCard = SummaryCardView()

    private lazy var refreshControl: UIRefreshControl = {
        let rc = UIRefreshControl()
        rc.tintColor = ThemeTokens.Color.primary
        return rc
    }()

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.color = ThemeTokens.Color.primary
        ai.hidesWhenStopped = true
        return ai
    }()

    private lazy var errorLabel: UILabel = {
        let l = UILabel()
        l.font = ThemeTokens.Typography.caption1
        l.textColor = ThemeTokens.Color.error
        l.textAlignment = .center
        l.numberOfLines = 0
        l.isHidden = true
        return l
    }()

    // MARK: - Relays

    private let refreshRelay = PublishRelay<Void>()
    private let selectSubsystemRelay = PublishRelay<SubsystemStats>()
    private let tapClearAllRelay = PublishRelay<Void>()
    private let tapPinnedManageRelay = PublishRelay<Void>()
    private let tapPresetCatalogRelay = PublishRelay<Void>()

    // MARK: - Data Source

    private var sections: [SectionModel<String, CacheDashboardViewModel.SubsystemStatItemModel>] = []

    // MARK: - Lifecycle

    override func makeUI() {
        title = "缓存仪表盘"
        view.backgroundColor = ThemeTokens.Color.background

        setupTableView()
        setupNavigationBar()
    }

    private func setupTableView() {
        // Summary card as table header
        let headerFrame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 180)
        summaryCard.frame = headerFrame
        tableView.tableHeaderView = summaryCard

        // Pull-to-refresh
        tableView.refreshControl = refreshControl

        // Add views
        view.addSubview(tableView)
        view.addSubview(errorLabel)

        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        errorLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(32)
        }
    }

    private func setupNavigationBar() {
        navigationItem.largeTitleDisplayMode = .never

        let refreshButton = UIBarButtonItem(
            image: LucideIcon.refresh.image()?.withRenderingMode(.alwaysTemplate),
            style: .plain,
            target: nil,
            action: nil
        )
        refreshButton.tintColor = ThemeTokens.Color.primary
        refreshButton.accessibilityLabel = "刷新缓存数据"
        navigationItem.rightBarButtonItem = refreshButton

        refreshButton.rx.tap
            .bind(to: refreshRelay)
            .disposed(by: rx)
    }

    // MARK: - Bind ViewModel

    override func bindViewModel() {
        // Pull-to-refresh
        refreshControl.rx.controlEvent(.valueChanged)
            .bind(to: refreshRelay)
            .disposed(by: rx)

        let input = CacheDashboardViewModel.Input(
            refresh: refreshRelay.asObservable(),
            selectSubsystem: selectSubsystemRelay.asObservable(),
            tapClearAll: tapClearAllRelay.asObservable(),
            tapPinnedManage: tapPinnedManageRelay.asObservable(),
            tapPresetCatalog: tapPresetCatalogRelay.asObservable()
        )

        let output = viewModel.transform(input: input)

        // Loading state
        output.isLoading
            .drive(onNext: { [weak self] isLoading in
                if !isLoading {
                    self?.refreshControl.endRefreshing()
                }
            })
            .disposed(by: rx)

        // Dashboard data → summary card
        output.dashboardData
            .drive(onNext: { [weak self] data in
                self?.summaryCard.configure(with: data)
            })
            .disposed(by: rx)

        // Sections → table view
        output.subsystemSections
            .drive(onNext: { [weak self] newSections in
                self?.sections = newSections
                self?.tableView.reloadData()
            })
            .disposed(by: rx)

        // Summary text
        output.summaryText
            .drive(onNext: { [weak self] text in
                guard let self, !text.isEmpty else { return }
                // Update summary card's summary label
            })
            .disposed(by: rx)

        // Error
        output.error
            .drive(onNext: { [weak self] errorMsg in
                guard let self else { return }
                if let msg = errorMsg, !msg.isEmpty {
                    self.errorLabel.text = msg
                    self.errorLabel.isHidden = false
                } else {
                    self.errorLabel.isHidden = true
                }
            })
            .disposed(by: rx)

        // Navigate to subsystem detail
        output.navigateToDetail
            .drive(onNext: { [weak self] subsystemID in
                self?.navigateToSubsystemDetail(subsystemID)
            })
            .disposed(by: rx)
    }

    // MARK: - Navigation

    private func navigateToSubsystemDetail(_ subsystemID: SubsystemID) {
        let detailVC = CacheSubsystemDetailViewController(subsystemID: subsystemID)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension CacheDashboardViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: SubsystemStatCell.reuseIdentifier,
            for: indexPath
        ) as? SubsystemStatCell else {
            return UITableViewCell()
        }

        let item = sections[indexPath.section].items[indexPath.row]
        cell.configure(with: item)
        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].model
    }
}

// MARK: - UITableViewDelegate

extension CacheDashboardViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let item = sections[indexPath.section].items[indexPath.row]

        // Reconstruct SubsystemStats from the item model for the relay
        let stats = SubsystemStats(
            id: item.id,
            totalEntries: Int(item.entries) ?? 0,
            totalSize: 0,
            status: item.hasData ? .active : .empty
        )
        selectSubsystemRelay.accept(stats)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        64
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        header.backgroundColor = ThemeTokens.Color.background

        let label = UILabel()
        label.font = ThemeTokens.Typography.caption1
        label.textColor = ThemeTokens.Color.textSecondary
        label.text = sections[section].model

        header.addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
        }

        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        36
    }
}
