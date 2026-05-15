//
//  ServerConfigManager.swift
//  WebBridgeKit
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import RealmSwift
import WebBridgeKit

/// 服务器配置管理器
/// 负责服务器配置的保存、读取、重置
public class ServerConfigManager {

    public static let shared = ServerConfigManager()

    let realmConfiguration: Realm.Configuration

    private let defaultBaseURL = "https://wbk.shanbox.19930810.xyz:8443"
    private let defaultAPIEndpoint = ""

    private var hasEnsuredDefault = false
    private let initLock = NSRecursiveLock()

    public init() {
        self.realmConfiguration = Realm.Configuration(
            fileURL: Realm.Configuration.defaultConfiguration.fileURL?.deletingLastPathComponent().appendingPathComponent("serverConfig.realm"),
            schemaVersion: 1,
            objectTypes: [ServerConfig.self]
        )
    }

    private func ensureDefaultOnce() {
        initLock.lock()
        defer { initLock.unlock() }
        guard !hasEnsuredDefault else { return }
        hasEnsuredDefault = true
        do {
            let realm = try Realm(configuration: realmConfiguration)
            if realm.object(ofType: ServerConfig.self, forPrimaryKey: "default") == nil {
                try resetToDefaultSync(in: realm)
            }
        } catch {
            print("⚠️ [ServerConfigManager] Failed to ensure default config: \(error)")
        }
    }

    private func getRealm() -> Realm? {
        return try? Realm(configuration: realmConfiguration)
    }

    private func resetToDefaultSync(in realm: Realm) throws {
        try realm.write {
            if let existing = realm.object(ofType: ServerConfig.self, forPrimaryKey: "default") {
                realm.delete(existing)
            }
            let defaultConfig = ServerConfig()
            defaultConfig.id = "default"
            defaultConfig.serverType = "default"
            defaultConfig.baseURL = defaultBaseURL
            defaultConfig.apiEndpoint = defaultAPIEndpoint
            defaultConfig.isActive = true
            defaultConfig.updatedAt = Date()
            realm.add(defaultConfig)
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
        ensureDefaultOnce()
        guard let realm = getRealm() else { return nil }
        return realm.object(ofType: ServerConfig.self, forPrimaryKey: "default")
    }

    /// 激活指定配置
    public func activateConfig(id: String) {
        guard let realm = getRealm() else { return }

        let defaultConfig = realm.object(ofType: ServerConfig.self, forPrimaryKey: "default")
        let targetConfig = realm.object(ofType: ServerConfig.self, forPrimaryKey: id)

        try? realm.write {
            defaultConfig?.isActive = false
            targetConfig?.isActive = true
            targetConfig?.updatedAt = Date()
        }

        WebBridgeLogger.shared.log(.info, "✅ Config activated: \(id)")
    }

    /// 重置为默认配置
    public func resetToDefault() {
        guard let realm = getRealm() else { return }

        try? realm.write {
            if let existing = realm.object(ofType: ServerConfig.self, forPrimaryKey: "default") {
                realm.delete(existing)
            }
        }

        let defaultConfig = ServerConfig()
        defaultConfig.id = "default"
        defaultConfig.serverType = "default"
        defaultConfig.baseURL = defaultBaseURL
        defaultConfig.apiEndpoint = defaultAPIEndpoint
        defaultConfig.isActive = true
        defaultConfig.updatedAt = Date()

        try? realm.write {
            realm.add(defaultConfig)
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
    public func getAllConfigs() -> [ServerConfig] {
        guard let realm = getRealm() else { return [] }
        var configs: [ServerConfig] = []
        if let defaultCfg = realm.object(ofType: ServerConfig.self, forPrimaryKey: "default") {
            configs.append(defaultCfg)
        }
        return configs
    }

    // MARK: - 连接测试

    /// 测试服务器连接
    /// - Parameters:
    ///   - config: 要测试的配置
    ///   - completion: 完成回调，返回是否成功
    public func testConnection(config: ServerConfig, completion: @escaping (Bool) -> Void) {
        guard let url = config.fullAPIURL else {
            completion(false)
            return
        }

        // 真实的网络测试：发送一个轻量级的 GET 请求（如 /ping 或 /health）
        // 这里假设服务端提供了一个健康检查接口，如果没有，则尝试连接 BaseURL
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0 // 5秒超时

        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    WebBridgeLogger.shared.log(.error, "❌ Connection test failed: \(error.localizedDescription)")
                    completion(false)
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    // 只要返回 200~399 范围内的状态码，认为服务是存活的
                    let isSuccess = (200...399).contains(httpResponse.statusCode)
                    WebBridgeLogger.shared.log(.info, "🔍 Connection test result for \(url.absoluteString): \(isSuccess) (Status: \(httpResponse.statusCode))")
                    completion(isSuccess)
                } else {
                    completion(false)
                }
            }
        }
        task.resume()

        WebBridgeLogger.shared.log(.info, "🔍 Testing real connection: \(url.absoluteString)")
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
