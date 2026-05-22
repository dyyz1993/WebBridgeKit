//
//  TokenGenerateViewModel.swift
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

private struct TokenHistorySnapshot: Sendable {
    let id: String
    let url: String
    let title: String?
    let favicon: Data?
    let htmlPath: String?
    let cachedSize: Int64
    let isCached: Bool
    let isPinned: Bool
    let isFavorite: Bool
    let visitCount: Int
    let lastVisitDate: Date
    let cacheDate: Date?
    let thumbnail: Data?
    let ruleId: String?
    let ruleName: String?
    let isExcluded: Bool
    let resourcePaths: [String]

    init(history: WebPageHistory) {
        self.id = history.id
        self.url = history.url
        self.title = history.title
        self.favicon = history.favicon
        self.htmlPath = history.htmlPath
        self.cachedSize = history.cachedSize
        self.isCached = history.isCached
        self.isPinned = history.isPinned
        self.isFavorite = history.isFavorite
        self.visitCount = history.visitCount
        self.lastVisitDate = history.lastVisitDate
        self.cacheDate = history.cacheDate
        self.thumbnail = history.thumbnail
        self.ruleId = history.ruleId
        self.ruleName = history.ruleName
        self.isExcluded = history.isExcluded
        self.resourcePaths = Array(history.resourcePaths)
    }

    func makeHistory() -> WebPageHistory {
        let history = WebPageHistory()
        history.id = id
        history.url = url
        history.title = title
        history.favicon = favicon
        history.htmlPath = htmlPath
        history.cachedSize = cachedSize
        history.isCached = isCached
        history.isPinned = isPinned
        history.isFavorite = isFavorite
        history.visitCount = visitCount
        history.lastVisitDate = lastVisitDate
        history.cacheDate = cacheDate
        history.thumbnail = thumbnail
        history.ruleId = ruleId
        history.ruleName = ruleName
        history.isExcluded = isExcluded
        history.resourcePaths.append(objectsIn: resourcePaths)
        return history
    }
}

/// 口令生成 ViewModel
class TokenGenerateViewModel: ViewModel {

    // MARK: - Input & Output

    struct Input {
        let selectedURL: Driver<URL?>
        let duration: Driver<Int>  // 天数: 1/7/30/永久(用-1表示)
        let generateTap: Driver<Void>
        let copyTap: Driver<Void>
        let shareTap: Driver<Void>
    }

    struct Output {
        let histories: Driver<[WebPageHistory]>
        let isEmpty: Driver<Bool>
        let generatedToken: Driver<String?>
        let showShare: Driver<AccessToken?>  // 分享的完整口令对象
        let copySuccess: Driver<Void>
        let errorMessage: Driver<String?>
    }

    // MARK: - Properties

    private let historyManager: WebPageHistoryManager
    private let tokenManager: AccessTokenManager

    private let historiesRelay = BehaviorRelay<[WebPageHistory]>(value: [])
    private let isEmptyRelay = BehaviorRelay<Bool>(value: true)
    private let generatedTokenRelay = BehaviorRelay<String?>(value: nil)
    private var lastGeneratedAccessToken: AccessToken?
    private let showShareRelay = PublishRelay<AccessToken?>()
    private let copySuccessRelay = PublishRelay<Void>()
    private let errorMessageRelay = PublishRelay<String?>()

    private var currentSelectedURL: URL?
    private var currentDuration: Int = 7  // 默认7天

    // MARK: - Initialization

    override init() {
        self.historyManager = WebPageHistoryManager.shared
        self.tokenManager = AccessTokenManager.shared
        super.init()
    }

    // MARK: - Transform

    func transform(input: Input) -> Output {
        // 监听URL选择
        input.selectedURL
            .drive(onNext: { [weak self] url in
                self?.currentSelectedURL = url
            })
            .disposed(by: rx)

        // 监听时长选择
        input.duration
            .drive(onNext: { [weak self] duration in
                self?.currentDuration = duration
            })
            .disposed(by: rx)

        // 生成口令
        input.generateTap
            .do(onNext: { [weak self] in
                guard let self = self else { return }
                guard let url = self.currentSelectedURL else {
                    self.errorMessageRelay.accept(L10n.tr("token.generate.select_url_error"))
                    return
                }

                // 计算有效时长（秒）
                let durationInSeconds: TimeInterval
                if self.currentDuration == -1 {
                    durationInSeconds = -1  // 永久
                } else {
                    durationInSeconds = TimeInterval(self.currentDuration * 24 * 60 * 60)
                }

                // 生成口令
                if let token = self.tokenManager.generateToken(url: url, duration: durationInSeconds) {
                    self.lastGeneratedAccessToken = token
                    self.generatedTokenRelay.accept(token.token)
                } else {
                    self.errorMessageRelay.accept(L10n.tr("token.generate.failure"))
                }
            })
            .drive()
            .disposed(by: rx)

        // 复制口令
        input.copyTap
            .withLatestFrom(generatedTokenRelay.asDriver(onErrorJustReturn: nil))
            .compactMap { $0 }
            .do(onNext: { [weak self] token in
                UIPasteboard.general.string = token
                self?.copySuccessRelay.accept(())
            })
            .drive()
            .disposed(by: rx)

        // 分享口令
        input.shareTap
            .compactMap { [weak self] in self?.lastGeneratedAccessToken }
            .do(onNext: { [weak self] token in
                self?.showShareRelay.accept(token)
            })
            .drive()
            .disposed(by: rx)

        // 加载历史记录
        loadHistories()

        return Output(
            histories: historiesRelay.asDriver(onErrorJustReturn: []),
            isEmpty: isEmptyRelay.asDriver(onErrorJustReturn: true),
            generatedToken: generatedTokenRelay.asDriver(onErrorJustReturn: nil),
            showShare: showShareRelay.asDriver(onErrorJustReturn: nil),
            copySuccess: copySuccessRelay.asDriver(onErrorJustReturn: ()),
            errorMessage: errorMessageRelay.asDriver(onErrorJustReturn: nil)
        )
    }

    // MARK: - Private Methods

    private func loadHistories() {
        Task { [weak self] in
            guard let self else { return }
            let allHistories = (try? await WebPageHistoryManager.shared.getAllHistories()) ?? []
            let historySnapshots = allHistories.prefix(50).map { TokenHistorySnapshot(history: $0) }
            await MainActor.run {
                let histories = historySnapshots.map { $0.makeHistory() }
                self.historiesRelay.accept(histories)
                self.isEmptyRelay.accept(histories.isEmpty)
            }
        }
    }

    // MARK: - Public Methods

    /// 刷新历史记录
    func refreshHistories() {
        loadHistories()
    }
}
