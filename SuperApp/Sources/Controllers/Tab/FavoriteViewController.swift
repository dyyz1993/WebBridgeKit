//
//  FavoriteViewController.swift
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

/// 收藏管理视图控制器
class FavoriteViewController: BaseViewController<FavoriteViewModel> {

    // MARK: - UI Components

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.register(FavoriteCell.self, forCellReuseIdentifier: FavoriteCell.identifier)
        tableView.showsVerticalScrollIndicator = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        return tableView
    }()

    private let emptyStateView: EmptyStateView = {
        let view = EmptyStateView()
        view.isHidden = true
        return view
    }()

    private let loadingView = LoadingView()

    // MARK: - Properties

    private var currentSections: [URLFavoriteSection] = []
    private var isEditingMode = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.tr("favorite.title")

        view.accessibilityIdentifier = "FavoriteViewController"

        setupUI()
        setupGestures()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.loadFavoritesData()
    }

    // MARK: - Setup UI

    private func setupUI() {
        view.backgroundColor = ThemeTokens.Color.background

        // Set accessibility identifiers
        tableView.accessibilityIdentifier = "favorite.tableView"
        emptyStateView.accessibilityIdentifier = "favorite.emptyStateView"
        loadingView.accessibilityIdentifier = "favorite.loadingView"

        view.addSubview(tableView)
        view.addSubview(emptyStateView)
        view.addSubview(loadingView)

        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        emptyStateView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        loadingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // 配置空状态
        emptyStateView.configure(
            icon: "star",
            title: L10n.tr("favorite.empty_title"),
            description: L10n.tr("favorite.empty_description"),
            actionTitle: nil
        )

        // 直接持有 delegate/dataSource，不走 Rx DelegateProxy：真机 (iOS 18.7,
        // Release) 上点按收藏会在 RXDelegateProxy forwardInvocation 转发期间
        // 撞上代理销毁的 SIGTRAP（crash_1790071569 等四份同签名报告），
        // 这个屏幕不再经过任何 DelegateProxy。
        // 列表顺序固定为「置顶浮顶 + 收藏时间倒序」（FavoriteViewModel），
        // 不再支持拖拽手动排序——时间排序下手拖会被下次刷新覆盖。
        tableView.delegate = self
        tableView.dataSource = self
    }

    private func setupGestures() {
        // 下拉刷新
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        tableView.refreshControl = refreshControl

        // 长按手势进入编辑模式
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        tableView.addGestureRecognizer(longPressGesture)
    }

    // MARK: - Bind ViewModel

    override func bindViewModel() {
        let refresh = tableView.refreshControl!.rx.controlEvent(.valueChanged)
            .map { _ in () }
            .asDriver(onErrorJustReturn: ())

        let itemDelete = PublishRelay<String>()
            .asDriver(onErrorJustReturn: "")

        let input = FavoriteViewModel.Input(
            refresh: refresh,
            itemSelect: .empty(),
            pinToggle: .empty(),
            cacheModeToggle: .empty(),
            itemDelete: itemDelete
        )

        let output = viewModel.transform(input: input)

        // 数据绑定：存 sections 后直接 reloadData（dataSource 为本 VC 直持，
        // 不经 Rx 代理；点选在 didSelectRowAt 里直调 openURL）。
        output.favorites
            .drive(onNext: { [weak self] sections in
                self?.currentSections = sections
                self?.tableView.reloadData()
            })
            .disposed(by: rx)

        output.isEmpty
            .drive(onNext: { [weak self] isEmpty in
                guard let self = self else { return }

                if isEmpty {
                    // 显示空状态，隐藏tableView
                    self.view.bringSubviewToFront(self.emptyStateView)
                    self.emptyStateView.isHidden = false
                    self.tableView.isHidden = true
                } else {
                    // 隐藏空状态，显示tableView
                    self.emptyStateView.isHidden = true
                    self.tableView.isHidden = false
                    self.view.bringSubviewToFront(self.tableView)
                }
            })
            .disposed(by: rx)

        output.openURL
            .drive(onNext: { [weak self] url in
                self?.openURL(url)
            })
            .disposed(by: rx)

        output.loading
            .drive(onNext: { [weak self] loading in
                if loading {
                    // 下拉刷新不需要显示 loading view
                } else {
                    self?.tableView.refreshControl?.endRefreshing()
                }
            })
            .disposed(by: rx)
    }

    // MARK: - Private Methods

    @objc private func refreshData() {
        // 刷新会通过 RxSwift 自动触发
    }

    private func openURL(_ url: URL) {
        DrelFavoriteOpenPolicy.open(url, from: navigationController)
    }

    private func handleDelete(id: String) {
        let alert = UIAlertController(
            title: L10n.tr("favorite.confirm_delete"),
            message: L10n.tr("favorite.delete_message"),
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: L10n.tr("common.cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: L10n.tr("common.delete"), style: .destructive) { _ in
            let input = FavoriteViewModel.Input(
                refresh: .empty(),
                itemSelect: .empty(),
                pinToggle: .empty(),
                cacheModeToggle: .empty(),
                itemDelete: .just(id)
            )
            _ = self.viewModel.transform(input: input)
        })

        present(alert, animated: true)
    }

    /// 收藏夹页的置顶入口：与首页长按操作表共用同一 pinToggle 通道。
    private func handlePinToggle(id: String) {
        let input = FavoriteViewModel.Input(
            refresh: .empty(),
            itemSelect: .empty(),
            pinToggle: .just(id),
            cacheModeToggle: .empty(),
            itemDelete: .empty()
        )
        _ = viewModel.transform(input: input)
    }

    @objc private func handleLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        guard gestureRecognizer.state == .began else { return }

        let point = gestureRecognizer.location(in: tableView)
        guard let indexPath = tableView.indexPathForRow(at: point) else { return }

        // 进入编辑模式
        isEditingMode = true
        tableView.setEditing(true, animated: true)

        // 显示操作菜单
        let alert = UIAlertController(title: L10n.tr("favorite.actions"), message: L10n.tr("favorite.select_action"), preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: L10n.tr("common.cancel"), style: .cancel) { _ in
            self.isEditingMode = false
            self.tableView.setEditing(false, animated: true)
        })

        alert.addAction(UIAlertAction(title: L10n.tr("common.delete"), style: .destructive) { [weak self] _ in
            guard let self = self else { return }

            // Get all favorites flattened from sections
            let allFavorites = self.currentSections.flatMap { $0.items }
            guard let favorite = allFavorites[safe: indexPath.row] else { return }

            self.handleDelete(id: favorite.id)
            self.isEditingMode = false
            self.tableView.setEditing(false, animated: true)
        })

        // 支持 iPad
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = tableView
            popoverController.sourceRect = CGRect(
                x: point.x,
                y: point.y,
                width: 1,
                height: 1
            )
        }

        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension FavoriteViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentSections.flatMap { $0.items }.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FavoriteCell.identifier, for: indexPath) as! FavoriteCell
        let allFavorites = currentSections.flatMap { $0.items }
        if let favorite = allFavorites[safe: indexPath.row] {
            cell.favorite = favorite
        }
        return cell
    }
}

