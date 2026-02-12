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
        let testPushResult: Driver<(success: Bool, message: String)>
    }

    // MARK: - Properties

    private let apiKeyManager: APIKeyManager
    private let permanentKeyRelay = BehaviorRelay<String>(value: "")
    private let temporaryKeysRelay = BehaviorRelay<[APIKey]>(value: [])
    private let refreshSuccessRelay = PublishRelay<Bool>()
    private let showExamplesRelay = PublishRelay<Void>()
    private let copySuccessRelay = PublishRelay<Void>()
    private let addedTemporaryKeyRelay = PublishRelay<APIKey?>()
    private let testPushResultRelay = PublishRelay<(success: Bool, message: String)>()

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
                self.permanentKeyRelay.accept(newKey.value)
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
            addedTemporaryKey: addedTemporaryKeyRelay.asDriver(onErrorJustReturn: nil),
            testPushResult: testPushResultRelay.asDriver(onErrorJustReturn: (false, "未知错误"))
        )
    }

    // MARK: - Public Methods

    // MARK: - Bark Configuration Persistence
    
    private let barkKeyKey = "com.webbridgekit.bark.key"
    private let barkServerKey = "com.webbridgekit.bark.server"
    
    /// 保存 Bark 配置
    func saveBarkConfig(key: String, server: String?) {
        UserDefaults.standard.set(key, forKey: barkKeyKey)
        if let server = server, !server.isEmpty {
            UserDefaults.standard.set(server, forKey: barkServerKey)
        } else {
            UserDefaults.standard.removeObject(forKey: barkServerKey)
        }
    }
    
    /// 获取当前 Bark Key
    func getBarkKey() -> String? {
        return UserDefaults.standard.string(forKey: barkKeyKey)
    }
    
    /// 获取当前 Bark 服务器
    func getBarkServer() -> String {
        return UserDefaults.standard.string(forKey: barkServerKey) ?? "https://api.day.app"
    }

    /// 发送永久密钥测试推送
    func sendPermanentKeyTestPush() {
        guard let barkKey = getBarkKey(), !barkKey.isEmpty else {
            testPushResultRelay.accept((false, "请先在页面下方配置您的 Bark Key"))
            return
        }
        
        let server = getBarkServer()
        let title = "WebBridgeKit 测试".addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
        let body = "您的永久 API Key 状态正常".addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
        
        // 构造 Bark V1 URL
        let urlString = "\(server)/\(barkKey)/\(title)/\(body)?group=WebBridgeKit&icon=https://day.app/assets/images/avatar.jpg"
        
        performPushRequest(urlString: urlString)
    }
    
    /// 发送临时密钥测试推送
    func sendTemporaryKeyTestPush(key: APIKey) {
        guard let barkKey = getBarkKey(), !barkKey.isEmpty else {
            testPushResultRelay.accept((false, "请先在页面下方配置您的 Bark Key"))
            return
        }
        
        let server = getBarkServer()
        let title = "临时密钥测试 (\(key.name))".addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
        let body = "过期时间: \(DateFormatter.localizedString(from: key.expiresAt ?? Date(), dateStyle: .short, timeStyle: .medium))".addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
        
        // 构造 Bark V1 URL
        let urlString = "\(server)/\(barkKey)/\(title)/\(body)?group=WebBridgeKit&icon=https://day.app/assets/images/clock.jpg"
        
        performPushRequest(urlString: urlString)
    }

    private func performPushRequest(urlString: String) {
        guard let url = URL(string: urlString) else {
            testPushResultRelay.accept((false, "无效的请求地址"))
            return
        }

        print("🚀 [APIKey] Sending test push: \(urlString)")

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.testPushResultRelay.accept((false, "发送失败: \(error.localizedDescription)"))
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        self?.testPushResultRelay.accept((true, "测试消息已发出，请注意查看通知"))
                    } else {
                        self?.testPushResultRelay.accept((false, "服务器返回错误: \(httpResponse.statusCode)"))
                    }
                }
            }
        }.resume()
    }

    /// 添加临时密钥
    func addTemporaryKey(duration: TimeInterval, name: String? = nil, groupId: String? = nil) {
        let key = apiKeyManager.generateTemporaryKey(duration: duration, name: name, boundGroupId: groupId)
        loadTemporaryKeys()
        addedTemporaryKeyRelay.accept(key)
    }

    /// 更新密钥绑定群组
    func updateKeyGroupId(id: String, groupId: String?) {
        let allKeys = apiKeyManager.getAllKeys()
        if var key = allKeys.first(where: { $0.id == id }) {
            key.boundGroupId = groupId
            apiKeyManager.updateKey(key)
            loadTemporaryKeys()
        }
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
        permanentKeyRelay.accept(permanentKey.value)

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
