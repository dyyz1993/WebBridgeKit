//
//  FavoriteViewModel.swift
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

/// 收藏管理 ViewModel
class FavoriteViewModel: ViewModel {

    // MARK: - Input & Output

    struct Input {
        let refresh: Driver<Void>
        let itemSelect: Driver<IndexPath>
        let pinToggle: Driver<String>
        let cacheModeToggle: Driver<(String, Bool)>
        let itemDelete: Driver<String>
    }

    struct Output {
        let favorites: Driver<[URLFavoriteSection]>
        let isEmpty: Driver<Bool>
        let openURL: Driver<URL>
        let loading: Driver<Bool>
    }

    // MARK: - Properties

    private let favoriteService: FavoriteServiceProtocol
    private let favoritesRelay = BehaviorRelay<[URLFavoriteSection]>(value: [])
    private let isEmptyRelay = BehaviorRelay<Bool>(value: true)
    private let openURLRelay = PublishRelay<URL>()
    private let loadingRelay = BehaviorRelay<Bool>(value: false)

    private var currentFavorites: [URLFavorite] = []

    // MARK: - Initialization

    /// 指定初始化方法，支持依赖注入
    /// - Parameter favoriteService: 收藏服务，默认使用 ServiceLocator 提供
    init(favoriteService: FavoriteServiceProtocol = ServiceLocator.favorite) {
        self.favoriteService = favoriteService
        super.init()
    }

    // MARK: - Transform

    func transform(input: Input) -> Output {
        // 刷新数据
        input.refresh
            .do(onNext: { [weak self] in
                self?.loadingRelay.accept(true)
                self?.loadFavorites()
            })
            .drive()
            .disposed(by: rx)

        // 点击项目
        input.itemSelect
            .withLatestFrom(favoritesRelay.asDriver(onErrorJustReturn: [])) { indexPath, sections in
                return sections[indexPath.section].items[indexPath.item]
            }
            .compactMap { favorite -> URL? in
                return URL(string: favorite.url)
            }
            .do(onNext: { [weak self] url in
                self?.openURLRelay.accept(url)
            })
            .drive()
            .disposed(by: rx)

        // 切换置顶
        input.pinToggle
            .do(onNext: { [weak self] id in
                self?.favoriteService.togglePin(id: id)
                self?.loadFavorites()
            })
            .drive()
            .disposed(by: rx)

        // 切换缓存模式
        input.cacheModeToggle
            .do(onNext: { [weak self] args in
                let (id, enabled) = args
                self?.favoriteService.updateCacheMode(id: id, enabled: enabled)
                self?.loadFavorites()
            })
            .drive()
            .disposed(by: rx)

        // 删除项目
        input.itemDelete
            .do(onNext: { [weak self] id in
                self?.favoriteService.deleteFavorite(id: id)
                self?.loadFavorites()
            })
            .drive()
            .disposed(by: rx)

        // 初始加载数据
        loadFavorites()

        return Output(
            favorites: favoritesRelay.asDriver(onErrorJustReturn: []),
            isEmpty: isEmptyRelay.asDriver(onErrorJustReturn: true),
            openURL: openURLRelay.asDriver(onErrorJustReturn: URL(string: "https://example.com")!),
            loading: loadingRelay.asDriver(onErrorJustReturn: false)
        )
    }

    // MARK: - Private Methods

    private func loadFavorites() {
        let results = favoriteService.getAllFavorites()
        currentFavorites = Array(results)

        // 分组：置顶的和普通的
        let pinnedFavorites = currentFavorites.filter { $0.isPinned }
        let normalFavorites = currentFavorites.filter { !$0.isPinned }

        var sections: [URLFavoriteSection] = []

        if !pinnedFavorites.isEmpty {
            sections.append(URLFavoriteSection(
                header: "置顶收藏",
                items: pinnedFavorites
            ))
        }

        if !normalFavorites.isEmpty {
            sections.append(URLFavoriteSection(
                header: "收藏",
                items: normalFavorites
            ))
        }

        favoritesRelay.accept(sections)
        isEmptyRelay.accept(currentFavorites.isEmpty)
        loadingRelay.accept(false)
    }

    // MARK: - Public Methods

    /// 更新排序
    func updateSortOrder(sourceIndexPath: IndexPath, destinationIndexPath: IndexPath) {
        guard sourceIndexPath.section == destinationIndexPath.section else {
            return // 不支持跨 section 拖拽
        }

        let sections = favoritesRelay.value
        var items = sections[sourceIndexPath.section].items

        let movedItem = items.remove(at: sourceIndexPath.item)
        items.insert(movedItem, at: destinationIndexPath.item)

        // 更新所有项目的 sortOrder
        for (index, item) in items.enumerated() {
            item.sortOrder = index
        }

        favoriteService.updateSortOrder(favorites: items)
        loadFavorites()
    }
}

// MARK: - Section Model

struct URLFavoriteSection {
    let header: String
    let items: [URLFavorite]
}
