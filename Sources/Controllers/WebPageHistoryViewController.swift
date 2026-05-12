//
//  WebPageHistoryViewController.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-15.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import RxCocoa
import RxDataSources
import RxSwift
import SnapKit
import UIKit

// Framework imports

/// 页面历史记录视图控制器
class WebPageHistoryViewController: BaseViewController<WebPageHistoryViewModel> {

    // MARK: - UI Components

    /// 扫码按钮
    private lazy var qrScanButton: UIButton = {
        let btn = UIButton()
        btn.setImage(LucideIcon.scan.templateImage(pointSize: 20, weight: .medium), for: .normal)
        btn.imageView?.tintColor = ThemeTokens.Color.text
        btn.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        btn.accessibilityLabel = "扫描二维码"
        return btn
    }()

    private lazy var viewModeButton: UIButton = {
        let btn = UIButton()
        btn.setImage(LucideIcon.appFill.templateImage(pointSize: 20, weight: .medium), for: .normal)
        btn.imageView?.tintColor = ThemeTokens.Color.text
        btn.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        btn.accessibilityLabel = "切换视图模式"
        return btn
    }()

    /// 列表视图
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.separatorStyle = .none
        tableView.backgroundColor = ThemeTokens.Color.background
        tableView.register(WebPageHistoryCell.self,
                           forCellReuseIdentifier: "\(WebPageHistoryCell.self)")
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 20))
        tableView.rx.setDelegate(self).disposed(by: rx)

        // 长按手势
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleTableViewLongPress(_:)))
        tableView.addGestureRecognizer(longPress)

        return tableView
    }()

    /// 画册视图
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        let spacing: CGFloat = 10
        let itemsPerRow: CGFloat = 2
        let itemWidth = (UIScreen.main.bounds.width - spacing * 3) / itemsPerRow

        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = spacing
        layout.minimumLineSpacing = spacing
        layout.sectionInset = UIEdgeInsets(top: spacing, left: spacing, bottom: spacing, right: spacing)
        layout.itemSize = CGSize(width: itemWidth, height: itemWidth + 50)

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = ThemeTokens.Color.background
        collectionView.register(WebPageHistoryGalleryCell.self,
                                forCellWithReuseIdentifier: WebPageHistoryGalleryCell.reuseIdentifier)
        collectionView.dataSource = self
        collectionView.rx.setDelegate(self).disposed(by: rx)

        // 长按手势
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        collectionView.addGestureRecognizer(longPress)

        return collectionView
    }()

    /// 空状态视图
    private lazy var emptyStateView: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeTokens.Color.background

        let imageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 60, weight: .light)
        imageView.image = LucideIcon.clock.image(pointSize: 60, weight: .medium)
        imageView.tintColor = ThemeTokens.Color.textTertiary
        imageView.contentMode = .scaleAspectFit
        imageView.accessibilityLabel = "无历史记录"

        let label = UILabel()
        label.text = NSLocalizedString("No browsing history yet", comment: "")
        label.textColor = ThemeTokens.Color.textSecondary
        label.font = ThemeTokens.Typography.callout
        label.textAlignment = .center

        let detailLabel = UILabel()
        detailLabel.text = NSLocalizedString("Visit a webpage to see it here", comment: "")
        detailLabel.textColor = ThemeTokens.Color.textTertiary
        detailLabel.font = ThemeTokens.Typography.footnote
        detailLabel.textAlignment = .center

        view.addSubview(imageView)
        view.addSubview(label)
        view.addSubview(detailLabel)

        imageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-60)
            make.width.height.equalTo(80)
        }

        label.snp.makeConstraints { make in
            make.top.equalTo(imageView.snp.bottom).offset(20)
            make.left.right.equalToSuperview().inset(40)
        }

        detailLabel.snp.makeConstraints { make in
            make.top.equalTo(label.snp.bottom).offset(8)
            make.left.right.equalToSuperview().inset(40)
        }

        view.isHidden = true
        return view
    }()

    // 进度HUD

    // MARK: - Properties

    private var currentViewMode: ViewMode = .list
    var allHistories: [WebPageHistory] = []
    private let longPressRelay = PublishRelay<WebPageHistory>()

    /// 数据源
    lazy var dataSource = RxTableViewSectionedAnimatedDataSource<WebPageHistorySection>(
        animationConfiguration: AnimationConfiguration(
            insertAnimation: .fade,
            reloadAnimation: .none,
            deleteAnimation: .left
        ),
        configureCell: { [weak self] (_: TableViewSectionedDataSource<WebPageHistorySection>, tableView: UITableView, _: IndexPath, item: WebPageHistory) in
            guard let self = self,
                  let cell = tableView.dequeueReusableCell(
                    withIdentifier: "\(WebPageHistoryCell.self)"
                  ) as? WebPageHistoryCell else {
                return UITableViewCell()
            }
            cell.history = item
            return cell
        }
    )

    // MARK: - Lifecycle

    override func makeUI() {
        // 设置导航栏
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(customView: viewModeButton),
            UIBarButtonItem(customView: qrScanButton)
        ]

        // 添加子视图
        view.addSubview(tableView)
        view.addSubview(collectionView)
        view.addSubview(emptyStateView)

        // 布局
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        emptyStateView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // 初始状态：显示列表，隐藏画册
        collectionView.isHidden = true

        // 绑定按钮事件
        bindButtonActions()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // 确保隐藏所有HUD
        HUDService.shared.dismiss()

        // 初始加载数据（确保在主线程）
        DispatchQueue.main.async { [weak self] in
            if self?.allHistories.isEmpty ?? true {
                self?.viewModel.loadHistories()
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 确保隐藏所有HUD
        HUDService.shared.dismiss()
    }

    override func bindViewModel() {
        let output = viewModel.transform(
            input: WebPageHistoryViewModel.Input(
                refresh: .empty(),
                itemSelect: tableView.rx.modelSelected(WebPageHistory.self).asDriver(),
                itemDelete: .empty(),
                searchText: .empty(),
                viewModeToggle: viewModeButton.rx.tap.asDriver(),
                cacheRequest: .empty(),
                deleteCacheRequest: .empty(),
                qrScan: qrScanButton.rx.tap.asDriver()
            )
        )

        // 绑定数据源
        output.histories
            .drive(onNext: { [weak self] (sections: [WebPageHistorySection]) in
                self?.allHistories = sections.flatMap { $0.items }
            })
            .disposed(by: rx)

        output.histories
            .drive(tableView.rx.items(dataSource: dataSource))
            .disposed(by: rx)

        // 绑定标题
        output.title
            .drive(navigationItem.rx.title)
            .disposed(by: rx)

        // 绑定空状态
        output.isEmpty
            .drive(onNext: { [weak self] (isEmpty: Bool) in
                self?.tableView.isHidden = isEmpty || self?.currentViewMode != .list
                self?.collectionView.isHidden = isEmpty || self?.currentViewMode != .gallery
                self?.emptyStateView.isHidden = !isEmpty
            })
            .disposed(by: rx)

        // 打开URL
        output.openURL
            .drive(onNext: { [weak self] url in
                self?.openURL(url)
            })
            .disposed(by: rx)

        // 缓存进度
        output.cacheProgress
            .drive(onNext: { [weak self] progress in
                self?.updateCacheProgress(progress)
            })
            .disposed(by: rx)

        // 缓存成功
        output.cacheSuccess
            .drive(onNext: { [weak self] in
                self?.hideProgressHUD()
                HUDService.shared.showInfo(withStatus: NSLocalizedString("Cached successfully", comment: ""))
                // 刷新列表
                self?.viewModel.loadHistories()
            })
            .disposed(by: rx)

        // 缓存错误
        output.cacheError
            .drive(onNext: { [weak self] (error: String) in
                self?.hideProgressHUD()
                HUDService.shared.showError(withStatus: error)
            })
            .disposed(by: rx)

        // 显示扫码
        output.showScanner
            .drive(onNext: { [weak self] in
                self?.showQRScanner()
            })
            .disposed(by: rx)

        // 绑定画册数据源
        output.histories
            .drive(onNext: { [weak self] sections in
                guard let self = self else { return }
                // 更新画册数据
                self.allHistories = sections.flatMap { $0.items }
                if self.currentViewMode == .gallery {
                    self.collectionView.reloadData()
                }
            })
            .disposed(by: rx)
    }

    // MARK: - Private Methods

    private func bindButtonActions() {
        // 视图模式切换
        viewModeButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.toggleViewMode()
            })
            .disposed(by: rx)
    }

    private func toggleViewMode() {
        currentViewMode = currentViewMode == .list ? .gallery : .list

        if currentViewMode == .list {
            viewModeButton.setImage(LucideIcon.appFill.templateImage(pointSize: 20, weight: .medium), for: .normal)
            tableView.isHidden = allHistories.isEmpty
            collectionView.isHidden = true
        } else {
            viewModeButton.setImage(LucideIcon.docText.templateImage(pointSize: 20, weight: .medium), for: .normal)
            tableView.isHidden = true
            collectionView.isHidden = allHistories.isEmpty
            collectionView.reloadData()
        }
    }

    func openHistory(_ history: WebPageHistory) {
        guard let url = URL(string: history.url) else { return }

        // 更新访问记录 - 使用异步 API
        Task { @MainActor in
            do {
                try await WebPageHistoryManager.shared.addOrUpdateHistory(url: url, title: history.title)
            } catch {
                HUDService.shared.showError(withStatus: NSLocalizedString("Failed to update history", comment: ""))
                WebBridgeLogger.shared.log(.error, "Failed to update history: \(error.localizedDescription)")
            }
        }

        // 打开浏览器
        if let navigationController = navigationController {
            WebBrowserManager.shared.openBrowser(
                url: url,
                from: navigationController
            )
        }
    }

    func openURL(_ url: URL) {
        WebBrowserManager.shared.openBrowser(url: url, from: navigationController)
    }

    private func showQRScanner() {
        let scannerVC = QRScannerViewController()
        let navController = UINavigationController(rootViewController: scannerVC)

        // 使用RxSwift订阅扫描结果
        // 注意：QRScannerViewController已经在didSuccess中调用了dismiss
        scannerVC.scannerDidSuccess
            .subscribe(onNext: { [weak self] result in
                // 不需要再次dismiss，QRScannerViewController已经处理了
                self?.handleQRScanResult(result)
            })
            .disposed(by: rx)

        present(navController, animated: true)
    }

    func showContextMenu(for history: WebPageHistory, at location: CGPoint) {
        let alert = UIAlertController(
            title: history.title ?? URL(string: history.url)?.host,
            message: nil,
            preferredStyle: .actionSheet
        )

        // 打开
        alert.addAction(UIAlertAction(title: NSLocalizedString("Open", comment: ""), style: .default) { [weak self] _ in
            self?.openHistory(history)
        })

        // 缓存/删除缓存
        if history.isCached {
            alert.addAction(UIAlertAction(title: NSLocalizedString("Delete Cache", comment: ""), style: .default) { _ in
                WebPageOfflineCacheManager.shared.deleteCache(history: history)
                HUDService.shared.showInfo(withStatus: NSLocalizedString("Cache deleted", comment: ""))
            })
        } else {
            alert.addAction(UIAlertAction(title: NSLocalizedString("Cache Offline", comment: ""), style: .default) { [weak self] _ in
                self?.cachePage(history)
            })
        }

        // 分享
        alert.addAction(UIAlertAction(title: NSLocalizedString("Share", comment: ""), style: .default) { [weak self] _ in
            self?.shareHistory(history)
        })

        // 复制链接
        alert.addAction(UIAlertAction(title: NSLocalizedString("Copy Link", comment: ""), style: .default) { _ in
            UIPasteboard.general.string = history.url
            HUDService.shared.showInfo(withStatus: NSLocalizedString("Link copied", comment: ""))
        })

        // 删除
        alert.addAction(UIAlertAction(title: NSLocalizedString("Delete", comment: ""), style: .destructive) { [weak self] _ in
            Task { @MainActor in
                await self?.deleteHistory(history)
            }
        })

        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))

        present(alert, animated: true)
    }

    func cachePage(_ history: WebPageHistory) {
        // 显示进度
        showProgressHUD()

        WebPageOfflineCacheManager.shared.cachePage(history: history) { [weak self] progress in
            self?.updateCacheProgress(progress)
        } completion: { [weak self] result in
            self?.hideProgressHUD()
            switch result {
            case .success:
                HUDService.shared.showInfo(withStatus: NSLocalizedString("Cached successfully", comment: ""))
                // 在主线程刷新列表
                DispatchQueue.main.async {
                    self?.viewModel.loadHistories()
                }
            case .failure(let error):
                HUDService.shared.showError(withStatus: error.localizedDescription)
            }
        }
    }

    func deleteHistory(_ history: WebPageHistory) async {
        do {
            try await WebPageHistoryManager.shared.deleteHistory(id: history.id)
            HUDService.shared.showInfo(withStatus: NSLocalizedString("Deleted", comment: ""))
            // 刷新列表（已经在 MainActor 上了）
            viewModel.loadHistories()
        } catch {
            HUDService.shared.showError(withStatus: NSLocalizedString("Failed to delete", comment: ""))
            WebBridgeLogger.shared.log(.error, "Failed to delete history: \(error.localizedDescription)")
        }
    }

    func shareHistory(_ history: WebPageHistory) {
        guard let url = URL(string: history.url) else { return }

        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )

        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        present(activityVC, animated: true)
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began,
              let indexPath = collectionView.indexPathForItem(at: gesture.location(in: collectionView)),
              indexPath.item < allHistories.count else {
            return
        }

        let history = allHistories[indexPath.item]
        showContextMenu(for: history, at: gesture.location(in: view))
    }

    @objc private func handleTableViewLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began,
              let indexPath = tableView.indexPathForRow(at: gesture.location(in: tableView)),
              let history = try? dataSource.model(at: indexPath) as? WebPageHistory else {
            return
        }

        showContextMenu(for: history, at: gesture.location(in: view))
    }

    // MARK: - Progress HUD

    private func showProgressHUD() {
        HUDService.shared.show()
        HUDService.shared.setStatus(NSLocalizedString("Caching...", comment: "Caching..."))
    }

    private func updateCacheProgress(_ progress: Double) {
        let percent = Int(progress * 100)
        HUDService.shared.showProgress(Float(progress))
        HUDService.shared.setStatus("\(percent)%")
    }

    private func hideProgressHUD() {
        HUDService.shared.dismiss()
    }
}
