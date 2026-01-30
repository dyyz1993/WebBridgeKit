//
//  APIKeyManageViewModel.swift
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

/// 密钥管理 ViewModel
class APIKeyManageViewModel: ViewModel {

    // MARK: - Input & Output

    struct Input {
        let copyKey: Driver<Void>
        let refreshKey: Driver<Void>
        let addTemporaryKey: Driver<Void>
        let deleteKey: Driver<String>
        let showExamples: Driver<Void>
    }

    struct Output {
        let permanentKey: Driver<String>
        let temporaryKeys: Driver<[APIKey]>
        let refreshSuccess: Driver<Bool>
        let showExamples: Driver<Void>
        let copySuccess: Driver<Void>
        let addedTemporaryKey: Driver<APIKey?>
    }

    // MARK: - Properties

    private let apiKeyManager: APIKeyManager
    private let permanentKeyRelay = BehaviorRelay<String>(value: "")
    private let temporaryKeysRelay = BehaviorRelay<[APIKey]>(value: [])
    private let refreshSuccessRelay = PublishRelay<Bool>()
    private let showExamplesRelay = PublishRelay<Void>()
    private let copySuccessRelay = PublishRelay<Void>()
    private let addedTemporaryKeyRelay = PublishRelay<APIKey?>()

    // MARK: - Initialization

    override init() {
        self.apiKeyManager = APIKeyManager.shared
        super.init()
        loadInitialData()
    }

    // MARK: - Transform

    func transform(input: Input) -> Output {
        // 复制永久密钥
        input.copyKey
            .withLatestFrom(permanentKeyRelay.asDriver(onErrorJustReturn: ""))
            .do(onNext: { [weak self] key in
                UIPasteboard.general.string = key
                self?.copySuccessRelay.accept(())
            })
            .drive()
            .disposed(by: rx)

        // 刷新永久密钥
        input.refreshKey
            .do(onNext: { [weak self] in
                guard let self = self else { return }
                let newKey = self.apiKeyManager.refreshPermanentKey()
                self.permanentKeyRelay.accept(newKey)
                self.refreshSuccessRelay.accept(true)
            })
            .drive()
            .disposed(by: rx)

        // 添加临时密钥（duration 由 ViewController 提供）
        input.addTemporaryKey
            .do(onNext: {
                // 这个信号应该携带 duration 参数
                // 实际处理在 ViewController 中通过回调完成
            })
            .drive()
            .disposed(by: rx)

        // 删除密钥
        input.deleteKey
            .do(onNext: { [weak self] keyId in
                self?.apiKeyManager.deleteKey(id: keyId)
                self?.loadTemporaryKeys()
            })
            .drive()
            .disposed(by: rx)

        // 显示使用示例
        input.showExamples
            .do(onNext: { [weak self] in
                self?.showExamplesRelay.accept(())
            })
            .drive()
            .disposed(by: rx)

        return Output(
            permanentKey: permanentKeyRelay.asDriver(onErrorJustReturn: ""),
            temporaryKeys: temporaryKeysRelay.asDriver(onErrorJustReturn: []),
            refreshSuccess: refreshSuccessRelay.asDriver(onErrorJustReturn: false),
            showExamples: showExamplesRelay.asDriver(onErrorJustReturn: ()),
            copySuccess: copySuccessRelay.asDriver(onErrorJustReturn: ()),
            addedTemporaryKey: addedTemporaryKeyRelay.asDriver(onErrorJustReturn: nil)
        )
    }

    // MARK: - Public Methods

    /// 添加临时密钥
    func addTemporaryKey(duration: TimeInterval) {
        let key = apiKeyManager.generateTemporaryKey(duration: duration)
        loadTemporaryKeys()
        addedTemporaryKeyRelay.accept(key)
    }

    /// 获取永久密钥的脱敏显示
    func getMaskedPermanentKey() -> String {
        let key = permanentKeyRelay.value
        return maskKey(key)
    }

    /// 密钥脱敏显示
    func maskKey(_ key: String) -> String {
        guard key.count > 12 else { return key }
        let prefix = String(key.prefix(8))
        let suffix = String(key.suffix(4))
        return "\(prefix)****\(suffix)"
    }

    // MARK: - Private Methods

    private func loadInitialData() {
        // 加载永久密钥
        let permanentKey = apiKeyManager.getPermanentKey()
        permanentKeyRelay.accept(permanentKey)

        // 加载临时密钥
        loadTemporaryKeys()
    }

    private func loadTemporaryKeys() {
        // 清理过期密钥
        apiKeyManager.cleanupExpiredKeys()

        // 获取临时密钥列表
        let keys = Array(apiKeyManager.getTemporaryKeys())
        temporaryKeysRelay.accept(keys)
    }
}
