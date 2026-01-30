//
//  APIKeyManager.swift
//  WebBridgeKit
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import RealmSwift
import CommonCrypto

/// API 密钥管理器
/// 负责密钥的生成、刷新、验证、删除
public class APIKeyManager {

    public static let shared = APIKeyManager()

    private let realmConfiguration: Realm.Configuration
    private let permanentKeyID = "permanent-key"

    private init() {
        // 使用独立的 Realm 文件
        self.realmConfiguration = Realm.Configuration(
            fileURL: Realm.Configuration.defaultConfiguration.fileURL?.deletingLastPathComponent().appendingPathComponent("apiKey.realm"),
            schemaVersion: 1
        )

        // 初始化永久密钥
        ensurePermanentKeyExists()
    }

    /// 获取 Realm 实例
    private func getRealm() -> Realm? {
        return try? Realm(configuration: realmConfiguration)
    }

    /// 确保永久密钥存在
    private func ensurePermanentKeyExists() {
        guard let permanentKey = getPermanentKeyObject() else {
            // 不存在则创建
            _ = createPermanentKey()
            return
        }
    }

    // MARK: - 永久密钥

    /// 获取永久密钥
    /// - Returns: 永久密钥字符串
    public func getPermanentKey() -> String {
        guard let key = getPermanentKeyObject() else {
            return createPermanentKey()
        }
        return key.keyValue
    }

    /// 刷新永久密钥
    /// - Returns: 新的永久密钥字符串
    @discardableResult
    public func refreshPermanentKey() -> String {
        let realm = getRealm()

        // 删除旧的永久密钥
        if let oldKey = getPermanentKeyObject() {
            try? realm?.write {
                realm?.delete(oldKey)
            }
        }

        // 创建新的永久密钥
        let newKey = createPermanentKey()
        WebBridgeLogger.shared.log(.info, "🔄 Permanent key refreshed")
        return newKey
    }

    /// 获取永久密钥对象
    private func getPermanentKeyObject() -> APIKey? {
        let realm = getRealm()
        let predicate = NSPredicate(format: "id == %@", permanentKeyID)
        return realm?.objects(APIKey.self).filter(predicate).first
    }

    /// 创建永久密钥
    private func createPermanentKey() -> String {
        let realm = getRealm()

        let key = APIKey()
        key.id = permanentKeyID
        key.keyType = "permanent"
        key.keyValue = generateAPIKey()
        key.isActive = true
        key.createdAt = Date()
        key.expiresAt = nil

        try? realm?.write {
            realm?.add(key)
        }

        WebBridgeLogger.shared.log(.info, "🔑 Permanent key created")
        return key.keyValue
    }

    // MARK: - 临时密钥

    /// 生成临时密钥
    /// - Parameter duration: 有效时长（秒）
    /// - Returns: 创建的临时密钥对象
    @discardableResult
    public func generateTemporaryKey(duration: TimeInterval) -> APIKey? {
        let realm = getRealm()

        let key = APIKey()
        key.id = UUID().uuidString
        key.keyType = "temporary"
        key.keyValue = generateAPIKey()
        key.isActive = true
        key.createdAt = Date()
        key.expiresAt = Date().addingTimeInterval(duration)

        try? realm?.write {
            realm?.add(key)
        }

        WebBridgeLogger.shared.log(.info, "🔑 Temporary key generated, valid for \(Int(duration))s")
        return key
    }

    /// 验证密钥是否有效
    /// - Parameter key: 密钥字符串
    /// - Returns: 是否有效
    public func validateKey(key: String) -> Bool {
        let realm = getRealm()
        let predicate = NSPredicate(format: "keyValue == %@ AND isActive == true", key)
        guard let keyObj = realm?.objects(APIKey.self).filter(predicate).first else { return false }

        // 检查是否过期
        if keyObj.isExpired {
            return false
        }

        return true
    }

    // MARK: - CRUD

    /// 删除密钥
    public func deleteKey(id: String) {
        let realm = getRealm()
        guard let key = realm?.object(ofType: APIKey.self, forPrimaryKey: id) else { return }

        // 不允许删除永久密钥
        if key.id == permanentKeyID {
            WebBridgeLogger.shared.log(.warning, "⚠️ Cannot delete permanent key")
            return
        }

        try? realm?.write {
            realm?.delete(key)
        }

        WebBridgeLogger.shared.log(.info, "🗑️ Key deleted: \(id)")
    }

    /// 获取所有密钥
    public func getAllKeys() -> Results<APIKey> {
        guard let realm = getRealm() else {
            return try! Realm().objects(APIKey.self).filter("FALSEPREDICATE")
        }
        return realm.objects(APIKey.self)
            .sorted(byKeyPath: "createdAt", ascending: false)
    }

    /// 获取临时密钥
    public func getTemporaryKeys() -> Results<APIKey> {
        guard let realm = getRealm() else {
            return try! Realm().objects(APIKey.self).filter("FALSEPREDICATE")
        }
        let predicate = NSPredicate(format: "keyType == 'temporary'")
        return realm.objects(APIKey.self)
            .filter(predicate)
            .sorted(byKeyPath: "createdAt", ascending: false)
    }

    // MARK: - 维护

    /// 清理已过期的临时密钥
    public func cleanupExpiredKeys() {
        let realm = getRealm()
        let now = Date()
        let predicate = NSPredicate(format: "keyType == 'temporary' AND expiresAt <= %@", now as NSDate)
        let expired = realm?.objects(APIKey.self).filter(predicate)

        try? realm?.write {
            if let expired = expired {
                realm?.delete(expired)
            }
        }

        WebBridgeLogger.shared.log(.info, "🧹 Cleaned up \(expired?.count ?? 0) expired keys")
    }

    // MARK: - 私有方法

    /// 生成 API 密钥
    private func generateAPIKey() -> String {
        // 格式: wbk_ + 32位随机字符
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let randomPart = String((0..<32).map { _ in characters.randomElement()! })

        // 添加设备标识前缀
        let deviceID = UIDevice.current.identifierForVendor?.uuidString.prefix(8) ?? "unknown"
        return "wbk_\(deviceID)_\(randomPart)"
    }
}
