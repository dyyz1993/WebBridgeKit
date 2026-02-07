//
//  MainViewModel.swift
//  DemoApp
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import RxCocoa
import RxSwift
import UIKit
import WebBridgeKit

/// 首页 ViewModel
class MainViewModel: ViewModel {

    // MARK: - Input & Output

    struct Input {
        let refresh: Driver<Void>
        let itemSelect: Driver<IndexPath>
        let itemLongPress: Driver<IndexPath>
        let scanButtonTap: Driver<Void>
    }

    struct Output {
        let histories: Driver<[WebPageHistorySection]>
        let isEmpty: Driver<Bool>
        let openURL: Driver<URL>
        let showActionSheet: Driver<URL>
        let showScanner: Driver<Void>
        let loading: Driver<Bool>
    }

    // MARK: - Properties

    private let historyService: HistoryServiceProtocol
    private let favoriteService: FavoriteServiceProtocol

    private let historiesRelay = BehaviorRelay<[WebPageHistorySection]>(value: [])
    private let openURLRelay = PublishRelay<URL>()
    private let showActionSheetRelay = PublishRelay<URL>()
    private let showScannerRelay = PublishRelay<Void>()
    private let loadingRelay = BehaviorRelay<Bool>(value: false)
    private let isEmptyRelay = BehaviorRelay<Bool>(value: true)
    let totalStorageSizeRelay = BehaviorRelay<String>(value: "0 KB")
    
    var historiesRelayValue: [WebPageHistorySection] {
        return historiesRelay.value
    }
    
    var totalStorageSize: String {
        return totalStorageSizeRelay.value
    }

    // MARK: - Initialization

    /// 指定初始化方法，支持依赖注入
    /// - Parameters:
    ///   - historyService: 历史记录服务，默认使用 ServiceLocator 提供
    ///   - favoriteService: 收藏服务，默认使用 ServiceLocator 提供
    init(
        historyService: HistoryServiceProtocol = ServiceLocator.history,
        favoriteService: FavoriteServiceProtocol = ServiceLocator.favorite
    ) {
        self.historyService = historyService
        self.favoriteService = favoriteService
        super.init()
    }

    // MARK: - Transform

    func transform(input: Input) -> Output {
        // 刷新数据
        input.refresh
            .do(onNext: { [weak self] in
                self?.loadingRelay.accept(true)
                self?.loadHistories()
            })
            .drive()
            .disposed(by: rx)

        // 点击项目
        input.itemSelect
            .withLatestFrom(historiesRelay.asDriver()) { indexPath, sections in
                return sections[indexPath.section].items[indexPath.item]
            }
            .flatMap { history -> Driver<URL> in
                let urlString = history.url
                guard !urlString.isEmpty, let url = URL(string: urlString) else {
                    return Driver.empty()
                }
                return Driver.just(url)
            }
            .do(onNext: { [weak self] url in
                self?.openURLRelay.accept(url)
                // 增加访问计数
                self?.historyService.addOrUpdateHistory(url: url, title: nil, favicon: nil)
            })
            .drive()
            .disposed(by: rx)

        // 长按项目
        input.itemLongPress
            .withLatestFrom(historiesRelay.asDriver()) { indexPath, sections in
                return sections[indexPath.section].items[indexPath.item]
            }
            .flatMap { history -> Driver<URL> in
                guard let url = URL(string: history.url) else {
                    return Driver.empty()
                }
                return Driver.just(url)
            }
            .drive(onNext: showActionSheetRelay.accept)
            .disposed(by: rx)

        // 扫码按钮
        input.scanButtonTap
            .do(onNext: { [weak self] in
                self?.showScannerRelay.accept(())
            })
            .drive()
            .disposed(by: rx)

        // 初始加载数据
        loadHistories()

        return Output(
            histories: historiesRelay.asDriver(),
            isEmpty: isEmptyRelay.asDriver(),
            openURL: openURLRelay.asDriver(onErrorJustReturn: URL(string: "https://example.com")!),
            showActionSheet: showActionSheetRelay.asDriver(onErrorJustReturn: URL(string: "https://example.com")!),
            showScanner: showScannerRelay.asDriver(onErrorJustReturn: ()),
            loading: loadingRelay.asDriver()
        )
    }

    // MARK: - Private Methods

    func refreshData() {
        loadHistories()
    }

    /// 执行基于打开频率的自动清理
    /// 当历史记录超过 50 条时，自动清理访问次数少于 2 次的项目
    private func performFrequencyCleanup() {
        WebPageHistoryManager.shared.cleanupLowFrequencyItems(limit: 50)
    }

