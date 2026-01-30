//
//  ServerConfigManager.swift
//  WebBridgeKit
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import RealmSwift

/// 服务器配置管理器
/// 负责服务器配置的保存、读取、重置
public class ServerConfigManager {

    public static let shared = ServerConfigManager()

    private let realmConfiguration: Realm.Configuration

    // 默认服务器配置
    private let defaultBaseURL = "https://api.webbridgekit.com"
    private let defaultAPIEndpoint = "/v1"

    public init() {
        // 使用独立的 Realm 文件
        self.realmConfiguration = Realm.Configuration(
            fileURL: Realm.Configuration.defaultConfiguration.fileURL?.deletingLastPathComponent().appendingPathComponent("serverConfig.realm"),
            schemaVersion: 1
        )

        // 初始化默认配置
        ensureDefaultConfigExists()
    }

    /// 获取 Realm 实例
    private func getRealm() -> Realm? {
        return try? Realm(configuration: realmConfiguration)
    }

    /// 确保默认配置存在
    private func ensureDefaultConfigExists() {
        if getActiveConfig() == nil {
            resetToDefault()
        }
    }

    // MARK: - 配置管理

    /// 保存配置
    public func saveConfig(_ config: ServerConfig) {
        let realm = getRealm()

        config.updatedAt = Date()

        try? realm?.write {
            realm?.add(config, update: .modified)
        }

        WebBridgeLogger.shared.log(.info, "💾 Server config saved: \(config.serverType)")
    }

    /// 获取当前激活的配置
    public func getActiveConfig() -> ServerConfig? {
        let realm = getRealm()
        let predicate = NSPredicate(format: "isActive == true")
        return realm?.objects(ServerConfig.self).filter(predicate).first
    }

    /// 激活指定配置
    public func activateConfig(id: String) {
        let realm = getRealm()

        // 先停用所有配置
        try? realm?.write {
            let allConfigs = realm?.objects(ServerConfig.self)
            allConfigs?.forEach { $0.isActive = false }
        }

        // 激活指定配置
        guard let config = realm?.object(ofType: ServerConfig.self, forPrimaryKey: id) else { return }

        try? realm?.write {
            config.isActive = true
            config.updatedAt = Date()
        }

        WebBridgeLogger.shared.log(.info, "✅ Config activated: \(id)")
    }

    /// 重置为默认配置
    public func resetToDefault() {
        let realm = getRealm()

        // 删除所有现有配置
        try? realm?.write {
            let allConfigs = realm?.objects(ServerConfig.self)
            if let configs = allConfigs, !configs.isEmpty {
                realm?.delete(configs)
            }
        }

        // 创建默认配置
        let defaultConfig = ServerConfig()
        defaultConfig.id = "default"
        defaultConfig.serverType = "default"
        defaultConfig.baseURL = defaultBaseURL
        defaultConfig.apiEndpoint = defaultAPIEndpoint
        defaultConfig.isActive = true
        defaultConfig.updatedAt = Date()

        try? realm?.write {
            realm?.add(defaultConfig)
        }

        WebBridgeLogger.shared.log(.info, "🔄 Reset to default server config")
    }

    /// 删除配置
    public func deleteConfig(id: String) {
        let realm = getRealm()

        // 不允许删除默认配置
        if id == "default" {
            WebBridgeLogger.shared.log(.warning, "⚠️ Cannot delete default config")
            return
        }

        guard let config = realm?.object(ofType: ServerConfig.self, forPrimaryKey: id) else { return }

        try? realm?.write {
            realm?.delete(config)
        }

        WebBridgeLogger.shared.log(.info, "🗑️ Config deleted: \(id)")
    }

    /// 获取所有配置
    public func getAllConfigs() -> Results<ServerConfig> {
        guard let realm = getRealm() else {
            return try! Realm().objects(ServerConfig.self).filter("FALSEPREDICATE")
        }
        return realm.objects(ServerConfig.self)
            .sorted(byKeyPath: "updatedAt", ascending: false)
    }

    // MARK: - 连接测试

    /// 测试服务器连接
    /// - Parameters:
    ///   - config: 要测试的配置
    ///   - completion: 完成回调，返回是否成功
    public func testConnection(config: ServerConfig, completion: @escaping (Bool) -> Void) {
        // TODO: 实现实际的连接测试
        // 这里使用简单的延迟模拟
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // 简单验证：检查配置是否有效
            let isValid = config.baseURL != nil && config.apiEndpoint != nil
            completion(isValid)
        }

        WebBridgeLogger.shared.log(.info, "🔍 Testing connection: \(config.serverType)")
    }

    /// 测试当前激活的服务器连接
    public func testActiveConnection(completion: @escaping (Bool) -> Void) {
        guard let config = getActiveConfig() else {
            completion(false)
            return
        }
        testConnection(config: config, completion: completion)
    }

    // MARK: - 便捷方法

    /// 获取当前激活的完整 API URL
    public func getActiveAPIURL() -> URL? {
        return getActiveConfig()?.fullAPIURL
    }

    /// 获取当前激活的 Base URL
    public func getActiveBaseURL() -> String? {
        return getActiveConfig()?.baseURL
    }

    /// 获取当前激活的 API Endpoint
    public func getActiveAPIEndpoint() -> String? {
        return getActiveConfig()?.apiEndpoint
    }

    /// 判断当前是否使用默认服务器
    public func isUsingDefaultServer() -> Bool {
        return getActiveConfig()?.isDefault ?? true
    }
}
