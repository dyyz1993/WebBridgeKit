//
//  MainViewModel.swift
//  SuperApp
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

        let appGridOffset = MainSection.appGrid.rawValue

        input.itemSelect
            .filter { $0.section >= appGridOffset }
            .withLatestFrom(historiesRelay.asDriver()) { indexPath, sections -> WebPageHistory? in
                let gridIndex = indexPath.section - appGridOffset
                guard gridIndex >= 0 && gridIndex < sections.count,
                      indexPath.item < sections[gridIndex].items.count else {
                    return nil
                }
                return sections[gridIndex].items[indexPath.item].history
            }
            .compactMap { $0 }
            .flatMap { (history: WebPageHistory) -> Driver<URL> in
                let urlString = history.url
                guard !urlString.isEmpty, let url = URL(string: urlString) else {
                    return Driver.empty()
                }
                return Driver.just(url)
            }
            .do(onNext: { [weak self] url in
                self?.openURLRelay.accept(url)
                self?.historyService.addOrUpdateHistory(url: url, title: nil, favicon: nil)
            })
            .drive()
            .disposed(by: rx)

        // 长按项目
        input.itemLongPress
            .filter { $0.section >= appGridOffset }
            .withLatestFrom(historiesRelay.asDriver()) { indexPath, sections -> WebPageHistory? in
                let gridIndex = indexPath.section - appGridOffset
                guard gridIndex >= 0 && gridIndex < sections.count,
                      indexPath.item < sections[gridIndex].items.count else {
                    return nil
                }
                return sections[gridIndex].items[indexPath.item].history
            }
            .compactMap { $0 }
            .flatMap { (history: WebPageHistory) -> Driver<URL> in
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
            openURL: openURLRelay.asDriver(onErrorJustReturn: URL(string: "https://wbk.shanbox.19930810.xyz:8443")!),
            showActionSheet: showActionSheetRelay.asDriver(onErrorJustReturn: URL(string: "https://wbk.shanbox.19930810.xyz:8443")!),
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
        Task {
            try? await WebPageHistoryManager.shared.cleanupLowFrequencyItems(limit: 50)
        }
    }

    private func loadHistories() {
        Log.debug("loadHistories called", category: .ui)

        // 使用 Task 执行异步操作
        Task { [weak self] in
            guard let self = self else { return }

            // 1. 执行自动清理（异步）
            try? await WebPageHistoryManager.shared.cleanupLowFrequencyItems(limit: 50)

            // 2. 异步获取所有历史记录
            let historyResults: [WebPageHistory]
            do {
                historyResults = try await WebPageHistoryManager.shared.getAllHistories()
            } catch {
                Log.error("Failed to get all histories: \(error.localizedDescription)", category: .ui)
                historyResults = []
            }

            // 3. 一次性获取所有收藏数据，避免在循环中重复查询 Realm
            // 注意：favoriteService 目前还是同步的，保持在主线程执行
            await MainActor.run {
                let allFavorites = self.favoriteService.getAllFavorites()
                let favoriteURLs = Set(allFavorites.map { $0.url })

                let cacheTypeOrder = ["offline", "smart", "live"]
                let cacheTypeHeaders: [String: String] = [
                    "offline": "已收藏 · 离线可用",
                    "smart": "已收藏 · 智能缓存",
                    "live": "已收藏"
                ]

                let allItems = allFavorites.sorted { $0.sortOrder < $1.sortOrder }
                    .map { favorite -> WebPageHistorySectionItem in
                        let history = WebPageHistory()
                        history.id = favorite.id
                        history.url = favorite.url
                        history.title = favorite.title ?? favorite.domain ?? L10n.tr("common.unknown")
                        history.favicon = favorite.favicon
                        history.isPinned = favorite.isPinned
                        history.isFavorite = true

                        let itemURL = favorite.url
                        if let url = URL(string: itemURL) {
                            let cacheID = url.host ?? url.lastPathComponent
                            history.cachedSize = favorite.enableCacheMode ? 1 : 0
                            history.isCached = favorite.enableCacheMode

                            Task.detached {
                                let size = PersistentManifestLoader.shared.getCacheSize(for: cacheID)
                                if size > 0 {
                                    await MainActor.run { [weak self] in
                                        self?.updateHistoryItemSize(url: itemURL, size: size)
                                    }
                                }
                            }
                        }
                        return WebPageHistorySectionItem(history: history, cacheType: favorite.cacheType)
                    }

                var grouped: [String: [WebPageHistorySectionItem]] = [:]
                for item in allItems {
                    let type = item.cacheType.isEmpty ? "live" : item.cacheType
                    grouped[type, default: []].append(item)
                }

                var sections: [WebPageHistorySection] = []
                for type in cacheTypeOrder {
                    guard let items = grouped[type], !items.isEmpty else { continue }
                    let header = cacheTypeHeaders[type] ?? type
                    sections.append(WebPageHistorySection(header: header, items: items, cacheType: type))
                }

                let histories = historyResults.prefix(100)
                    .filter { !favoriteURLs.contains($0.url) }
                    .prefix(20)
                    .map { history -> WebPageHistorySectionItem in
                        let displayHistory = WebPageHistory()
                        displayHistory.id = history.id
                        displayHistory.url = history.url
                        displayHistory.title = history.title
                        displayHistory.favicon = history.favicon
                        displayHistory.visitCount = history.visitCount
                        displayHistory.lastVisitDate = history.lastVisitDate
                        displayHistory.isFavorite = false
                        displayHistory.isPinned = false

                        if let url = URL(string: history.url) {
                            let cacheID = url.host ?? url.lastPathComponent
                            displayHistory.cachedSize = history.cachedSize
                            displayHistory.isCached = history.isCached

                            Task.detached {
                                let size = PersistentManifestLoader.shared.getCacheSize(for: cacheID)
                                if size > 0 {
                                    await MainActor.run { [weak self] in
                                        self?.updateHistoryItemSize(url: history.url, size: size)
                                    }
                                }
                            }
                        }
                        return WebPageHistorySectionItem(history: displayHistory, cacheType: "live")
                    }

                if !histories.isEmpty {
                    let recentSection = WebPageHistorySection(
                        header: L10n.tr("home.section.recent_visits"),
                        items: Array(histories),
                        cacheType: "live"
                    )
                    let hasLiveSection = sections.contains { $0.cacheType == "live" }
                    if hasLiveSection, let idx = sections.firstIndex(where: { $0.cacheType == "live" }) {
                        sections[idx] = WebPageHistorySection(
                            header: sections[idx].header,
                            items: sections[idx].items + histories,
                            cacheType: "live"
                        )
                    } else {
                        sections.append(recentSection)
                    }
                }

                Task.detached { [weak self] in
                    let totalBytes = PersistentManifestLoader.shared.getCacheSize()
                    let formattedTotalSize = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
                    await MainActor.run {
                        self?.totalStorageSizeRelay.accept(formattedTotalSize)
                    }
                }

                self.historiesRelay.accept(sections)
                self.isEmptyRelay.accept(sections.allSatisfy { $0.items.isEmpty })
                self.loadingRelay.accept(false)
                Log.info("loadHistories completed, sections: \(sections.count)", category: .ui)
            }
        }
    }

    /// 异步更新历史记录项的缓存大小
    /// - Parameters:
    ///   - url: 项目 URL
    ///   - size: 缓存大小
    private func updateHistoryItemSize(url: String, size: Int64) {
        var currentSections = historiesRelay.value
        var updated = false

        for (sIndex, section) in currentSections.enumerated() {
            var items = section.items
            for (iIndex, item) in items.enumerated() where item.history.url == url {
                let updatedHistory = item.history
                updatedHistory.cachedSize = size
                updatedHistory.isCached = size > 0
                items[iIndex] = WebPageHistorySectionItem(history: updatedHistory, cacheType: item.cacheType)
                updated = true
            }
            if updated {
                currentSections[sIndex] = WebPageHistorySection(header: section.header, items: items, cacheType: section.cacheType)
                break
            }
        }

        if updated {
            historiesRelay.accept(currentSections)
        }
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

struct WebPageHistorySectionItem {
    let history: WebPageHistory
    let cacheType: String
}

struct WebPageHistorySection {
    let header: String
    let items: [WebPageHistorySectionItem]
    let cacheType: String
}
