//
//  WebAccessViewModel.swift
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

/// URL 访问页面 ViewModel
class WebAccessViewModel: ViewModel {

    // MARK: - Input & Output

    struct Input {
        let loadURL: Driver<URL>
        let cacheButtonTap: Driver<Void>
        let cacheModeToggle: Driver<Bool>
        let cacheCountTap: Driver<Void>
    }

    struct Output {
        let title: Driver<String?>
        let url: Driver<URL?>
        let canCache: Driver<Bool>
        let isCached: Driver<Bool>
        let cacheProgress: Driver<Double>
        let cacheCount: Driver<String>
        let showCacheResources: Driver<Void>
        let loading: Driver<Bool>
        let errorMessage: Driver<String?>
    }

    // MARK: - Properties

    private let historyManager: WebPageHistoryManager
    private let cacheManager: WebPageOfflineCacheManager

    private let titleRelay = BehaviorRelay<String?>(value: nil)
    private let urlRelay = BehaviorRelay<URL?>(value: nil)
    private let canCacheRelay = BehaviorRelay<Bool>(value: false)
    private let isCachedRelay = BehaviorRelay<Bool>(value: false)
    private let cacheProgressRelay = BehaviorRelay<Double>(value: 0)
    private let cacheCountRelay = BehaviorRelay<String>(value: "0 个资源")
    private let showCacheResourcesRelay = PublishRelay<Void>()
    private let loadingRelay = BehaviorRelay<Bool>(value: false)
    private let errorMessageRelay = PublishRelay<String?>()

    private var currentURL: URL?
    private var currentHistory: WebPageHistory?
    private var isCacheModeEnabled: Bool = false
    private var isPageLoading: Bool = false

    // MARK: - Initialization

    override init() {
        self.historyManager = WebPageHistoryManager.shared
        self.cacheManager = WebPageOfflineCacheManager.shared
        super.init()
    }

    // MARK: - Transform

    func transform(input: Input) -> Output {
        // 加载 URL
        input.loadURL
            .do(onNext: { [weak self] url in
                self?.currentURL = url
                self?.urlRelay.accept(url)
                self?.loadingRelay.accept(true)
                self?.updateURLInfo(url: url)
            })
            .drive()
            .disposed(by: rx)

        // 缓存按钮点击
        input.cacheButtonTap
            .filter { [weak self] in
                guard let self = self, self.currentURL != nil else {
                    return false
                }
                return true
            }
            .do(onNext: { [weak self] in
                self?.handleCacheButtonTap()
            })
            .drive()
            .disposed(by: rx)

        // 缓存模式切换
        input.cacheModeToggle
            .do(onNext: { [weak self] isEnabled in
                self?.handleCacheModeToggle(isEnabled)
            })
            .drive()
            .disposed(by: rx)

        // 缓存数量点击
        input.cacheCountTap
            .filter { [weak self] in
                guard let self = self, self.currentHistory != nil else {
                    return false
                }
                return true
            }
            .do(onNext: { [weak self] in
                self?.showCacheResourcesRelay.accept(())
            })
            .drive()
            .disposed(by: rx)

        return Output(
            title: titleRelay.asDriver(onErrorJustReturn: nil),
            url: urlRelay.asDriver(onErrorJustReturn: nil),
            canCache: canCacheRelay.asDriver(onErrorJustReturn: false),
            isCached: isCachedRelay.asDriver(onErrorJustReturn: false),
            cacheProgress: cacheProgressRelay.asDriver(onErrorJustReturn: 0),
            cacheCount: cacheCountRelay.asDriver(onErrorJustReturn: ""),
            showCacheResources: showCacheResourcesRelay.asDriver(onErrorJustReturn: ()),
            loading: loadingRelay.asDriver(onErrorJustReturn: false),
            errorMessage: errorMessageRelay.asDriver(onErrorJustReturn: nil)
        )
    }

    // MARK: - Private Methods

