//
//  TokenGenerateViewModel.swift
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
        let showShare: Driver<String?>  // 分享的口令文本
        let copySuccess: Driver<Void>
        let errorMessage: Driver<String?>
    }

    // MARK: - Properties

    private let historyManager: WebPageHistoryManager
    private let tokenManager: AccessTokenManager

    private let historiesRelay = BehaviorRelay<[WebPageHistory]>(value: [])
    private let isEmptyRelay = BehaviorRelay<Bool>(value: true)
    private let generatedTokenRelay = BehaviorRelay<String?>(value: nil)
    private let showShareRelay = PublishRelay<String?>()
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
                    self.errorMessageRelay.accept("请先选择要生成口令的URL")
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
                    self.generatedTokenRelay.accept(token.token)
                } else {
                    self.errorMessageRelay.accept("生成口令失败，请重试")
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
            .withLatestFrom(generatedTokenRelay.asDriver(onErrorJustReturn: nil))
            .compactMap { $0 }
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
        let histories = Array(historyManager.getAllHistories().prefix(50))  // 只取最近50条
        historiesRelay.accept(histories)
        isEmptyRelay.accept(histories.isEmpty)
    }

    // MARK: - Public Methods

    /// 刷新历史记录
    func refreshHistories() {
        loadHistories()
    }
}
