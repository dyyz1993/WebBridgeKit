//
//  MainViewController.swift
//  DemoApp
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa
import WebBridgeKit

/// 首页宫格视图控制器
class MainViewController: BaseViewController<MainViewModel> {

    // MARK: - UI Components

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.register(URLGridCell.self, forCellWithReuseIdentifier: URLGridCell.identifier)
        cv.showsVerticalScrollIndicator = false
        return cv
    }()

    private let emptyStateView: EmptyStateView = {
        let view = EmptyStateView()
        view.isHidden = true
        return view
    }()

    private let scanButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let image = UIImage(systemName: "qrcode.viewfinder", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .label
        return button
    }()

    private let loadingView = LoadingView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "首页"
        setupUI()
        setupGestures()
    }

    // MARK: - Setup UI

    private func setupUI() {
        view.backgroundColor = UIColor.systemGroupedBackground

        // Accessibility identifiers
        view.accessibilityIdentifier = "MainViewController"
        collectionView.accessibilityIdentifier = "main.collectionView"
        scanButton.accessibilityIdentifier = "main.scanButton"

        view.addSubview(collectionView)
        view.addSubview(emptyStateView)
        view.addSubview(loadingView)

        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        emptyStateView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        loadingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // 导航栏右侧按钮
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: scanButton)

        // 配置空状态
        emptyStateView.configure(
            icon: "globe",
            title: "暂无访问记录",
            description: "访问网页后会显示在这里",
            actionTitle: nil
        )
    }

    private func setupGestures() {
        // 下拉刷新
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }

    // MARK: - Bind ViewModel

    override func bindViewModel() {
        let refresh = collectionView.refreshControl!.rx.controlEvent(.valueChanged)
            .map { _ in () }
            .asDriver(onErrorJustReturn: ())

        let itemSelect = collectionView.rx.itemSelected
            .asDriver()

        let itemLongPress = collectionView.rx.itemSelected
            .asDriver()

        let scanButtonTap = scanButton.rx.tap
            .asDriver()

        let input = MainViewModel.Input(
            refresh: refresh,
            itemSelect: itemSelect,
            itemLongPress: itemLongPress,
            scanButtonTap: scanButtonTap
        )

        let output = viewModel.transform(input: input)

        // 绑定数据
        output.histories
            .drive(onNext: { [weak self] sections in
                self?.updateCollectionView(sections: sections)
            })
            .disposed(by: rx)

        output.isEmpty
            .drive(onNext: { [weak self] isEmpty in
                self?.emptyStateView.isHidden = !isEmpty
                self?.collectionView.isHidden = isEmpty
            })
            .disposed(by: rx)

        output.openURL
            .drive(onNext: { [weak self] url in
                self?.openURL(url)
            })
            .disposed(by: rx)

        output.showActionSheet
            .drive(onNext: { [weak self] url in
                self?.showActionSheet(url: url)
            })
            .disposed(by: rx)

        output.showScanner
            .drive(onNext: { [weak self] in
                self?.openScanner()
            })
            .disposed(by: rx)

        output.loading
            .drive(onNext: { [weak self] loading in
                if loading {
                    // 下拉刷新不需要显示 loading view
                } else {
                    self?.collectionView.refreshControl?.endRefreshing()
                }
            })
            .disposed(by: rx)
    }

    // MARK: - Private Methods

    private func updateCollectionView(sections: [WebPageHistorySection]) {
        collectionView.dataSource = nil
        collectionView.delegate = nil

        // Get all histories from sections
        let allHistories = sections.flatMap { $0.items }

        Observable.just(allHistories)
            .bind(to: collectionView.rx.items) { collectionView, index, history in
                let indexPath = IndexPath(item: index, section: 0)
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: URLGridCell.identifier,
                    for: indexPath
                ) as! URLGridCell

                // 计算单元格大小
                let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout
                let width = (collectionView.bounds.width - 32 - 12) / 2
                layout?.itemSize = CGSize(width: width, height: width)

                cell.history = history

                // 检查收藏状态
                if let url = URL(string: history.url) {
                    cell.isFavorite = URLFavoriteManager.shared.findFavorite(url: url) != nil
                } else {
                    cell.isFavorite = false
                }

                return cell
            }
            .disposed(by: rx)
    }

    @objc private func refreshData() {
        // Load histories will be triggered automatically through RxSwift
    }

    private func openURL(_ url: URL) {
        // 使用 WebBrowserManager 打开浏览器
        WebBrowserManager.shared.openBrowser(
            url: url,
            params: WebBrowserParams(displayMode: .normal),
            from: navigationController
        )
    }

    private func showActionSheet(url: URL) {
        let actionSheet = ActionSheetView()

        let actions: [(title: String, style: UIAlertAction.Style, action: () -> Void)] = [
            (title: "打开", style: .default, action: {
                self.openURL(url)
            }),
            (title: "收藏", style: .default, action: {
                self.viewModel.addToFavorites(url: url)
                self.showAlert(title: "成功", message: "已添加到收藏")
            }),
            (title: "从历史移除", style: .destructive, action: {
                self.viewModel.deleteHistory(url: url)
            })
        ]

        actionSheet.configure(
            title: url.host ?? url.absoluteString,
            actions: actions
        )

        actionSheet.show(in: view)
    }

    private func openScanner() {
        // 打开二维码扫描器
        let scannerVC = QRScannerViewController()
        scannerVC.modalPresentationStyle = .fullScreen
        present(scannerVC, animated: true)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension MainViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (collectionView.bounds.width - 32 - 12) / 2
        return CGSize(width: width, height: width)
    }
}
