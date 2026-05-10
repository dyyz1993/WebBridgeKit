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

    private lazy var addButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let image = UIImage(systemName: "plus", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = ThemeColors.current.text
        button.snp.makeConstraints { make in
            make.width.height.equalTo(44)
        }
        return button
    }()

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
        view.backgroundColor = ThemeColors.current.background

        // Set accessibility identifiers
        tableView.accessibilityIdentifier = "favorite.tableView"
        emptyStateView.accessibilityIdentifier = "favorite.emptyStateView"
        loadingView.accessibilityIdentifier = "favorite.loadingView"
        addButton.accessibilityIdentifier = "favorite.addButton"

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

        // 导航栏右侧按钮
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: addButton)

        // 配置空状态
        emptyStateView.configure(
            icon: "star",
            title: L10n.tr("favorite.empty_title"),
            description: L10n.tr("favorite.empty_description"),
            actionTitle: nil
        )

        // 配置表格视图
        tableView.dragDelegate = self
        tableView.dropDelegate = self
        tableView.dragInteractionEnabled = true

        tableView.rx.setDelegate(self).disposed(by: rx)
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

        let itemSelect = tableView.rx.itemSelected
            .asDriver()

        let pinToggle = PublishRelay<String>()
            .asDriver(onErrorJustReturn: "")

        let cacheModeToggle = PublishRelay<(String, Bool)>()
            .asDriver(onErrorJustReturn: ("", false))

        let itemDelete = PublishRelay<String>()
            .asDriver(onErrorJustReturn: "")

        let input = FavoriteViewModel.Input(
            refresh: refresh,
            itemSelect: itemSelect,
            pinToggle: pinToggle,
            cacheModeToggle: cacheModeToggle,
            itemDelete: itemDelete
        )

        let output = viewModel.transform(input: input)

        // 绑定数据（直接 reactive binding，避免每次 reload 重建 rx.items 导致 DelegateProxy 冲突）
        output.favorites
            .drive(onNext: { [weak self] sections in
                self?.currentSections = sections
            })
            .disposed(by: rx)

        output.favorites
            .map { $0.flatMap { $0.items } }
            .drive(tableView.rx.items(cellIdentifier: FavoriteCell.identifier, cellType: FavoriteCell.self)) { [weak self] _, favorite, cell in
                cell.favorite = favorite
                cell.onPinToggle = { id in
                    self?.handlePinToggle(id: id)
                }
                cell.onCacheModeToggle = { id, enabled in
                    self?.handleCacheModeToggle(id: id, enabled: enabled)
                }
            }
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
        WebBrowserManager.shared.openBrowser(
            url: url,
            params: WebBrowserParams(displayMode: .normal),
            from: navigationController
        )
    }

    private func handlePinToggle(id: String) {
        // 通过 PublishRelay 发送事件
        let input = FavoriteViewModel.Input(
            refresh: .empty(),
            itemSelect: .empty(),
            pinToggle: .just(id),
            cacheModeToggle: .empty(),
            itemDelete: .empty()
        )
        _ = viewModel.transform(input: input)
    }

    private func handleCacheModeToggle(id: String, enabled: Bool) {
        let input = FavoriteViewModel.Input(
            refresh: .empty(),
            itemSelect: .empty(),
            pinToggle: .empty(),
            cacheModeToggle: .just((id, enabled)),
            itemDelete: .empty()
        )
        _ = viewModel.transform(input: input)
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

// MARK: - UITableViewDelegate

extension FavoriteViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: L10n.tr("common.delete")) { [weak self] _, _, completion in
            guard let self = self else {
                completion(false)
                return
            }

            // Get all favorites flattened from sections
            let allFavorites = self.currentSections.flatMap { $0.items }
            guard let favorite = allFavorites[safe: indexPath.row] else {
                completion(false)
                return
            }

            self.handleDelete(id: favorite.id)
            completion(true)
        }

        deleteAction.backgroundColor = ThemeColors.current.error

        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}

// MARK: - UITableViewDragDelegate

extension FavoriteViewController: UITableViewDragDelegate {
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        // 只允许在同一个 section 内拖拽
        guard !currentSections.isEmpty else { return [] }

        let itemProvider = NSItemProvider(object: String(indexPath.section) as NSString)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = indexPath
        return [dragItem]
    }
}

// MARK: - UITableViewDropDelegate

extension FavoriteViewController: UITableViewDropDelegate {
    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        guard let destinationIndexPath = coordinator.destinationIndexPath,
              let dragItem = coordinator.items.first,
              let sourceIndexPath = dragItem.sourceIndexPath else {
            return
        }

        // 只允许在同一 section 内拖拽
        guard sourceIndexPath.section == destinationIndexPath.section else {
            return
        }

        tableView.performBatchUpdates {
            viewModel.updateSortOrder(
                sourceIndexPath: sourceIndexPath,
                destinationIndexPath: destinationIndexPath
            )
        } completion: { _ in
            coordinator.drop(dragItem.dragItem, toRowAt: destinationIndexPath)
        }
    }

    func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
        // 只允许在同一 section 内拖拽
        if let destinationIndexPath = destinationIndexPath,
           let section = currentSections[safe: destinationIndexPath.section] {
            // 只有普通收藏可以拖拽，置顶的不可以
            if section.header == L10n.tr("favorite.section_favorites") {
                return UITableViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
            }
        }

        return UITableViewDropProposal(operation: .forbidden)
    }
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
