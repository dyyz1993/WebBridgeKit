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

    private var collectionView: UICollectionView!

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

    private let storageLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .right
        return label
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        print("🔧 [MainVC] viewDidLoad called")
        title = "首页"
        setupUI()
        setupGestures()
        setupNotifications()
        // Note: bindViewModel will be called by BaseViewController in viewWillAppear
        
        // 启动时执行一次自动清理
        WebCacheManager.shared.performAutoCleanup()
    }

    private func setupNotifications() {
        NotificationCenter.default.rx.notification(NSNotification.Name("QRScannerDidScanURL"))
            .subscribe(onNext: { [weak self] notification in
                let url = notification.object as? URL
                let rawString = notification.userInfo?["rawString"] as? String
                self?.handleScannedResult(url: url, rawString: rawString)
            })
            .disposed(by: rx)
            
        // 自动化测试支持：直接通过通知触发原生跳转，避免 URL Scheme 弹窗
        NotificationCenter.default.rx.notification(NSNotification.Name("AutomationTestOpenURL"))
            .compactMap { $0.userInfo?["url"] as? String }
            .compactMap { URL(string: $0) }
            .subscribe(onNext: { [weak self] url in
                print("🤖 [MainVC] Automation trigger: opening \(url.absoluteString) natively")
                self?.openURL(url)
            })
            .disposed(by: rx)

        // 监听历史记录更新通知
        NotificationCenter.default.rx.notification(NSNotification.Name("WebPageHistoryUpdated"))
            .subscribe(onNext: { [weak self] _ in
                print("🔄 [MainVC] History updated notification received")
                self?.viewModel.refreshData()
            })
            .disposed(by: rx)
    }

    private func handleScannedResult(url: URL?, rawString: String?) {
        print("🔍 [MainVC] Handling scanned result - URL: \(url?.absoluteString ?? "nil"), Raw: \(rawString ?? "nil")")
        
        // 1. 优先处理解析后的 URL
        if let url = url {
            // 特殊协议处理：wb-app://
            if url.scheme == "wb-app" {
                handleCustomProtocol(url)
                return
            }
            
            // 判断是否是 Manifest URL
            if url.pathExtension == "json" || url.absoluteString.contains("manifest") {
                loadAndCacheManifest(url)
            } else {
                openURL(url)
            }
            return
        }
        
        // 2. 如果 URL 解析失败，但有原始字符串，尝试二次解析或报错
        if let raw = rawString {
            if raw.starts(with: "wb-app://") {
                if let customUrl = URL(string: raw) {
                    handleCustomProtocol(customUrl)
                } else {
                    showAlert(title: "协议错误", message: "无法解析自定义协议内容: \(raw)")
                }
            } else {
                showAlert(title: "无效内容", message: "无法识别扫描内容: \(raw)")
            }
        }
    }

    private func handleCustomProtocol(_ url: URL) {
        print("🔗 [MainVC] Handling custom protocol: \(url.absoluteString)")
        
        // 示例：wb-app://load?url=https://...
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        
        if url.host == "load" {
            if let targetUrlString = components.queryItems?.first(where: { $0.name == "url" })?.value,
               let targetUrl = URL(string: targetUrlString) {
                handleScannedResult(url: targetUrl, rawString: targetUrlString)
            }
        } else if url.host == "open" {
            // 示例：wb-app://open?url=https://...
            if let targetUrlString = components.queryItems?.first(where: { $0.name == "url" })?.value,
               let targetUrl = URL(string: targetUrlString) {
                openURL(targetUrl)
            }
        }
    }

    private func loadAndCacheManifest(_ url: URL) {
        loadingView.startLoading(message: "正在解析 Manifest...")
        
        Task {
            do {
                // 使用 WebBridgeKit 的 Manifest 加载器获取 Manifest 信息
                let manifest = try await PersistentManifestLoader.shared.fetchManifest(from: url)
                
                await MainActor.run {
                    self.loadingView.stopLoading()
                    self.showAlert(title: "解析成功", message: "发现应用: \(manifest.name ?? "未知")\n已加入缓存队列")
                    // 刷新列表
                    self.viewModel.refreshData()
                }
            } catch {
                await MainActor.run {
                    self.loadingView.stopLoading()
                    print("❌ [MainVC] Failed to load manifest: \(error)")
                    // 如果解析失败，可能是普通 JSON，直接作为 URL 打开
                    self.openURL(url)
                }
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("🔄 [MainVC] viewWillAppear - refreshing data")
        viewModel.refreshData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("👀 [MainVC] viewDidAppear")
    }

    // MARK: - Setup UI

    private func setupUI() {
        view.backgroundColor = UIColor.systemGroupedBackground

        // 导航栏大标题样式
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always

        // 创建CollectionView实例
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 16
        layout.minimumLineSpacing = 20
        layout.sectionInset = UIEdgeInsets(top: 10, left: 20, bottom: 30, right: 20)
        
        // 计算 Cell 大小 (2列布局)
        let screenWidth = UIScreen.main.bounds.width
        let itemWidth = (screenWidth - 40 - 16) / 2
        layout.itemSize = CGSize(width: itemWidth, height: 160)
        layout.headerReferenceSize = CGSize(width: screenWidth, height: 50)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0)
        collectionView.register(URLGridCell.self, forCellWithReuseIdentifier: URLGridCell.identifier)
        collectionView.register(SectionHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: SectionHeaderView.identifier)
        collectionView.showsVerticalScrollIndicator = false
        
        // 设置数据源
        collectionView.dataSource = self

        // 添加背景装饰：顶部渐变或图形
        let topBackground = UIView()
        topBackground.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.05)
        view.insertSubview(topBackground, at: 0)
        topBackground.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.height.equalTo(300)
        }

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

        // 导航栏按钮优化
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        let scanImage = UIImage(systemName: "qrcode.viewfinder", withConfiguration: config)
        let scanItem = UIBarButtonItem(image: scanImage, style: .plain, target: self, action: #selector(openScanner))
        navigationItem.leftBarButtonItem = scanItem
        
        let clearImage = UIImage(systemName: "trash.circle.fill", withConfiguration: config)
        let clearItem = UIBarButtonItem(image: clearImage, style: .plain, target: self, action: #selector(clearAllHistory))
        clearItem.tintColor = .systemRed
        
        let storageItem = UIBarButtonItem(customView: storageLabel)
        navigationItem.rightBarButtonItems = [clearItem, storageItem]

        // 配置空状态
        emptyStateView.configure(
            icon: "square.grid.2x2.fill",
            title: "开启您的极速体验",
            description: "扫描二维码或输入 URL 即可体验离线加载",
            actionTitle: nil
        )
    }

    @objc private func openScanner() {
        let scannerVC = QRScannerViewController()
        navigationController?.pushViewController(scannerVC, animated: true)
    }

    private func setupGestures() {
        // 下拉刷新
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        collectionView.refreshControl = refreshControl

        // Note: RxSwift binding handles cell selection via collectionView.rx.itemSelected
    }

    // MARK: - Bind ViewModel

    override func bindViewModel() {
        print("🔧 [MainVC] bindViewModel called")
        print("🔧 [MainVC] navigationController: \(String(describing: navigationController))")

        // 设置代理以支持 FlowLayout，同时保持 Rx 事件有效
        collectionView.rx.setDelegate(self)
            .disposed(by: rx)

        // 使用 Driver 合并刷新信号，确保每次回到首页都更新
        let refreshTrigger = Driver.merge(
            collectionView.refreshControl!.rx.controlEvent(.valueChanged).asDriver(onErrorJustReturn: ()),
            rx.methodInvoked(#selector(UIViewController.viewWillAppear(_:))).map { _ in () }.asDriver(onErrorJustReturn: ())
        )

        let itemSelect = collectionView.rx.itemSelected
            .do(onNext: { indexPath in
                print("🔧 [MainVC] Cell tapped at indexPath: \(indexPath)")
            })
            .asDriver(onErrorDriveWith: .empty())

        let scanButtonTap = scanButton.rx.tap
            .asDriver(onErrorDriveWith: .empty())

        // 使用自定义 PublishRelay 处理长按
        let itemLongPressRelay = PublishRelay<IndexPath>()
        
        // 添加长按手势
        let longPressGesture = UILongPressGestureRecognizer()
        collectionView.addGestureRecognizer(longPressGesture)
        longPressGesture.rx.event
            .filter { $0.state == .began }
            .subscribe(onNext: { [weak self] gesture in
                guard let self = self else { return }
                let point = gesture.location(in: self.collectionView)
                if let indexPath = self.collectionView.indexPathForItem(at: point) {
                    print("🔧 [MainVC] Cell long pressed at indexPath: \(indexPath)")
                    itemLongPressRelay.accept(indexPath)
                }
            })
            .disposed(by: rx)

        let input = MainViewModel.Input(
            refresh: refreshTrigger,
            itemSelect: itemSelect,
            itemLongPress: itemLongPressRelay.asDriver(onErrorJustReturn: IndexPath(item: 0, section: 0)),
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
            .drive(onNext: { [weak self] (isEmpty: Bool) in
                guard let self = self else { return }

                if isEmpty {
                    // 显示空状态，隐藏collectionView
                    self.view.bringSubviewToFront(self.emptyStateView)
                    self.emptyStateView.isHidden = false
                    self.collectionView.isHidden = true
                } else {
                    // 隐藏空状态，显示collectionView
                    self.emptyStateView.isHidden = true
                    self.collectionView.isHidden = false
                    self.view.bringSubviewToFront(self.collectionView)
                }
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
            .drive(onNext: { [weak self] (loading: Bool) in
                if loading {
                    // 下拉刷新不需要显示 loading view
                } else {
                    self?.collectionView.refreshControl?.endRefreshing()
                }
            })
            .disposed(by: rx)

        viewModel.totalStorageSizeRelay
            .asDriver()
            .drive(storageLabel.rx.text)
            .disposed(by: rx)
    }

    // MARK: - Private Methods

    private func updateCollectionView(sections: [WebPageHistorySection]) {
        print("🔄 [MainVC] updateCollectionView called with \(sections.count) sections")
        
        // 关键：直接刷新，不再使用带延迟的 Observable 订阅，避免内存泄漏和重复刷新
        DispatchQueue.main.async { [weak self] in
            self?.collectionView.reloadData()
            print("🔄 [MainVC] collectionView.reloadData() executed")
        }
            
        // 注意：不要在这里手动设置 delegate = self，否则会破坏 RxSwift 的 itemSelected 绑定
        // Delegate 已在 bindViewModel 中通过 rx.setDelegate(self) 设置
        collectionView.dataSource = self
    }

    @objc private func refreshData() {
        print("🔄 [MainVC] refreshData (Pull-to-refresh) triggered")
        // 不需要在这里手动调用 viewModel.refreshData()，
        // 因为 bindViewModel 中已经绑定了 refreshControl.rx.controlEvent(.valueChanged)
    }

    @objc private func clearAllHistory() {
        let alert = UIAlertController(title: "彻底清理", message: "这将删除所有访问历史、收藏以及本地缓存资源。确定要继续吗？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "清理全部", style: .destructive) { [weak self] _ in
            // 1. 清理历史记录
            WebPageHistoryManager.shared.clearAllHistory()
            // 2. 清理所有缓存 (WKWebView, Manifests, Resources)
            WebCacheManager.shared.clearAll()
            // 3. 刷新 UI
            self?.viewModel.refreshData()
            self?.showAlert(title: "清理完成", message: "所有历史和缓存已清空")
        })
        present(alert, animated: true)
    }

    private func openURL(_ url: URL) {
        print("🔗 [MainVC] openURL called: \(url.absoluteString)")

        // 保存上次打开的 URL（如果启用了记忆功能）
        if UserDefaults.standard.bool(forKey: "EnableLastAppMemory") {
            UserDefaults.standard.set(url.absoluteString, forKey: "LastOpenedURL")
            UserDefaults.standard.synchronize()
            print("💾 [MainVC] Saved LastOpenedURL: \(url.absoluteString)")
        }

        // 使用 WebBrowserManager 打开支持缓存的浏览器
        print("🔗 [MainVC] Calling WebBrowserManager.shared.openBrowserWithCache...")
        WebBrowserManager.shared.openBrowserWithCache(
            url: url,
            params: WebBrowserParams(displayMode: .normal),
            from: navigationController
        )
        print("✅ [MainVC] WebBrowserManager.shared.openBrowserWithCache returned")
    }

    private func showActionSheet(url: URL) {
        let history = viewModel.getHistory(url: url)
        let alert = UIAlertController(
            title: history?.title ?? url.host ?? url.absoluteString,
            message: """
                域名: \(url.host ?? "未知")
                缓存大小: \(history?.formattedSize ?? "0 KB")
                访问次数: \(history?.visitCount ?? 0) 次
                """,
            preferredStyle: .actionSheet
        )

        alert.addAction(UIAlertAction(title: "打开", style: .default, handler: { [weak self] _ in
            self?.openURL(url)
        }))

        // 判断是否已置顶
        let isPinned = viewModel.isPinned(url: url)
        alert.addAction(UIAlertAction(title: isPinned ? "取消置顶" : "置顶", style: .default, handler: { [weak self] _ in
            self?.viewModel.togglePin(url: url)
            self?.viewModel.refreshData()
        }))

        alert.addAction(UIAlertAction(title: "收藏", style: .default, handler: { [weak self] _ in
            self?.viewModel.addToFavorites(url: url)
            self?.showAlert(title: "成功", message: "已添加到收藏")
            self?.viewModel.refreshData()
        }))

        alert.addAction(UIAlertAction(title: "清除缓存", style: .destructive, handler: { [weak self] _ in
            self?.viewModel.clearCache(url: url)
            self?.viewModel.refreshData()
        }))

        alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))

        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = self.view
            popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }

        present(alert, animated: true, completion: nil)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

// MARK: - UICollectionViewDataSource

extension MainViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return viewModel.historiesRelayValue.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let sections = viewModel.historiesRelayValue
        guard section < sections.count else { return 0 }
        return sections[section].items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: URLGridCell.identifier,
            for: indexPath
        ) as! URLGridCell

        let sections = viewModel.historiesRelayValue
        let history = sections[indexPath.section].items[indexPath.item]
        cell.history = history

        // 设置置顶和收藏的点击事件
        cell.onPinToggle = { [weak self] in
            guard let self = self, let url = URL(string: history.url) else { return }
            print("📌 [MainVC] Toggled pin for: \(url.absoluteString)")
            self.viewModel.togglePin(url: url)
            self.viewModel.refreshData()
        }
        
        cell.onFavoriteToggle = { [weak self] in
            guard let self = self, let url = URL(string: history.url) else { return }
            print("⭐ [MainVC] Toggled favorite for: \(url.absoluteString)")
            self.viewModel.toggleFavorite(url: url)
            self.viewModel.refreshData()
        }

        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: SectionHeaderView.identifier, for: indexPath) as! SectionHeaderView
            let sections = viewModel.historiesRelayValue
            header.titleLabel.text = sections[indexPath.section].header
            return header
        }
        return UICollectionReusableView()
    }
}

// MARK: - SectionHeaderView

class SectionHeaderView: UICollectionReusableView {
    static let identifier = "SectionHeader"
    
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        label.textColor = .label
        return label
    }()

    private let indicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBlue
        view.layer.cornerRadius = 2
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(indicatorView)
        addSubview(titleLabel)

        indicatorView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
            make.width.equalTo(4)
            make.height.equalTo(18)
        }

        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(indicatorView.snp.right).offset(10)
            make.centerY.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension MainViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let screenWidth = collectionView.bounds.width
        let itemWidth = (screenWidth - 40 - 16) / 2
        return CGSize(width: itemWidth, height: 160)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.bounds.width, height: 60)
    }
}
