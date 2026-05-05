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
import SVProgressHUD
import WebBridgeKit

/// 缓存管理页面
/// 显示所有已缓存的应用列表，支持删除和刷新
class CacheManagementViewController: UIViewController {

    // MARK: - Properties

    private let viewModel: CacheManagementViewModel
    private let disposeBag = DisposeBag()

    // 存储当前的缓存应用列表，用于 swipe-to-delete
    private var cacheApps: [CacheAppInfo] = []

    // MARK: - UI Components

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.backgroundColor = .systemGroupedBackground
        table.separatorStyle = .none
        table.register(CacheAppCell.self, forCellReuseIdentifier: CacheAppCell.identifier)
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 100
        table.delegate = self
        return table
    }()

    private lazy var refreshControl: UIRefreshControl = {
        let control = UIRefreshControl()
        control.tintColor = .systemBlue
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

    private lazy var footerView: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 80))
        view.backgroundColor = .clear

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.alignment = .center

        let totalSizeLabel = UILabel()
        totalSizeLabel.font = .systemFont(ofSize: 14, weight: .medium)
        totalSizeLabel.textColor = .secondaryLabel
        totalSizeLabel.text = "总缓存: 0 B"
        totalSizeLabel.tag = 100

        let appCountLabel = UILabel()
        appCountLabel.font = .systemFont(ofSize: 12, weight: .regular)
        appCountLabel.textColor = .tertiaryLabel
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

    init(viewModel: CacheManagementViewModel = CacheManagementViewModel()) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
        setupNotifications()
    }

    deinit {
        // 移除通知监听
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 每次进入页面时刷新数据
        manualRefreshSubject.accept(())
    }

    // MARK: - Setup

    private func setupUI() {
        title = "缓存管理"
        view.backgroundColor = .systemGroupedBackground

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
                    SVProgressHUD.show()
                } else {
                    SVProgressHUD.dismiss()
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
                SVProgressHUD.showSuccess(withStatus: "缓存已删除")
            })
            .disposed(by: disposeBag)

        // 全部删除成功提示
        output.deleteAllSuccess
            .drive(onNext: {
                SVProgressHUD.showSuccess(withStatus: "所有缓存已清除")
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
        SVProgressHUD.showSuccess(withStatus: "AppID 已复制")
        SVProgressHUD.dismiss(withDelay: 1.5)
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
                SVProgressHUD.showSuccess(withStatus: "缓存已删除")
                SVProgressHUD.dismiss(withDelay: 1.5)
                // 手动刷新
                self.manualRefreshSubject.accept(())
            }
        }
    }

    // 直接删除全部缓存（绕过 RxSwift）
    private func deleteAllCacheDirectly() {
        ManifestCacheManager.shared.clearAll {
            DispatchQueue.main.async {
                SVProgressHUD.showSuccess(withStatus: "所有缓存已清除")
                SVProgressHUD.dismiss(withDelay: 1.5)
                // 手动刷新
                self.manualRefreshSubject.accept(())
            }
        }
    }

    private func deletePage(pageKey: String, appID: String) {
        // 删除特定页面的缓存
        ManifestCacheManager.shared.removeCache(for: pageKey)

        SVProgressHUD.showSuccess(withStatus: "页面缓存已删除")
        SVProgressHUD.dismiss(withDelay: 1.5)

        // 刷新数据
        let _ = viewModel.transform(input: CacheManagementViewModel.Input(
            refresh: .just(()),
            deleteApp: .empty(),
            deleteAll: .empty()
        ))
    }
}

// MARK: - UITableViewDelegate

extension CacheManagementViewController: UITableViewDelegate {

    // Swipe-to-Delete 支持
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let appInfo = cacheApps[indexPath.row]

        // 删除操作
        let deleteAction = UIContextualAction(style: .destructive, title: "删除") { [weak self] (action, view, completionHandler) in
            self?.confirmDelete(appID: appInfo.appID)
            completionHandler(true)
        }

        deleteAction.image = UIImage(systemName: "trash.fill")

        // 详情操作
        let detailAction = UIContextualAction(style: .normal, title: "详情") { [weak self] (action, view, completionHandler) in
            self?.showAppDetails(appInfo: appInfo)
            completionHandler(true)
        }

        detailAction.backgroundColor = .systemBlue
        detailAction.image = UIImage(systemName: "info.circle.fill")

        let configuration = UISwipeActionsConfiguration(actions: [deleteAction, detailAction])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }

    // 长按手势支持（通过 context menu）
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let appInfo = cacheApps[indexPath.row]

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { suggestedActions in
            // 复制 AppID
            let copyAction = UIAction(title: "复制 AppID", image: UIImage(systemName: "doc.on.doc")) { [weak self] _ in
                UIPasteboard.general.string = appInfo.appID
                self?.showCopyFeedback(appID: appInfo.appID)
            }

            // 查看详情
            let detailAction = UIAction(title: "查看详情", image: UIImage(systemName: "info.circle")) { [weak self] _ in
                self?.showAppDetails(appInfo: appInfo)
            }

            // 删除
            let deleteAction = UIAction(title: "删除缓存", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.confirmDelete(appID: appInfo.appID)
            }

            return UIMenu(title: "操作", children: [copyAction, detailAction, deleteAction])
        }
    }
}
