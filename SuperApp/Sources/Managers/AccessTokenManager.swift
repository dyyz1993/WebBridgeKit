//
//  AccessTokenManager.swift
//  WebBridgeKit
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import RealmSwift
import WebBridgeKit

/// 访问口令管理器
/// 负责口令的生成、验证、删除、延长有效期
public class AccessTokenManager {

    public static let shared = AccessTokenManager()

    let realmConfiguration: Realm.Configuration

    private init() {
        self.realmConfiguration = Realm.Configuration(
            fileURL: Realm.Configuration.defaultConfiguration.fileURL?.deletingLastPathComponent().appendingPathComponent("accessToken.realm"),
            schemaVersion: 1
        )
    }

    /// 获取 Realm 实例
    private func getRealm() -> Realm? {
        return try? Realm(configuration: realmConfiguration)
    }

    // MARK: - 生成与管理

    /// 生成口令
    /// - Parameters:
    ///   - url: 目标URL
    ///   - duration: 有效时长（秒），-1 表示永久
    /// - Returns: 创建的口令对象
    @discardableResult
    public func generateToken(url: URL, duration: TimeInterval) -> AccessToken? {
        let realm = getRealm()

        let token = AccessToken()
        token.url = url.absoluteString
        token.title = url.host
        token.token = generateTokenCode()
        token.validDuration = duration == -1 ? -1 : Int(duration)
        token.createdAt = Date()

        if duration == -1 {
            // 永久有效，设置一个很远的过期时间
            token.expiresAt = Date(timeIntervalSince1970: 9999999999)
        } else {
            token.expiresAt = Date().addingTimeInterval(duration)
        }

        token.accessCount = 0

        try? realm?.write {
            realm?.add(token)
        }

        WebBridgeLogger.shared.log(.info, "🔑 Token generated: \(token.token)")
        return token
    }

    /// 验证口令是否有效
    /// - Parameter token: 口令码
    /// - Returns: 是否有效
    public func validateToken(token: String) -> Bool {
        guard let tokenObj = getTokenInfo(token: token) else { return false }
        return !tokenObj.isExpired
    }

    /// 获取口令信息
    public func getTokenInfo(token: String) -> AccessToken? {
        let realm = getRealm()
        let predicate = NSPredicate(format: "token == %@", token)
        return realm?.objects(AccessToken.self).filter(predicate).first
    }

    /// 增加口令访问次数
    func incrementAccessCount(token: String) {
        let realm = getRealm()
        guard let tokenObj = getTokenInfo(token: token) else { return }

        try? realm?.write {
            tokenObj.accessCount += 1
        }
    }

    // MARK: - CRUD

    /// 删除口令
    public func deleteToken(id: String) {
        let realm = getRealm()
        guard let token = realm?.object(ofType: AccessToken.self, forPrimaryKey: id) else { return }

        try? realm?.write {
            realm?.delete(token)
        }

        WebBridgeLogger.shared.log(.info, "🗑️ Token deleted: \(id)")
    }

    /// 获取所有口令
    public func getAllTokens() -> Results<AccessToken> {
        guard let realm = getRealm() else {
            return try! Realm().objects(AccessToken.self).filter("FALSEPREDICATE")
        }
        return realm.objects(AccessToken.self)
            .sorted(byKeyPath: "createdAt", ascending: false)
    }

    /// 获取有效的口令
    public func getActiveTokens() -> Results<AccessToken> {
        guard let realm = getRealm() else {
            return try! Realm().objects(AccessToken.self).filter("FALSEPREDICATE")
        }
        let now = Date()
        return realm.objects(AccessToken.self)
            .filter("expiresAt > %@", now as NSDate)
            .sorted(byKeyPath: "createdAt", ascending: false)
    }

    /// 获取已过期的口令
    func getExpiredTokens() -> Results<AccessToken> {
        guard let realm = getRealm() else {
            return try! Realm().objects(AccessToken.self).filter("FALSEPREDICATE")
        }
        let now = Date()
        return realm.objects(AccessToken.self)
            .filter("expiresAt <= %@", now as NSDate)
            .sorted(byKeyPath: "expiresAt", ascending: false)
    }

    // MARK: - 特殊操作

    /// 延长口令有效期
    /// - Parameters:
    ///   - id: 口令ID
    ///   - duration: 延长的时长（秒）
    public func extendToken(id: String, duration: TimeInterval) {
        let realm = getRealm()
        guard let token = realm?.object(ofType: AccessToken.self, forPrimaryKey: id) else { return }

        try? realm?.write {
            token.expiresAt = token.expiresAt.addingTimeInterval(duration)
            token.validDuration += Int(duration)
        }

        WebBridgeLogger.shared.log(.info, "⏰ Token extended: \(id)")
    }

    /// 清理已过期的口令
    public func cleanupExpiredTokens() {
        let realm = getRealm()
        let expired = getExpiredTokens()

        try? realm?.write {
            realm?.delete(expired)
        }

        WebBridgeLogger.shared.log(.info, "🧹 Cleaned up \(expired.count) expired tokens")
    }

    // MARK: - 私有方法

    /// 生成随机口令码
    private func generateTokenCode() -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<8).map { _ in letters.randomElement()! })
    }
}
