//
//  ServerConfigViewModel.swift
//  DemoApp
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa
import WebBridgeKit

/// 服务器配置 ViewModel
class ServerConfigViewModel: ViewModel {

    // MARK: - Input & Output

    struct Input {
        let serverTypeChange: Driver<String>      // "default" or "custom"
        let baseURLChange: Driver<String?>        // Base URL 输入
        let apiEndpointChange: Driver<String?>    // API Endpoint 输入
        let testConnection: Driver<Void>          // 测试连接
        let saveConfig: Driver<Void>              // 保存配置
        let resetConfig: Driver<Void>             // 重置配置
    }

    struct Output {
        let currentConfig: Driver<ServerConfig?>     // 当前配置
        let serverType: Driver<String>               // 服务器类型
        let baseURL: Driver<String?>                 // Base URL
        let apiEndpoint: Driver<String?>             // API Endpoint
        let testResult: Driver<Bool?>                // 测试结果
        let saveSuccess: Driver<Bool>                // 保存成功
        let resetSuccess: Driver<Bool>               // 重置成功
        let isCustomServer: Driver<Bool>             // 是否为自定义服务器
        let isLoading: Driver<Bool>                  // 加载状态
    }

    // MARK: - Properties

    private let serverConfigManager = ServerConfigManager.shared

    private let currentConfigRelay = BehaviorRelay<ServerConfig?>(value: nil)
    private let serverTypeRelay = BehaviorRelay<String>(value: "default")
    private let baseURLRelay = BehaviorRelay<String?>(value: nil)
    private let apiEndpointRelay = BehaviorRelay<String?>(value: nil)
    private let testResultRelay = BehaviorRelay<Bool?>(value: nil)
    private let saveSuccessRelay = PublishRelay<Bool>()
    private let resetSuccessRelay = PublishRelay<Bool>()
    private let isLoadingRelay = BehaviorRelay<Bool>(value: false)

    // 默认配置
    private let defaultBaseURL = "https://api.webbridgekit.com"
    private let defaultAPIEndpoint = "/v1"

    // MARK: - Transform

    func transform(input: Input) -> Output {
        // 加载当前配置
        loadCurrentConfig()

        // 处理服务器类型切换
        input.serverTypeChange
            .drive(onNext: { [weak self] serverType in
                self?.handleServerTypeChange(serverType)
            })
            .disposed(by: rx)

        // 处理 Base URL 变化
        input.baseURLChange
            .drive(baseURLRelay)
            .disposed(by: rx)

        // 处理 API Endpoint 变化
        input.apiEndpointChange
            .drive(apiEndpointRelay)
            .disposed(by: rx)

        // 处理测试连接
        input.testConnection
            .drive(onNext: { [weak self] in
                self?.testConnection()
            })
            .disposed(by: rx)

        // 处理保存配置
        input.saveConfig
            .drive(onNext: { [weak self] in
                self?.saveConfig()
            })
            .disposed(by: rx)

        // 处理重置配置
        input.resetConfig
            .drive(onNext: { [weak self] in
                self?.resetConfig()
            })
            .disposed(by: rx)

        return Output(
            currentConfig: currentConfigRelay.asDriver(),
            serverType: serverTypeRelay.asDriver(),
            baseURL: baseURLRelay.asDriver(),
            apiEndpoint: apiEndpointRelay.asDriver(),
            testResult: testResultRelay.asDriver(),
            saveSuccess: saveSuccessRelay.asDriver(onErrorJustReturn: false),
            resetSuccess: resetSuccessRelay.asDriver(onErrorJustReturn: false),
            isCustomServer: serverTypeRelay.asDriver().map { $0 == "custom" },
            isLoading: isLoadingRelay.asDriver()
        )
    }

    // MARK: - Private Methods

    /// 加载当前配置
    private func loadCurrentConfig() {
        let config = serverConfigManager.getActiveConfig()
        currentConfigRelay.accept(config)

        if let config = config {
            serverTypeRelay.accept(config.serverType)
            baseURLRelay.accept(config.baseURL)
            apiEndpointRelay.accept(config.apiEndpoint)
        } else {
            // 如果没有配置，使用默认值
            serverTypeRelay.accept("default")
            baseURLRelay.accept(defaultBaseURL)
            apiEndpointRelay.accept(defaultAPIEndpoint)
        }
    }

    /// 处理服务器类型切换
    private func handleServerTypeChange(_ serverType: String) {
        serverTypeRelay.accept(serverType)

        if serverType == "default" {
            // 切换到默认服务器时，填充默认值
            baseURLRelay.accept(defaultBaseURL)
            apiEndpointRelay.accept(defaultAPIEndpoint)
        }
        // 如果是自定义，保持当前输入值不变
    }

    /// 测试连接
    private func testConnection() {
        isLoadingRelay.accept(true)
        testResultRelay.accept(nil) // 重置测试结果

        // 构建临时配置用于测试
        let tempConfig = ServerConfig()
        tempConfig.serverType = serverTypeRelay.value
        tempConfig.baseURL = baseURLRelay.value
        tempConfig.apiEndpoint = apiEndpointRelay.value

        serverConfigManager.testConnection(config: tempConfig) { [weak self] success in
            self?.isLoadingRelay.accept(false)
            self?.testResultRelay.accept(success)
        }
    }

    /// 保存配置
    private func saveConfig() {
        let serverType = serverTypeRelay.value
        let baseURL = baseURLRelay.value
        let apiEndpoint = apiEndpointRelay.value

        // 验证输入
        guard serverType == "default" || (!baseURL.isNilOrEmpty && !apiEndpoint.isNilOrEmpty) else {
            saveSuccessRelay.accept(false)
            return
        }

        // 创建配置对象
        let config = ServerConfig()
        config.id = serverType == "default" ? "default" : UUID().uuidString
        config.serverType = serverType
        config.baseURL = baseURL
        config.apiEndpoint = apiEndpoint
        config.isActive = true
        config.updatedAt = Date()

        // 保存配置
        serverConfigManager.saveConfig(config)
        serverConfigManager.activateConfig(id: config.id)

        // 更新当前配置
        currentConfigRelay.accept(config)
        saveSuccessRelay.accept(true)
    }

    /// 重置配置
    private func resetConfig() {
        serverConfigManager.resetToDefault()

        // 重新加载配置
        loadCurrentConfig()
        resetSuccessRelay.accept(true)
    }
}

// MARK: - String Extension

private extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        return self?.isEmpty ?? true
    }
}
