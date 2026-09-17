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
import WebKit


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
            title: "暂无离线应用包",
            description: "安装离线应用后会出现在这里",
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


    /// 网页缓存单独清理：只清 WKWebView 的磁盘/内存网络缓存，不动离线应用包
    /// 与其他目录。用户可以放心清这块最大的可再生产物。
    private lazy var clearWebCacheButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("清理网页缓存", for: .normal)
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .footnote)
        button.setTitleColor(ThemeTokens.Color.primary, for: .normal)
        button.backgroundColor = ThemeTokens.Color.primarySoft
        button.layer.cornerRadius = ThemeTokens.CornerRadius.md
        button.clipsToBounds = true
        button.addTarget(self, action: #selector(clearWebCacheTapped), for: .touchUpInside)
        return button
    }()

    /// S3: breakdown of the number the settings row shows. The settings entry
    /// counts the whole Caches directory, so this card itemizes the same
    /// number instead of listing only manifest offline packages.
    private lazy var summaryCard: UIView = {
        let container = UIView()
        container.backgroundColor = ThemeTokens.Color.surface
        container.layer.cornerRadius = ThemeTokens.CornerRadius.lg
        container.clipsToBounds = true

        let titleLabel = UILabel()
        titleLabel.text = "存储构成"
        titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        titleLabel.textColor = ThemeTokens.Color.text

        let totalLabel = UILabel()
        totalLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        totalLabel.textColor = ThemeTokens.Color.textSecondary
        totalLabel.textAlignment = .right
        totalLabel.tag = 300
        totalLabel.setContentHuggingPriority(.required, for: .horizontal)

        let titleRow = UIStackView(arrangedSubviews: [titleLabel, totalLabel])
        titleRow.axis = .horizontal
        titleRow.spacing = 8

        func breakdownRow(name: String, valueTag: Int, nameColor: UIColor) -> UIStackView {
            let nameLabel = UILabel()
            nameLabel.text = name
            nameLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
            nameLabel.textColor = nameColor
            nameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

            let valueLabel = UILabel()
            valueLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
            valueLabel.textColor = ThemeTokens.Color.text
            valueLabel.textAlignment = .right
            valueLabel.tag = valueTag
            valueLabel.setContentHuggingPriority(.required, for: .horizontal)

            let row = UIStackView(arrangedSubviews: [nameLabel, valueLabel])
            row.axis = .horizontal
            return row
        }

        let rows = UIStackView(arrangedSubviews: [
            titleRow,
            breakdownRow(name: "网页缓存（浏览器网络缓存）", valueTag: 301, nameColor: ThemeTokens.Color.textSecondary),
            breakdownRow(name: "网页离线缓存", valueTag: 302, nameColor: ThemeTokens.Color.textSecondary),
            breakdownRow(name: "其他缓存", valueTag: 303, nameColor: ThemeTokens.Color.textTertiary),
            breakdownRow(name: "已下载离线应用（应用中心下载，不计入总计）", valueTag: 304, nameColor: ThemeTokens.Color.textSecondary),
            clearWebCacheButton
        ])
        rows.axis = .vertical
        rows.spacing = 10
        rows.setCustomSpacing(14, after: titleRow)
        rows.setCustomSpacing(14, after: clearWebCacheButton)

        container.addSubview(rows)
        rows.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
        }
        clearWebCacheButton.snp.makeConstraints { make in
            make.height.equalTo(40)
        }
        return container
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
        refreshStorageSummary()
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
        view.addSubview(summaryCard)
        view.addSubview(tableView)
        view.addSubview(emptyStateView)

        tableView.addSubview(refreshControl)

        setupCharts()

        // 布局：摘要卡常驻列表上方——离线应用包为空时，网页缓存等
        // 占用依然可见（入口数字与页面内容对齐，S3）。
        summaryCard.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(12)
            make.left.right.equalToSuperview().inset(16)
        }

        tableView.snp.makeConstraints { make in
            make.top.equalTo(summaryCard.snp.bottom).offset(12)
            make.left.right.bottom.equalToSuperview()
        }

        emptyStateView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.lessThanOrEqualTo(300)
        }

    }

    private func setupCharts() {
        #if DEBUG
        // Prototype charts with hard-coded figures ("2.3G", "1.1 GB", weekly
        // bars) that never reflect real cache state. Shipping them in Release
        // contradicted the real per-app sizes listed below (N2b), so they are
        // Debug-only and explicitly labeled as demo data.
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

        (chartContainerView.viewWithTag(200) as? UILabel)?.text = "存储分布（演示数据）"
        (chartContainerView.viewWithTag(202) as? UILabel)?.text = "每周使用量（演示）"

        // Auto-size the header: the stale fixed 340pt frame clipped the
        // weekly-usage title (N3). Fit the stack to its own layout.
        let headerWidth = max(tableView.bounds.width, UIScreen.main.bounds.width)
        chartContainerView.frame = CGRect(x: 0, y: 0, width: headerWidth, height: 1)
        let fitHeight = chartContainerView.systemLayoutSizeFitting(
            CGSize(width: headerWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        chartContainerView.frame = CGRect(x: 0, y: 0, width: headerWidth, height: ceil(fitHeight))
        tableView.tableHeaderView = chartContainerView
        #endif
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
            .disposed(by: disposeBag)        // 绑定空状态
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
                self.refreshStorageSummary()
            }
        }
    }

    /// Recompute the summary card numbers off the main thread; the values use
    /// the same Caches-directory scope as the settings row badge (S3).
    private func refreshStorageSummary() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            let total = Self.directorySize(at: caches)
            let webkit = Self.directorySize(at: caches.appendingPathComponent("WebKit"))
            // 离线应用包 = ManifestCache（页面 HTML + 资源 + 映射）+ 持久缓存。
            // 列表条目的大小正是按这三块累加的，两个口径必须一致，合计才能对上。
            let offline = Self.directorySize(at: caches.appendingPathComponent("ManifestCache"))
                + Self.directorySize(at: caches.appendingPathComponent("WebBridgeKit/PersistentCache"))
            let other = max(0, total - webkit - offline)

            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            // 已下载离线应用装在 Application Support（应用中心管辖），
            // 不属于 Caches 口径——单列一行展示，不并入总计（总计与设置
            // 行角标保持同口径）。
            let downloaded = Self.directorySize(at: HTMLAppOfflinePackageLocator.defaultPackagesRoot)
            DispatchQueue.main.async {
                guard let self, self.summaryCard.superview != nil else { return }
                func setValue(_ tag: Int, _ bytes: Int64) {
                    (self.summaryCard.viewWithTag(tag) as? UILabel)?.text = formatter.string(fromByteCount: bytes)
                }
                setValue(300, total)
                setValue(301, webkit)
                setValue(302, offline)
                setValue(303, other)
                setValue(304, downloaded)
            }
        }
    }

    private static func directorySize(at directory: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values?.isRegularFile == true, let size = values?.fileSize else { continue }
            total += Int64(size)
        }
        return total
    }

    // 直接删除全部缓存（绕过 RxSwift）
    private func deleteAllCacheDirectly() {
        ManifestCacheManager.shared.clearAll {
            DispatchQueue.main.async {
                // 入口角标的数字统计的是整个 Caches 目录；只清 manifest 缓存
                // 永远追不上那个数字，这里把 WKWebView 网络缓存一并清掉（S3）。
                WKWebsiteDataStore.default().removeData(
                    ofTypes: [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache],
                    modifiedSince: .distantPast,
                    completionHandler: {}
                )
                // 「其他缓存」里的三个自建目录也一并清掉，角标才能归零。
                Self.removeResidualCacheDirectories()
                HUDService.shared.showSuccess(withStatus: "所有缓存已清除")
                HUDService.shared.dismiss(withDelay: 1.5)
                // 手动刷新
                self.manualRefreshSubject.accept(())
                self.refreshStorageSummary()
            }
        }
    }

    /// 「其他缓存」口径里的自建目录（资源缓存/压缩缓存/页面快照），不在
    /// ManifestCacheManager 的管辖内，全部清除时必须显式删除。
    private static func removeResidualCacheDirectories() {
        DispatchQueue.global(qos: .utility).async {
            let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            for component in ["WebResourceCache", "WebCompressedCache", "WebPageCache"] {
                try? FileManager.default.removeItem(at: caches.appendingPathComponent(component))
            }
        }
    }

    /// 只清浏览器网络缓存（summaryCard 里「网页缓存」一项的来源）。
    @objc private func clearWebCacheTapped() {
        WKWebsiteDataStore.default().removeData(
            ofTypes: [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache],
            modifiedSince: .distantPast
        ) { [weak self] in
            DispatchQueue.main.async {
                HUDService.shared.showSuccess(withStatus: "网页缓存已清除")
                HUDService.shared.dismiss(withDelay: 1.5)
                self?.refreshStorageSummary()
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
        refreshStorageSummary()
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
