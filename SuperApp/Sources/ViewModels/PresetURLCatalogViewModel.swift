//
//  PresetURLCatalogViewModel.swift
//  SuperApp
//
//  Created on 2026-05-11.
//  Copyright © 2026年 WebBridgeKit. All rights reserved.
//

import Foundation
import RxCocoa
import RxDataSources
import RxSwift
import WebBridgeKit

/// 预设 URL 目录 ViewModel
class PresetURLCatalogViewModel: ViewModel {

    // MARK: - Input

    struct Input {
        let selectCategory: Observable<PresetCategory?>
        let searchQuery: Observable<String>
        let pinTapped: Observable<PresetURLItemModel>
        let showRecommendedOnly: Observable<Bool>
    }

    // MARK: - Output

    struct Output {
        let categories: Driver<[PresetCategoryItem]>
        let items: Driver<[PresetURLItemModel]>
        let selectedCategory: Driver<PresetCategory?>
        let isEmpty: Driver<Bool>
        let pinResult: Driver<(item: PresetURLItem, success: Bool)>
        let totalAvailable: Driver<Int>
    }

    // MARK: - Category Item

    struct PresetCategoryItem: Equatable {
        let category: PresetCategory?
        let displayName: String
        let iconName: String
        let count: Int
        let isSelected: Bool
    }

    // MARK: - Item Model

    struct PresetURLItemModel: IdentifiableType, Equatable {
        var identity: String { id }
        let id: String
        let url: String
        let title: String
        let description: String
        let categoryDisplayName: String
        let urlTypeDisplayName: String
        let urlTypeIconName: String
        let tags: [String]
        let isRecommended: Bool
        let isAlreadyPinned: Bool

        init(from item: PresetURLItem, isPinned: Bool = false) {
            self.id = item.id
            self.url = item.url
            self.title = item.title
            self.description = item.description
            self.categoryDisplayName = item.category.displayName
            self.urlTypeDisplayName = item.urlType.displayName
            self.urlTypeIconName = item.urlType.iconName
            self.tags = item.tags
            self.isRecommended = item.isRecommended
            self.isAlreadyPinned = isPinned
        }
    }

    // MARK: - Private

    private let selectedCategoryRelay = BehaviorRelay<PresetCategory?>(value: nil)
    private let pinResultRelay = BehaviorRelay<(PresetURLItem, Bool)?>(value: nil)
    private var existingPinnedURLs: Set<String> = []

    // MARK: - Transform

    func transform(input: Input) -> Output {
        input.selectCategory
            .bind(to: selectedCategoryRelay)
            .disposed(by: rx)

        Observable.just(())
            .flatMap { Observable.from(optional: try? PinnedURLManager.shared.getAllPinnedSync() ?? []) }
            .map { $0.map(\.url) }
            .subscribe(onNext: { [weak self] urls in
                self?.existingPinnedURLs = Set(urls)
            })
            .disposed(by: rx)

        input.pinTapped
            .map { [weak self] model -> (PresetURLItem, Bool) in
                guard let self else { return (PresetURLItem(id: "", url: "", title: "", description: "", category: .htmlPages, tags: [], isRecommended: false), false) }
                let item = PresetURLItem(id: model.id, url: model.url, title: model.title, description: model.description, category: PresetCategory.htmlPages, tags: model.tags, isRecommended: model.isRecommended)
                if let _ = PinnedURLManager.shared.addSync(url: item.url, title: item.title, notes: item.description) {
                    self.existingPinnedURLs.insert(item.url)
                    return (item, true)
                }
                return (item, false)
            }
            .bind(to: pinResultRelay)
            .disposed(by: rx)

        let categories = selectedCategoryRelay
            .flatMapLatest { selected -> Observable<[PresetCategoryItem]> in
                let byCat = PresetURLCatalog.itemsByCategory

                var cats: [PresetCategoryItem] = [
                    PresetCategoryItem(
                        category: nil,
                        displayName: "全部",
                        iconName: "layout-grid",
                        count: PresetURLCatalog.allItems.count,
                        isSelected: selected == nil
                    )
                ]

                let sortedCategories = PresetCategory.allCases.sorted { $0.sortPriority < $1.sortPriority }
                for cat in sortedCategories {
                    let count = byCat[cat]?.count ?? 0
                    cats.append(PresetCategoryItem(
                        category: cat,
                        displayName: cat.displayName,
                        iconName: cat.iconName,
                        count: count,
                        isSelected: selected == cat
                    ))
                }

                return .just(cats)
            }
            .asDriver(onErrorJustReturn: [])

        let items = Observable.combineLatest(
            selectedCategoryRelay.asObservable(),
            input.searchQuery.startWith(""),
            input.showRecommendedOnly.startWith(false),
            pinResultRelay.asObservable().startWith(nil).map { _ in () }
        ) { [weak self] category, query, recommendedOnly, _ -> [PresetURLItemModel] in
            guard let self else { return [] }
            var source = PresetURLCatalog.allItems

            if let c = category {
                source = source.filter { $0.category == c }
            }

            let q = query.lowercased().trimmingCharacters(in: .whitespaces)
            if !q.isEmpty {
                source = PresetURLCatalog.search(q)
                if let c = category {
                    source = source.filter { $0.category == c }
                }
            }

            if recommendedOnly {
                source = source.filter { $0.isRecommended }
            }

            return source.map { PresetURLItemModel(from: $0, isPinned: self.existingPinnedURLs.contains($0.url)) }
        }
        .asDriver(onErrorJustReturn: [])

        return Output(
            categories: categories,
            items: items,
            selectedCategory: selectedCategoryRelay.asDriver(),
            isEmpty: items.map(\.isEmpty),
            pinResult: pinResultRelay.compactMap { $0 }.asDriver(onErrorJustReturn: (PresetURLItem(id: "", url: "", title: "", description: "", category: .htmlPages, tags: [], isRecommended: false), false)),
            totalAvailable: .just(PresetURLCatalog.allItems.count).asDriver()
        )
    }
}