    private func updateURLInfo(url: URL) {
        // 查找或创建历史记录
        if let history = historyManager.findHistory(url: url) {
            currentHistory = history
            titleRelay.accept(history.title ?? url.host)

            // 更新缓存状态
            isCachedRelay.accept(history.isCached)

            if history.isCached {
                // 已缓存，显示资源数量
                let count = history.resourcePaths.count
                cacheCountRelay.accept("\(count) 个资源")
                canCacheRelay.accept(false)
            } else {
                // 未缓存，可以缓存
                cacheCountRelay.accept("未缓存")
                canCacheRelay.accept(true)
            }

            loadingRelay.accept(false)
        } else {
            // 新 URL，需要先创建历史记录
            historyManager.addOrUpdateHistory(url: url, title: url.host)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.updateURLInfo(url: url)
            }
        }
    }

    private func handleCacheButtonTap() {
        guard let url = currentURL,
              let history = currentHistory else {
            errorMessageRelay.accept("无法缓存该页面")
            return
        }

        if history.isCached {
            // 已缓存，删除缓存
            cacheManager.deleteCache(history: history)
            isCachedRelay.accept(false)
            cacheCountRelay.accept("未缓存")
            canCacheRelay.accept(true)
        } else {
            // 未缓存，开始缓存
            loadingRelay.accept(true)
            canCacheRelay.accept(false)
            cacheProgressRelay.accept(0)

            cacheManager.cachePage(history: history, progress: { [weak self] progress in
                self?.cacheProgressRelay.accept(progress)
            }, completion: { [weak self] result in
                self?.loadingRelay.accept(false)

                switch result {
                case .success:
                    self?.isCachedRelay.accept(true)
                    self?.updateURLInfo(url: url)
                case .failure(let error):
                    self?.errorMessageRelay.accept("缓存失败: \(error.localizedDescription)")
                    self?.canCacheRelay.accept(true)
                }
            })
        }
    }

    private func handleCacheModeToggle(_ isEnabled: Bool) {
        // 处理缓存模式切换
        isCacheModeEnabled = isEnabled

        if isEnabled {
            // 开启自动缓存模式
            // 如果当前页面已加载完成且未缓存，立即开始缓存
            if !isPageLoading, let history = currentHistory, !history.isCached {
                performAutoCache()
            }
        }
    }

    private func performAutoCache() {
        guard let url = currentURL,
              let history = currentHistory,
              !history.isCached else {
            return
        }

        // 开始自动缓存
        loadingRelay.accept(true)
        canCacheRelay.accept(false)
        cacheProgressRelay.accept(0)

        cacheManager.cachePage(history: history, progress: { [weak self] progress in
            self?.cacheProgressRelay.accept(progress)
        }, completion: { [weak self] result in
            self?.loadingRelay.accept(false)

            switch result {
            case .success:
                self?.isCachedRelay.accept(true)
                self?.updateURLInfo(url: url)
                print("✅ Auto-cache completed for: \(url.absoluteString)")
            case .failure(let error):
                self?.errorMessageRelay.accept("自动缓存失败: \(error.localizedDescription)")
                self?.canCacheRelay.accept(true)
                print("❌ Auto-cache failed: \(error.localizedDescription)")
            }
        })
    }

    // MARK: - Public Methods

    func getCurrentHistory() -> WebPageHistory? {
        return currentHistory
    }

    func refreshCacheStatus() {
        guard let url = currentURL else { return }
        updateURLInfo(url: url)
    }

    /// 通知 ViewModel 页面开始加载
    func notifyPageDidStartLoading() {
        isPageLoading = true
    }

    /// 通知 ViewModel 页面加载完成
    func notifyPageDidFinishLoading() {
        isPageLoading = false

        // 如果缓存模式已开启，自动触发缓存
        if isCacheModeEnabled, let history = currentHistory, !history.isCached {
            performAutoCache()
        }
    }
}
