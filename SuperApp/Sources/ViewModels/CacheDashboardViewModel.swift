//
//  CacheDashboardViewModel.swift
//  SuperApp
//
//  Created on 2026-05-11.
//  Copyright © 2026年 WebBridgeKit. All rights reserved.
//
//  ⚠️ CRITICAL: All Rx Observable element types must be built-in Swift types
//  (Void, Int, Bool, String). Using types from WebBridgeKit framework as Rx
//  generic parameters causes Swift runtime metadata crash (AnonymousObservableSink,
//  MapSink, SubscribeOnSink, CatchSink etc.). All WebBridgeKit types are handled
//  via BehaviorRelay internal storage or manual callbacks, never as Rx element types.
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
        /// Index into cached subsystem list (Int is safe for Rx generics)
        let selectSubsystemAt: Observable<Int>
        let tapClearAll: Observable<Void>
        let tapPinnedManage: Observable<Void>
        let tapPresetCatalog: Observable<Void>
    }

    // MARK: - Output
    // ⚠️ All Rx element types must be built-in Swift types (Void, Int, Bool, String)
    // Using WebBridgeKit framework types as Rx generics causes Swift runtime crash.

    struct Output {
        /// Signals when dashboard data is updated. Read via `currentDashboardData` property.
        let didUpdateData: Driver<Void>
        let isLoading: Driver<Bool>
        let subsystemSections: Driver<[SectionModel<String, SubsystemStatItemModel>]>
        let summaryText: Driver<String>
        let error: Driver<String?>
        /// Navigate to detail - emits SubsystemID.rawValue (String is safe for Rx)
        let navigateToDetail: Driver<String>
        let showClearAllConfirm: Driver<Void>
        let clearResult: Driver<Bool>
    }

    /// Thread-safe access to current dashboard data (WebBridgeKit type stored internally, not via Rx)
    private var _currentData: DashboardData?
    var currentDashboardData: DashboardData? {
        lock.lock(); defer { lock.unlock() }
        return _currentData
    }
    private let lock = NSLock()

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

    // MARK: - Private Relays (all use safe built-in types only)
    // WebBridgeKit types are stored as plain properties, NOT as Rx element types.

    private let loadingRelay = BehaviorRelay<Bool>(value: false)
    private let errorRelay = BehaviorRelay<String?>(value: nil)
    private let didUpdateRelay = PublishRelay<Void>()
    private let navigateDetailRelay = BehaviorRelay<String?>(value: nil)
    private let showClearConfirmRelay = PublishRelay<Void>()
    private let clearResultRelay = BehaviorRelay<Bool>(value: false)

    /// Cached subsystem list for index-based lookup
    private var cachedSubsystems: [SubsystemStats] = []

    // MARK: - Transform

    func transform(input: Input) -> Output {
        // Safe: Void is a built-in type
        input.refresh
            .subscribe(onNext: { [weak self] in
                self?.loadData()
            })
            .disposed(by: rx)

        // Safe: Int is a built-in type
        input.selectSubsystemAt
            .subscribe(onNext: { [weak self] index in
                guard let self, index >= 0, index < self.cachedSubsystems.count else { return }
                let stats = self.cachedSubsystems[index]
                self.navigateDetailRelay.accept(stats.id.rawValue)
            })
            .disposed(by: rx)

        // Safe: Void is a built-in type
        input.tapClearAll
            .subscribe(onNext: { [weak self] in
                self?.showClearConfirmRelay.accept(())
            })
            .disposed(by: rx)

        // MARK: - Output drivers (all use built-in types)

        let sectionsDriver = didUpdateRelay
            .compactMap { [weak self] _ -> [SectionModel<String, SubsystemStatItemModel>]? in
                guard let self, let data = self.currentDashboardData, !data.subsystems.isEmpty else { return [] }
                self.cachedSubsystems = data.subsystems

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

        let summaryDriver = didUpdateRelay
            .compactMap { [weak self] _ -> String? in
                guard let self, let data = self.currentDashboardData else { return nil }
                let active = data.activeSubsystemCount
                return "总计 \(data.formattedTotalSize) | \(data.totalEntries) 条目 | \(active)/\(data.subsystems.count) 子系统活跃"
            }
            .asDriver(onErrorJustReturn: "")

        return Output(
            didUpdateData: didUpdateRelay.asDriver(onErrorJustReturn: ()),
            isLoading: loadingRelay.asDriver(),
            subsystemSections: sectionsDriver,
            summaryText: summaryDriver,
            error: errorRelay.asDriver(onErrorJustReturn: ""),
            navigateToDetail: navigateDetailRelay.compactMap { $0 }.asDriver(onErrorJustReturn: ""),
            showClearAllConfirm: showClearConfirmRelay.asDriver(onErrorJustReturn: ()),
            clearResult: clearResultRelay.asDriver()
        )
    }

    // MARK: - Data Loading

    private func loadData() {
        loadingRelay.accept(true)
        errorRelay.accept(nil)

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let data = CacheStatsAggregator.shared.syncAggregate()
            DispatchQueue.main.async {
                self.lock.lock()
                self._currentData = data
                self.lock.unlock()
                self.didUpdateRelay.accept(())
                self.loadingRelay.accept(false)
            }
        }
    }
}
