//
//  CacheDashboardViewController.swift
//  SuperApp
//
//  Created on 2026-05-11.
//  Copyright © 2026年 WebBridgeKit. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import RxDataSources
import SnapKit
import WebBridgeKit

class CacheDashboardViewController: BaseViewController<CacheDashboardViewModel> {

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.backgroundColor = ThemeTokens.Color.background
        tv.delegate = self
        tv.register(SubsystemStatCell.self, forCellReuseIdentifier: SubsystemStatCell.reuseIdentifier)
        return tv
    }()

    private let summaryCardView = SummaryCardView()
    private let distributionChartView = DistributionChartView()

    private lazy var refreshControl: UIRefreshControl = {
        let rc = UIRefreshControl()
        rc.attributedTitle = NSAttributedString(string: "刷新中...")
        return rc
    }()

    private let actionStackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.distribution = .fillEqually
        sv.spacing = ThemeTokens.Spacing.md
        return sv
    }()

    private lazy var pinnedButton = createActionButton(title: "置顶管理", iconName: "pin")
    private lazy var presetButton = createActionButton(title: "预设目录", iconName: "book-open")
    private lazy var clearButton = createActionButton(title: "清除全部", iconName: "trash-2")

    private var dataSource: RxTableViewSectionedReloadDataSource<SectionModel<String, CacheDashboardViewModel.SubsystemStatItemModel>>?
    private var currentData: DashboardData?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "缓存仪表盘"
        view.backgroundColor = ThemeTokens.Color.background

        // Minimal UI for crash isolation
        let label = UILabel()
        label.text = "缓存仪表盘"
        label.textAlignment = .center
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.textColor = ThemeTokens.Color.text
        view.addSubview(label)
        label.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    override func bindViewModel() {
        // No-op for crash isolation
    }
        let input = CacheDashboardViewModel.Input(
            refresh: refreshControl.rx.controlEvent(.valueChanged).asObservable(),
            selectSubsystem: Observable.empty(),
            tapClearAll: clearButton.rx.tap.asObservable(),
            tapPinnedManage: pinnedButton.rx.tap.asObservable(),
            tapPresetCatalog: presetButton.rx.tap.asObservable()
        )

        let output = viewModel.transform(input: input)

        output.dashboardData
            .drive(onNext: { [weak self] data in
                self?.currentData = data
                self?.summaryCardView.configure(with: data)
                self?.distributionChartView.configure(with: data.sizeDistribution, totalSize: data.totalSize)
                self?.refreshControl.endRefreshing()
            })
            .disposed(by: rx)

        output.isLoading
            .drive(refreshControl.rx.isRefreshing)
            .disposed(by: rx)

        output.subsystemSections
            .drive(onNext: { [weak self] _ in
                self?.tableView.reloadData()
            })
            .disposed(by: rx)

        output.navigateToDetail
            .drive(onNext: { [weak self] subsystemID in
                self?.navigateToDetail(for: subsystemID)
            })
            .disposed(by: rx)

        output.error
            .drive(onNext: { [weak self] error in
                if let error = error, !error.isEmpty {
                    let alert = UIAlertController(title: "错误", message: error, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "确定", style: .default))
                    self?.present(alert, animated: true)
                }
            })
            .disposed(by: rx)

        output.showClearAllConfirm
            .drive(onNext: { [weak self] _ in
                self?.showClearAllConfirmation()
            })
            .disposed(by: rx)
    }

    private func setupUI() {
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func setupTableView() {
        tableView.refreshControl = refreshControl

        let headerContainer = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 320))
        headerContainer.addSubview(summaryCardView)
        headerContainer.addSubview(distributionChartView)
        headerContainer.addSubview(actionStackView)

        summaryCardView.snp.makeConstraints { make in
            make.top.equalTo(headerContainer).offset(8)
            make.leading.trailing.equalTo(headerContainer).inset(0)
        }

        distributionChartView.snp.makeConstraints { make in
            make.top.equalTo(summaryCardView.snp.bottom).offset(12)
            make.leading.trailing.equalTo(headerContainer).inset(16)
            make.height.equalTo(160)
        }

        actionStackView.snp.makeConstraints { make in
            make.top.equalTo(distributionChartView.snp.bottom).offset(12)
            make.leading.trailing.equalTo(headerContainer).inset(16)
            make.bottom.equalTo(headerContainer).offset(-8)
            make.height.equalTo(44)
        }

        tableView.tableHeaderView = headerContainer

        for v in [pinnedButton, presetButton, clearButton] { actionStackView.addArrangedSubview(v) }

        dataSource = RxTableViewSectionedReloadDataSource<SectionModel<String, CacheDashboardViewModel.SubsystemStatItemModel>>(
            configureCell: { _, tableView, indexPath, item in
                let cell = tableView.dequeueReusableCell(withIdentifier: SubsystemStatCell.reuseIdentifier, for: indexPath) as! SubsystemStatCell
                cell.configure(with: item)
                return cell
            },
            titleForHeaderInSection: { ds, index in
                ds.sectionModels[index].model
            }
        )
    }

    private func navigateToDetail(for subsystemID: SubsystemID) {
        let alert = UIAlertController(
            title: subsystemID.nameZh,
            message: "子系统详情页面待实现\nID: \(subsystemID.rawValue)",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    private func showClearAllConfirmation() {
        let alert = UIAlertController(
            title: "清除所有缓存",
            message: "这将清除所有缓存子系统的数据。置顶的 URL 不会被删除。确定继续？",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "清除", style: .destructive) { [weak self] _ in
            self?.performClearAll()
        })
        present(alert, animated: true)
    }

    private func performClearAll() {
        let loading = UIAlertController(title: nil, message: "正在清除...", preferredStyle: .alert)
        present(loading, animated: true)

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.1) { [weak self] in
            WebCacheManager.shared.clearAllCache()

            DispatchQueue.main.async {
                loading.dismiss(animated: true) {
                    let done = UIAlertController(title: "完成", message: "所有缓存已清除", preferredStyle: .alert)
                    done.addAction(UIAlertAction(title: "确定", style: .default) { _ in
                        self?.refreshControl.beginRefreshing()
                        self?.refreshControl.sendActions(for: .valueChanged)
                    })
                    self?.present(done, animated: true)
                }
            }
        }
    }

    private func createActionButton(title: String, iconName: String) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(lucideId: iconName), for: .normal)
        btn.setTitle(" \(title)", for: .normal)
        btn.titleLabel?.font = UIFont.preferredFont(forTextStyle: .caption1)
        btn.setTitleColor(ThemeTokens.Color.primary, for: .normal)
        btn.layer.cornerRadius = ThemeTokens.CornerRadius.md
        btn.clipsToBounds = true
        btn.backgroundColor = ThemeTokens.Color.surface
        btn.layer.borderColor = ThemeTokens.Color.border.cgColor
        btn.layer.borderWidth = 1
        btn.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        return btn
    }
}

