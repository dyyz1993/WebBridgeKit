//
//  WebPageHistoryViewModel.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-15.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import RxCocoa
import RxSwift
import RxDataSources

// Framework imports

/// 视图模式
enum ViewMode {
    case list
    case gallery
}

/// 历史记录Section
typealias WebPageHistorySection = AnimatableSectionModel<String, WebPageHistory>

/// 历史记录ViewModel
class WebPageHistoryViewModel: ViewModel {
    let disposeBag = DisposeBag()

    // MARK: - Input

    struct Input {
        let refresh: Driver<Void>
        let itemSelect: Driver<WebPageHistory>
        let itemDelete: Driver<WebPageHistory>
        let searchText: Observable<String?>
        let viewModeToggle: Driver<Void>
        let cacheRequest: Driver<WebPageHistory>
        let deleteCacheRequest: Driver<WebPageHistory>
        let qrScan: Driver<Void>
    }

    // MARK: - Output

    struct Output {
        let histories: Driver<[WebPageHistorySection]>
        let title: Driver<String>
        let isEmpty: Driver<Bool>
        let openURL: Driver<URL>
        let cacheProgress: Driver<Double>
        let cacheSuccess: Driver<Void>
        let cacheError: Driver<String>
        let showScanner: Driver<Void>
    }

    // MARK: - Properties

    private let historyRelay = BehaviorRelay<[WebPageHistorySection]>(value: [])
    private let viewModeRelay = BehaviorRelay<ViewMode>(value: .list)
    private let cacheProgressRelay = BehaviorRelay<Double>(value: 0)
    private let cacheSuccessRelay = PublishRelay<Void>()
    private let cacheErrorRelay = PublishRelay<String>()
    private let openURLRelay = PublishRelay<URL>()
    private let showScannerRelay = PublishRelay<Void>()

    // MARK: - Transform

    func transform(input: Input) -> Output {
        // 刷新时重新加载数据
        input.refresh
            .drive(onNext: { [weak self] in
                self?.loadHistories()
            })
            .disposed(by: disposeBag)

        // 搜索过滤
        input.searchText
            .subscribe(onNext: { [weak self] text in
                self?.filterHistories(keyword: text ?? "")
            })
            .disposed(by: disposeBag)

        // 视图模式切换
        input.viewModeToggle
            .drive(onNext: { [weak self] in
                self?.toggleViewMode()
            })
            .disposed(by: disposeBag)

        // 选中历史记录
        input.itemSelect
            .drive(onNext: { [weak self] history in
                self?.openHistory(history)
            })
            .disposed(by: disposeBag)

        // 删除历史记录
        input.itemDelete
            .drive(onNext: { [weak self] history in
                WebPageHistoryManager.shared.deleteHistory(id: history.id)
                self?.loadHistories()
            })
            .disposed(by: disposeBag)

        // 缓存请求
        input.cacheRequest
            .drive(onNext: { [weak self] history in
                self?.cachePage(history)
            })
            .disposed(by: disposeBag)

        // 删除缓存请求
        input.deleteCacheRequest
            .drive(onNext: { history in
                WebPageOfflineCacheManager.shared.deleteCache(history: history)
            })
            .disposed(by: disposeBag)

        // 二维码扫描
        input.qrScan
            .drive(onNext: { [weak self] in
                self?.showScannerRelay.accept(())
            })
            .disposed(by: disposeBag)

        // 初始加载
        loadHistories()

        return Output(
            histories: historyRelay.asDriver(),
            title: Driver.just(NSLocalizedString("History", comment: "History")),
            isEmpty: historyRelay.map({ (sections: [WebPageHistorySection]) in sections.isEmpty || sections.first?.items.isEmpty ?? true }).asDriver(onErrorJustReturn: false),
            openURL: openURLRelay.asDriver(onErrorDriveWith: .empty()),
            cacheProgress: cacheProgressRelay.asDriver(),
            cacheSuccess: cacheSuccessRelay.asDriver(onErrorDriveWith: .empty()),
            cacheError: cacheErrorRelay.asDriver(onErrorDriveWith: .empty()),
            showScanner: showScannerRelay.asDriver(onErrorDriveWith: .empty())
        )
    }

    // MARK: - Private Methods

    private func toggleViewMode() {
        let newMode: ViewMode = viewModeRelay.value == .list ? .gallery : .list
        viewModeRelay.accept(newMode)
    }

    func loadHistories() {
        // 确保在主线程执行
        if Thread.isMainThread {
            performLoadHistories()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.performLoadHistories()
            }
        }
    }

    private func performLoadHistories() {
        let histories = WebPageHistoryManager.shared.getAllHistories()

        // 按日期分组
        let grouped = Dictionary(grouping: histories) { history in
            formatSectionDate(history.lastVisitDate)
        }

        let sortedKeys = grouped.keys.sorted(by: >)

        let sections: [WebPageHistorySection] = sortedKeys.map { key in
            let items = grouped[key]?.sorted(by: { $0.lastVisitDate > $1.lastVisitDate }) ?? []
            return WebPageHistorySection(model: key, items: items)
        }

        historyRelay.accept(sections)
    }

    private func filterHistories(keyword: String) {
        if keyword.isEmpty {
            loadHistories()
            return
        }

        let filtered = WebPageHistoryManager.shared.searchHistories(keyword: keyword)

        let grouped = Dictionary(grouping: filtered) { history in
            formatSectionDate(history.lastVisitDate)
        }

        let sortedKeys = grouped.keys.sorted(by: >)

        let sections: [WebPageHistorySection] = sortedKeys.map { key in
            let items = grouped[key] ?? []
            return WebPageHistorySection(model: key, items: items)
        }

        historyRelay.accept(sections)
    }

    private func openHistory(_ history: WebPageHistory) {
        guard let url = URL(string: history.url) else { return }

        // 更新访问次数
        WebPageHistoryManager.shared.addOrUpdateHistory(url: url, title: history.title, favicon: history.favicon)

        // 触发打开URL
        openURLRelay.accept(url)
    }

    private func cachePage(_ history: WebPageHistory) {
        WebPageOfflineCacheManager.shared.cachePage(history: history) { [weak self] progress in
            self?.cacheProgressRelay.accept(progress)
        } completion: { [weak self] result in
            switch result {
            case .success:
                self?.cacheSuccessRelay.accept(())
                self?.loadHistories()
            case .failure(let error):
                self?.cacheErrorRelay.accept(error.localizedDescription)
            }
        }
    }

    private func formatSectionDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return NSLocalizedString("Today", comment: "")
        } else if calendar.isDateInYesterday(date) {
            return NSLocalizedString("Yesterday", comment: "")
        } else if calendar.dateInterval(of: .weekOfYear, for: now)?.contains(date) ?? false {
            let daysAgo = calendar.dateComponents([.day], from: date, to: now).day ?? 0
            return String(format: NSLocalizedString("%d days ago", comment: ""), daysAgo)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.locale = Locale.current
            return formatter.string(from: date)
        }
    }
}