// MARK: - UITableViewDelegate

extension FavoriteViewController: UITableViewDelegate {

    /// 点选直调（不经 Rx itemSelected/DelegateProxy，见 setupUI 注释）。
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let allFavorites = currentSections.flatMap { $0.items }
        guard let favorite = allFavorites[safe: indexPath.row],
              let url = URL(string: favorite.url) else { return }
        openURL(url)
    }

    /// 右滑（leading）= 置顶/取消置顶：与收件箱同一套手势语义
    /// （右滑置顶、左滑删除），用户不需要为两套列表记两种手势。
    /// 整滑直触发：滑过阈值即执行置顶，不需要再点按钮。
    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let allFavorites = currentSections.flatMap { $0.items }
        guard let favorite = allFavorites[safe: indexPath.row] else { return nil }

        let isPinned = favorite.isPinned
        let pinAction = UIContextualAction(style: .normal, title: isPinned ? "取消置顶" : "置顶") { [weak self] _, _, completion in
            self?.handlePinToggle(id: favorite.id)
            completion(true)
        }
        pinAction.backgroundColor = ThemeTokens.Color.warning
        let configuration = UISwipeActionsConfiguration(actions: [pinAction])
        configuration.performsFirstActionWithFullSwipe = true
        return configuration
    }

    /// 左滑（trailing）= 删除（ destructive 全滑直删语义保持不变）。
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        // Get all favorites flattened from sections
        let allFavorites = currentSections.flatMap { $0.items }
        guard let favorite = allFavorites[safe: indexPath.row] else { return nil }

        let deleteAction = UIContextualAction(style: .destructive, title: L10n.tr("common.delete")) { [weak self] _, _, completion in
            guard let self = self else {
                completion(false)
                return
            }

            self.handleDelete(id: favorite.id)
            completion(true)
        }
        deleteAction.backgroundColor = ThemeTokens.Color.error

        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