extension CacheDashboardViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        guard let data = currentData else { return 0 }
        let activeCount = data.subsystems.filter { $0.hasData || $0.status == .active && $0.totalEntries > 0 }.count
        let inactiveCount = data.subsystems.filter { !$0.hasData && $0.status != .active || $0.totalEntries == 0 }.count
        var count = 0
        if activeCount > 0 { count += 1 }
        if inactiveCount > 0 { count += 1 }
        return count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let data = currentData else { return 0 }
        let activeItems = data.subsystems.filter { $0.hasData || $0.status == .active && $0.totalEntries > 0 }
        let inactiveItems = data.subsystems.filter { !$0.hasData || $0.status != .active || $0.totalEntries == 0 }
        if section == 0 && !activeItems.isEmpty { return activeItems.count }
        return inactiveItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let data = currentData else { return UITableViewCell() }
        let activeStats = data.subsystems.filter { $0.hasData || $0.status == .active }
        let inactiveStats = data.subsystems.filter { !$0.hasData && $0.status != .active }
        let stats = (indexPath.section == 0) ? activeStats : inactiveStats
        let item = CacheDashboardViewModel.SubsystemStatItemModel(from: stats[indexPath.row])
        let cell = tableView.dequeueReusableCell(withIdentifier: SubsystemStatCell.reuseIdentifier, for: indexPath) as! SubsystemStatCell
        cell.configure(with: item)
        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let data = currentData else { return nil }
        let activeCount = data.subsystems.filter { $0.hasData || $0.status == .active && $0.totalEntries > 0 }.count
        if section == 0 && activeCount > 0 { return "活跃" }
        return "空闲"
    }
}

extension CacheDashboardViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let data = currentData else { return }
        let activeStats = data.subsystems.filter { $0.hasData || $0.status == .active }
        let inactiveStats = data.subsystems.filter { !$0.hasData && $0.status != .active }
        let stats = (indexPath.section == 0) ? activeStats : inactiveStats
        guard indexPath.row < stats.count else { return }
        navigateToDetail(for: stats[indexPath.row].id)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 68
    }
}
