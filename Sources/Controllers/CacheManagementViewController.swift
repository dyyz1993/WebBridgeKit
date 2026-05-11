//
//  CacheManagementViewController.swift
//  SuperApp
//
//  Created by Claude on 2025-02-04.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa


/// 缓存管理页面
/// 显示所有已缓存的应用列表，支持删除和刷新
public class CacheManagementViewController: UIViewController {

    // MARK: - Properties

    private let viewModel: CacheManagementViewModel
    private let disposeBag = DisposeBag()

    // 存储当前的缓存应用列表，用于 swipe-to-delete
    private var cacheApps: [CacheAppInfo] = []

    // MARK: - UI Components

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.backgroundColor = ThemeTokens.Color.background
        table.separatorStyle = .none
        table.register(CacheAppCell.self, forCellReuseIdentifier: CacheAppCell.identifier)
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 100
        table.delegate = self
        return table
    }()

    private lazy var refreshControl: UIRefreshControl = {
        let control = UIRefreshControl()
        control.tintColor = ThemeTokens.Color.primary
        return control
    }()

    private lazy var emptyStateView: EmptyStateView = {
        let view = EmptyStateView()
        view.configure(
            icon: "tray",
            title: "暂无缓存",
            description: "加载网页时会自动创建缓存",
            actionTitle: nil
        )
        return view
    }()

    private lazy var chartContainerView: UIView = {
        let container = UIView()
        container.backgroundColor = ThemeTokens.Color.surface
        container.layer.cornerRadius = ThemeTokens.CornerRadius.lg
        container.clipsToBounds = true

        let titleLabel = UILabel()
        titleLabel.text = "存储分布"
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.tag = 200

        let pieChart = PieChartView()
        pieChart.tag = 201

        let barTitleLabel = UILabel()
        barTitleLabel.text = "每周使用量"
        barTitleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        barTitleLabel.tag = 202

        let barChart = BarChartView()
        barChart.tag = 203

        let stack = UIStackView(arrangedSubviews: [titleLabel, pieChart, barTitleLabel, barChart])
        stack.axis = .vertical
        stack.spacing = ThemeTokens.Spacing.md
        stack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.isLayoutMarginsRelativeArrangement = true

        container.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        pieChart.snp.makeConstraints { make in
            make.height.equalTo(130)
        }

        barChart.snp.makeConstraints { make in
            make.height.equalTo(120)
        }

        return container
    }()

    private lazy var footerView: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 80))
        view.backgroundColor = .clear

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = ThemeTokens.Spacing.sm
        stackView.alignment = .center

        let totalSizeLabel = UILabel()
        totalSizeLabel.font = .systemFont(ofSize: 14, weight: .medium)
        totalSizeLabel.textColor = ThemeTokens.Color.textSecondary
        totalSizeLabel.text = "总缓存: 0 B"
        totalSizeLabel.tag = 100

        let appCountLabel = UILabel()
        appCountLabel.font = .systemFont(ofSize: 12, weight: .regular)
        appCountLabel.textColor = ThemeTokens.Color.textTertiary
        appCountLabel.text = "0 个应用"
        appCountLabel.tag = 101

        stackView.addArrangedSubview(totalSizeLabel)
        stackView.addArrangedSubview(appCountLabel)

        view.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        return view
    }()

    // MARK: - Initialization

    public init(viewModel: CacheManagementViewModel = CacheManagementViewModel()) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
        setupNotifications()
    }

    deinit {
        // 移除通知监听
        NotificationCenter.default.removeObserver(self)
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        manualRefreshSubject.accept(())
    }

    // MARK: - Setup

    private func setupUI() {
        title = "缓存管理"
        view.backgroundColor = ThemeTokens.Color.background

        // 添加导航栏按钮
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "全部清除",
            style: .plain,
            target: self,
            action: #selector(clearAllTapped)
        )

        // 添加子视图
        view.addSubview(tableView)
        view.addSubview(emptyStateView)

        tableView.addSubview(refreshControl)

        setupCharts()

        // 布局
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        emptyStateView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.lessThanOrEqualTo(300)
        }

        tableView.tableFooterView = footerView
    }

    private func setupCharts() {
        let pieChart = chartContainerView.viewWithTag(201) as? PieChartView
        pieChart?.segments = [
            PieSegment(value: 1.1, color: ThemeTokens.Color.primary, label: "E-Commerce · 1.1 GB"),
            PieSegment(value: 0.46, color: ThemeTokens.Color.success, label: "Mini Games · 0.46 GB"),
            PieSegment(value: 0.32, color: ThemeTokens.Color.warning, label: "Toolbox · 0.32 GB"),
            PieSegment(value: 0.28, color: ThemeTokens.Color.gradientEnd, label: "Dashboard · 0.28 GB"),
            PieSegment(value: 0.14, color: ThemeTokens.Color.textSecondary, label: "Other · 0.14 GB")
        ]
        pieChart?.centerText = "2.3G"

        let barChart = chartContainerView.viewWithTag(203) as? BarChartView
        barChart?.items = [
            BarItem(value: 12, color: ThemeTokens.Color.primary.withAlphaComponent(0.4), label: "Mon"),
            BarItem(value: 18, color: ThemeTokens.Color.primary.withAlphaComponent(0.4), label: "Tue"),
            BarItem(value: 8, color: ThemeTokens.Color.primary.withAlphaComponent(0.4), label: "Wed"),
            BarItem(value: 22, color: ThemeTokens.Color.primary.withAlphaComponent(0.4), label: "Thu"),
            BarItem(value: 15, color: ThemeTokens.Color.primary.withAlphaComponent(0.4), label: "Fri"),
            BarItem(value: 28, color: ThemeTokens.Color.primary, label: "Sat"),
            BarItem(value: 10, color: ThemeTokens.Color.primary.withAlphaComponent(0.4), label: "Sun")
        ]

        chartContainerView.frame = CGRect(x: 0, y: 0, width: 0, height: 340)
        chartContainerView.layoutIfNeeded()
        tableView.tableHeaderView = chartContainerView
    }

    private func bindViewModel() {
        // 下拉刷新 + viewWillAppear 时刷新
        let refreshTrigger = Driver.merge(
            refreshControl.rx.controlEvent(.valueChanged).asDriver(),
            manualRefreshSubject.asDriver(onErrorJustReturn: ())
        )

        let input = CacheManagementViewModel.Input(
            refresh: refreshTrigger,
            deleteApp: deleteAppSubject.asDriver(onErrorJustReturn: ""),
            deleteAll: deleteAllSubject.asDriver(onErrorJustReturn: ())
        )

        let output = viewModel.transform(input: input)

        // 绑定数据
        output.cacheApps
            .do(onNext: { [weak self] apps in
                self?.cacheApps = apps
            })
            .drive(tableView.rx.items(cellIdentifier: CacheAppCell.identifier, cellType: CacheAppCell.self)) { [weak self] _, appInfo, cell in
                cell.appInfo = appInfo
                cell.onDelete = { appID in
                    self?.confirmDelete(appID: appID)
                }
                cell.onCopy = { appID in
                    self?.showCopyFeedback(appID: appID)
                }
                cell.onTap = { appInfo in
                    self?.showAppDetails(appInfo: appInfo)
                }
            }
            .disposed(by: disposeBag)

        // 绑定空状态
        output.isEmpty
            .drive(onNext: { [weak self] isEmpty in
                self?.tableView.isHidden = isEmpty
                self?.emptyStateView.isHidden = !isEmpty
            })
            .disposed(by: disposeBag)

        // 绑定加载状态
        output.loading
            .drive(onNext: { [weak self] isLoading in
                if isLoading {
                    HUDService.shared.show()
                } else {
                    HUDService.shared.dismiss()
                    self?.refreshControl.endRefreshing()
                }
            })
            .disposed(by: disposeBag)

        // 绑定总缓存大小
        output.totalCacheSize
            .drive(onNext: { [weak self] size in
                if let label = self?.footerView.viewWithTag(100) as? UILabel {
                    label.text = "总缓存: \(size)"
                }
            })
            .disposed(by: disposeBag)

        // 绑定应用数量
        output.appCount
            .drive(onNext: { [weak self] count in
                if let label = self?.footerView.viewWithTag(101) as? UILabel {
                    label.text = count
                }
            })
            .disposed(by: disposeBag)

        // 删除成功提示
        output.deleteSuccess
            .drive(onNext: {
                HUDService.shared.showSuccess(withStatus: "缓存已删除")
            })
            .disposed(by: disposeBag)

        // 全部删除成功提示
        output.deleteAllSuccess
            .drive(onNext: {
                HUDService.shared.showSuccess(withStatus: "所有缓存已清除")
            })
            .disposed(by: disposeBag)
    }

    private func setupNotifications() {
        // 监听缓存更新通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCacheUpdate),
            name: .manifestCacheDidUpdate,
            object: nil
        )
    }

    @objc private func handleCacheUpdate() {
        // 收到缓存更新通知，触发刷新
        manualRefreshSubject.accept(())
    }

    // MARK: - Actions

    private let manualRefreshSubject = PublishRelay<Void>()
    private let deleteAppSubject = PublishRelay<String>()
    private let deleteAllSubject = PublishRelay<Void>()

    @objc private func clearAllTapped() {
        let alert = UIAlertController(
            title: "确认清除所有缓存",
            message: "此操作将删除所有已缓存的网页和应用，无法恢复。",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "清除", style: .destructive) { [weak self] _ in
            self?.deleteAllCacheDirectly()
        })

        present(alert, animated: true)
    }

    private func confirmDelete(appID: String) {
        let alert = UIAlertController(
            title: "确认删除",
            message: "确定要删除此应用的缓存吗？",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            // 直接调用删除方法（绕过 RxSwift）
            self.deleteCacheDirectly(appID: appID)
        })

        present(alert, animated: true)
    }

    private func showCopyFeedback(appID: String) {
        HUDService.shared.showSuccess(withStatus: "AppID 已复制")
        HUDService.shared.dismiss(withDelay: 1.5)
    }

    private func showAppDetails(appInfo: CacheAppInfo) {
        let detailVC = CacheAppDetailViewController(appInfo: appInfo)
        detailVC.onDeletePage = { [weak self] pageKey in
            self?.confirmDeletePage(pageKey: pageKey, appID: appInfo.appID)
        }
        navigationController?.pushViewController(detailVC, animated: true)
    }

    private func confirmDeletePage(pageKey: String, appID: String) {
        let alert = UIAlertController(
            title: "确认删除页面",
            message: "确定要删除此页面的缓存吗？\n\n页面: \(pageKey)",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            self?.deletePage(pageKey: pageKey, appID: appID)
        })

        present(alert, animated: true)
    }

    // 直接删除方法（绕过 RxSwift）
    private func deleteCacheDirectly(appID: String) {
        ManifestCacheManager.shared.removeCacheByAppID(appID) {
            DispatchQueue.main.async {
                HUDService.shared.showSuccess(withStatus: "缓存已删除")
                HUDService.shared.dismiss(withDelay: 1.5)
                // 手动刷新
                self.manualRefreshSubject.accept(())
            }
        }
    }

    // 直接删除全部缓存（绕过 RxSwift）
    private func deleteAllCacheDirectly() {
        ManifestCacheManager.shared.clearAll {
            DispatchQueue.main.async {
                HUDService.shared.showSuccess(withStatus: "所有缓存已清除")
                HUDService.shared.dismiss(withDelay: 1.5)
                // 手动刷新
                self.manualRefreshSubject.accept(())
            }
        }
    }

    private func deletePage(pageKey: String, appID: String) {
        // 删除特定页面的缓存
        ManifestCacheManager.shared.removeCache(for: pageKey)

        HUDService.shared.showSuccess(withStatus: "页面缓存已删除")
        HUDService.shared.dismiss(withDelay: 1.5)

        // 刷新数据
        _ = viewModel.transform(input: CacheManagementViewModel.Input(
            refresh: .just(()),
            deleteApp: .empty(),
            deleteAll: .empty()
        ))
    }
}

