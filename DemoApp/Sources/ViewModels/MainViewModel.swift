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

    private let historyManager: WebPageHistoryManager
    private let favoriteManager: URLFavoriteManager

    private let historiesRelay = BehaviorRelay<[WebPageHistorySection]>(value: [])
    private let isEmptyRelay = BehaviorRelay<Bool>(value: true)
    private let openURLRelay = PublishRelay<URL>()
    private let showActionSheetRelay = PublishRelay<URL>()
    private let showScannerRelay = PublishRelay<Void>()
    private let loadingRelay = BehaviorRelay<Bool>(value: false)

    // MARK: - Initialization

    override init() {
        self.historyManager = WebPageHistoryManager.shared
        self.favoriteManager = URLFavoriteManager.shared
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
            .compactMap { $0.url }
            .filter { $0 != "" }
            .compactMap { URL(string: $0) }
            .do(onNext: { [weak self] url in
                self?.openURLRelay.accept(url)
                // 增加访问计数
                self?.historyManager.addOrUpdateHistory(url: url)
            })
            .drive()
            .disposed(by: rx)

        // 长按项目
        input.itemLongPress
            .withLatestFrom(historiesRelay.asDriver()) { indexPath, sections in
                return sections[indexPath.section].items[indexPath.item]
            }
            .compactMap { history -> URL? in
                guard let url = URL(string: history.url) else { return nil }
                return url
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

    private func loadHistories() {
        // 获取最近访问的历史记录（最多显示 50 个）
        let histories = Array(historyManager.getAllHistories().prefix(50))

        let sections = [WebPageHistorySection(
            header: "最近访问",
            items: histories
        )]

        historiesRelay.accept(sections)
        isEmptyRelay.accept(histories.isEmpty)
        loadingRelay.accept(false)
    }

    func addToFavorites(url: URL) {
        favoriteManager.addFavorite(url: url, title: url.host)
    }

    func togglePin(url: URL) {
        guard let favorite = favoriteManager.findFavorite(url: url) else { return }
        favoriteManager.togglePin(id: favorite.id)
    }

    func deleteHistory(url: URL) {
        guard let history = historyManager.findHistory(url: url) else { return }
        historyManager.deleteHistory(id: history.id)
        loadHistories()
    }
}

// MARK: - Section Model

struct WebPageHistorySection {
    let header: String
    let items: [WebPageHistory]
}