    private func loadHistories() {
        print("🔍 [MainVM] loadHistories called")
        // 自动清理逻辑已在 WebPageHistoryManager 中优化：会自动忽略收藏和置顶项
        performFrequencyCleanup()

        // 1. 获取置顶项目 (从收藏中获取 isPinned = true)
        let pinnedItems = favoriteService.getAllFavorites()
            .filter("isPinned == true")
            .sorted(byKeyPath: "sortOrder", ascending: true)
            .map { favorite -> WebPageHistory in
                let history = WebPageHistory()
                history.id = favorite.id
                history.url = favorite.url
                history.title = favorite.title ?? favorite.domain ?? "未知"
                history.favicon = favorite.favicon
                history.isPinned = true
                history.isFavorite = true
                
                // 计算缓存大小
                if let url = URL(string: favorite.url) {
                    let cacheID = url.host ?? url.lastPathComponent
                    history.cachedSize = PersistentManifestLoader.shared.getCacheSize(for: cacheID)
                }
                
                return history
            }
        print("🔍 [MainVM] pinnedItems count: \(pinnedItems.count)")

        // 2. 获取收藏项目 (排除已置顶的)
        let favoriteItems = favoriteService.getAllFavorites()
            .filter("isPinned == false")
            .sorted(byKeyPath: "createdAt", ascending: false)
            .map { favorite -> WebPageHistory in
                let history = WebPageHistory()
                history.id = favorite.id
                history.url = favorite.url
                history.title = favorite.title ?? favorite.domain ?? "未知"
                history.favicon = favorite.favicon
                history.isPinned = false
                history.isFavorite = true
                
                // 计算缓存大小
                if let url = URL(string: favorite.url) {
                    let cacheID = url.host ?? url.lastPathComponent
                    history.cachedSize = PersistentManifestLoader.shared.getCacheSize(for: cacheID)
                }
                
                return history
            }

        // 3. 获取最近访问的历史记录 (排除已在收藏中的)
        let favoriteURLs = Set(favoriteService.getAllFavorites().map { $0.url })
        
        // 修改：按照最后访问时间 (lastVisitDate) 降序排列，显示最近的 20 条记录 (原来是 6 条)
        let histories = historyService.getAllHistories()
            .filter { !favoriteURLs.contains($0.url) }
            .sorted { $0.lastVisitDate > $1.lastVisitDate }
            .prefix(20)
            .map { history -> WebPageHistory in
                // 直接返回一个新的对象或修改后的对象，设置 isFavorite 为 false
                let displayHistory = WebPageHistory()
                displayHistory.id = history.id
                displayHistory.url = history.url
                displayHistory.title = history.title
                displayHistory.favicon = history.favicon
                displayHistory.visitCount = history.visitCount
                displayHistory.lastVisitDate = history.lastVisitDate
                displayHistory.isFavorite = false
                displayHistory.isPinned = false
                
                // 确保缓存大小是最新的
                if let url = URL(string: history.url) {
                    let cacheID = url.host ?? url.lastPathComponent
                    displayHistory.cachedSize = PersistentManifestLoader.shared.getCacheSize(for: cacheID)
                    displayHistory.isCached = displayHistory.cachedSize > 0
                }
                return displayHistory
            }

        // 🧪 添加测试入口到列表顶部
        let testEntry = WebPageHistory()
        testEntry.id = "manifest-cache-test"
        testEntry.url = "http://localhost:8080/test_resources/manifest_cache_demo/index.html"
        testEntry.title = "🧪 Manifest 缓存测试"
        testEntry.favicon = nil as Data?
        testEntry.visitCount = 0
        testEntry.lastVisitDate = Date()
        
        // 更新测试入口的缓存大小
        if let url = URL(string: testEntry.url) {
            let cacheID = url.host ?? url.lastPathComponent
            testEntry.cachedSize = PersistentManifestLoader.shared.getCacheSize(for: cacheID)
            testEntry.isCached = testEntry.cachedSize > 0
        }

        var sections: [WebPageHistorySection] = []
        
        if !pinnedItems.isEmpty {
            sections.append(WebPageHistorySection(header: "置顶应用", items: Array(pinnedItems)))
        }
        
        if !favoriteItems.isEmpty {
            sections.append(WebPageHistorySection(header: "我的收藏", items: Array(favoriteItems)))
        }
        
        let recentItems = [testEntry] + Array(histories)
        sections.append(WebPageHistorySection(header: "最近访问", items: recentItems))

        // 计算总存储大小
        let totalBytes = PersistentManifestLoader.shared.getCacheSize()
        let formattedTotalSize = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        totalStorageSizeRelay.accept(formattedTotalSize)

        historiesRelay.accept(sections)
        print("🔍 [MainVM] historiesRelay.accept called with \(sections.count) sections")
        isEmptyRelay.accept(sections.allSatisfy { $0.items.isEmpty })
        loadingRelay.accept(false)
    }

    func addToFavorites(url: URL) {
        let history = historyService.findHistory(url: url)
        favoriteService.addFavorite(url: url, title: history?.title ?? url.host, favicon: history?.favicon)
    }

    func isPinned(url: URL) -> Bool {
        guard let favorite = favoriteService.findFavorite(url: url) else { return false }
        return favorite.isPinned
    }

    func getHistory(url: URL) -> WebPageHistory? {
        return historyService.findHistory(url: url)
    }

    func togglePin(url: URL) {
        if let favorite = favoriteService.findFavorite(url: url) {
            favoriteService.togglePin(id: favorite.id)
        } else {
            // 如果还不是收藏，先添加为收藏并置顶
            let history = historyService.findHistory(url: url)
            if let newFavorite = favoriteService.addFavorite(url: url, title: history?.title ?? url.host, favicon: history?.favicon) {
                favoriteService.togglePin(id: newFavorite.id)
            }
        }
    }

    func toggleFavorite(url: URL) {
        if let favorite = favoriteService.findFavorite(url: url) {
            // 如果已经是收藏，则移除
            favoriteService.deleteFavorite(id: favorite.id)
        } else {
            // 如果不是收藏，则添加
            let history = historyService.findHistory(url: url)
            favoriteService.addFavorite(url: url, title: history?.title ?? url.host, favicon: history?.favicon)
        }
    }

    func clearCache(url: URL) {
        PersistentManifestLoader.shared.clearCache(for: url)
        // 清除缓存后刷新列表以更新显示的大小
        loadHistories()
    }

    func deleteHistory(url: URL) {
        guard let history = historyService.findHistory(url: url) else { return }
        historyService.deleteHistory(id: history.id)
        loadHistories()
    }

    func clearAllHistory() {
        historyService.clearAllHistory()
        loadHistories()
    }
}

// MARK: - Section Model

struct WebPageHistorySection {
    let header: String
    let items: [WebPageHistory]
}