// MARK: - UITableViewDelegate

extension CacheManagementViewController: UITableViewDelegate {

    // Swipe-to-Delete 支持
    public func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let appInfo = cacheApps[indexPath.row]

        // 删除操作
        let deleteAction = UIContextualAction(style: .destructive, title: "删除") { [weak self] (_, _, completionHandler) in
            self?.confirmDelete(appID: appInfo.appID)
            completionHandler(true)
        }

        deleteAction.image = LucideIcon.trash.image()

        // 详情操作
        let detailAction = UIContextualAction(style: .normal, title: "详情") { [weak self] (_, _, completionHandler) in
            self?.showAppDetails(appInfo: appInfo)
            completionHandler(true)
        }

        detailAction.backgroundColor = ThemeTokens.Color.primary
        detailAction.image = LucideIcon.info.image()

        let configuration = UISwipeActionsConfiguration(actions: [deleteAction, detailAction])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }

    // 长按手势支持（通过 context menu）
    public func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let appInfo = cacheApps[indexPath.row]

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            // 复制 AppID
            let copyAction = UIAction(title: "复制 AppID", image: LucideIcon.copy.image()) { [weak self] _ in
                UIPasteboard.general.string = appInfo.appID
                self?.showCopyFeedback(appID: appInfo.appID)
            }

            // 查看详情
            let detailAction = UIAction(title: "查看详情", image: LucideIcon.info.image()) { [weak self] _ in
                self?.showAppDetails(appInfo: appInfo)
            }

            // 删除
            let deleteAction = UIAction(title: "删除缓存", image: LucideIcon.trash.image(), attributes: .destructive) { [weak self] _ in
                self?.confirmDelete(appID: appInfo.appID)
            }

            return UIMenu(title: "操作", children: [copyAction, detailAction, deleteAction])
        }
    }
}
