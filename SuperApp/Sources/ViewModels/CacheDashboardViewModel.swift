//
//  CacheDashboardViewModel.swift
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

/// 缓存仪表盘 ViewModel
class CacheDashboardViewModel: ViewModel {

    // MARK: - Input

    struct Input {
        let refresh: Observable<Void>
        let selectSubsystem: Observable<SubsystemStats>
        let tapClearAll: Observable<Void>
        let tapPinnedManage: Observable<Void>
        let tapPresetCatalog: Observable<Void>
    }

    // MARK: - Output

    struct Output {
        let dashboardData: Driver<DashboardData>
        let isLoading: Driver<Bool>
        let subsystemSections: Driver<[SectionModel<String, SubsystemStatItemModel>]>
        let summaryText: Driver<String>
        let error: Driver<String?>
        let navigateToDetail: Driver<SubsystemID>
        let showClearAllConfirm: Driver<Void>
        let clearResult: Driver<Bool>
    }

    // MARK: - Data Model for Cell

    struct SubsystemStatItemModel: IdentifiableType, Equatable {
        var identity: String { id.rawValue }
        let id: SubsystemID
        let name: String
        let nameZh: String
        let iconName: String
        let entries: String
        let size: String
        let hitRate: String?
        let statusText: String
        let statusColorName: String
        let hasData: Bool

        init(from stats: SubsystemStats) {
            self.id = stats.id
            self.name = stats.id.name
            self.nameZh = stats.id.nameZh
            self.iconName = stats.id.iconName
            self.entries = "\(stats.totalEntries)"
            self.size = stats.formattedSize
            self.hitRate = stats.formattedHitRate
            self.statusText = stats.status.displayText
            self.statusColorName = stats.status.statusColorName
            self.hasData = stats.hasData
        }
    }

    // MARK: - Private

    private let loadingRelay = BehaviorRelay<Bool>(value: false)
    private let errorRelay = BehaviorRelay<String?>(value: nil)
    private let dataRelay = BehaviorRelay<DashboardData?>(value: nil)
    private let navigateDetailRelay = BehaviorRelay<SubsystemID?>(value: nil)
    private let showClearConfirmRelay = PublishRelay<Void>()
    private let clearResultRelay = BehaviorRelay<Bool>(value: false)

    // MARK: - Transform

    func transform(input: Input) -> Output {
        let initialLoad = Observable.just(())
        let refreshTrigger = Observable.merge(initialLoad, input.refresh)

        refreshTrigger
            .do(onNext: { [weak self] _ in
                self?.loadingRelay.accept(true)
                self?.errorRelay.accept(nil)
            })
            .flatMapLatest { [weak self] () -> Observable<DashboardData> in
                guard self != nil else { return .empty() }
                return CacheStatsAggregator.shared.aggregate()
                    .catch { [weak self] error in
                        self?.errorRelay.accept(error.localizedDescription)
                        return Observable.just(DashboardData())
                    }
            }
            .observe(on: MainScheduler.instance)
            .do(onNext: { [weak self] _ in
                self?.loadingRelay.accept(false)
            })
            .bind(to: dataRelay)
            .disposed(by: rx)

        input.selectSubsystem
            .map { $0.id }
            .bind(to: navigateDetailRelay)
            .disposed(by: rx)

        input.tapClearAll
            .bind(to: showClearConfirmRelay)
            .disposed(by: rx)

        let dashboardDriver = dataRelay
            .compactMap { $0 }
            .asDriver(onErrorJustReturn: DashboardData())

        let sectionsDriver = dataRelay
            .compactMap { [weak self] data -> [SectionModel<String, SubsystemStatItemModel>] in
                guard let data, !data.subsystems.isEmpty else { return [] }

                let activeItems = data.subsystems
                    .filter { $0.hasData || $0.status == .active }
                    .map { SubsystemStatItemModel(from: $0) }

                let inactiveItems = data.subsystems
                    .filter { !$0.hasData && $0.status != .active }
                    .map { SubsystemStatItemModel(from: $0) }

                var sections: [SectionModel<String, SubsystemStatItemModel>] = []

                if !activeItems.isEmpty {
                    sections.append(SectionModel(model: "🟢 活跃", items: activeItems))
                }
                if !inactiveItems.isEmpty {
                    sections.append(SectionModel(model: "⚪ 空闲", items: inactiveItems))
                }

                return sections
            }
            .asDriver(onErrorJustReturn: [])

        let summaryDriver = dataRelay
            .compactMap { data -> String? in
                guard let data else { return nil }
                let active = data.activeSubsystemCount
                return "总计 \(data.formattedTotalSize) | \(data.totalEntries) 条目 | \(active)/\(data.subsystems.count) 子系统活跃"
            }
            .asDriver(onErrorJustReturn: "")

        return Output(
            dashboardData: dashboardDriver,
            isLoading: loadingRelay.asDriver(),
            subsystemSections: sectionsDriver,
            summaryText: summaryDriver,
            error: errorRelay.asDriver(onErrorJustReturn: ""),
            navigateToDetail: navigateDetailRelay.compactMap { $0 }.asDriver(onErrorJustReturn: .manifestCache),
            showClearAllConfirm: showClearConfirmRelay.asDriver(onErrorJustReturn: ()),
            clearResult: clearResultRelay.asDriver()
        )
    }
}
