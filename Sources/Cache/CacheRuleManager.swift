//
//  CacheRuleManager.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-23.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import RealmSwift
import RxSwift

/// 缓存规则管理器
@available(*, deprecated, message: "Use PageCacheRuleManager instead for page-level offline caching. CacheRuleManager is deprecated and will be removed in a future version.")
public class CacheRuleManager {

    public static let shared = CacheRuleManager()

    private let realmConfiguration: Realm.Configuration
    private var rulesCache: [String: [CacheRule]] = [:]
    private let cacheLock = NSLock()

    private init() {
        // 配置 Realm - 使用独立的文件以避免与其他 Realm 冲突
        self.realmConfiguration = Realm.Configuration(
            fileURL: Realm.Configuration.defaultConfiguration.fileURL?.deletingLastPathComponent().appendingPathComponent("cacheRules.realm"),
            schemaVersion: 1,
            migrationBlock: { migration, oldSchemaVersion in
                // 未来版本迁移在这里处理
            }
        )

        // 检查并添加预设规则（如果不存在）
        checkAndAddPresetRules()
    }

    /// 获取 Realm 实例
    private func getRealm() -> Realm {
        do {
            return try Realm(configuration: realmConfiguration)
        } catch {
            // If Realm fails with the configuration, delete the old file and try again
            WebBridgeLogger.shared.error("Realm init failed: \(error.localizedDescription)")

            // Try to delete the old Realm file
            let config = realmConfiguration
            if let fileURL = config.fileURL {
                try? FileManager.default.removeItem(at: fileURL)
            }

            // Try again with a fresh Realm
            do {
                let realm = try Realm(configuration: config)
                WebBridgeLogger.shared.info("Created fresh Realm database")
                return realm
            } catch {
                WebBridgeLogger.shared.error("Failed to create Realm after cleanup: \(error.localizedDescription)")
                fatalError("Failed to initialize Realm: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Rule Management

    /// 获取所有规则
    public func getAllRules() -> [CacheRule] {
        return Array(getRealm().objects(CacheRuleRealm.self))
            .sorted { $0.priority > $1.priority }
            .map { $0.toCacheRule() }
    }

    /// 获取启用的规则
    public func getEnabledRules() -> [CacheRule] {
        return getRealm().objects(CacheRuleRealm.self)
            .filter("isEnabled == true")
            .sorted { $0.priority > $1.priority }
            .map { $0.toCacheRule() }
    }

    /// 添加规则
    public func addRule(_ rule: CacheRule) -> Bool {
        do {
            let realm = getRealm()
            try realm.write {
                let realmRule = CacheRuleRealm(from: rule)
                realm.add(realmRule, update: .all)
            }
            invalidateCache()
            WebBridgeLogger.shared.info("Added cache rule: \(rule.name)")
            return true
        } catch {
            WebBridgeLogger.shared.error("Failed to add rule: \(error.localizedDescription)")
            return false
        }
    }

    /// 批量添加规则
    public func addRules(_ rules: [CacheRule]) -> Int {
        var addedCount = 0
        for rule in rules {
            if addRule(rule) {
                addedCount += 1
            }
        }
        return addedCount
    }

    /// 删除规则
    public func deleteRule(ruleId: String) -> Bool {
        do {
            let realm = getRealm()
            var deleted = false
            try realm.write {
                if let realmRule = realm.object(ofType: CacheRuleRealm.self, forPrimaryKey: ruleId) {
                    realm.delete(realmRule)
                    invalidateCache()
                    WebBridgeLogger.shared.info("Deleted cache rule: \(ruleId)")
                    deleted = true
                }
            }
            return deleted
        } catch {
            WebBridgeLogger.shared.error("Failed to delete rule: \(error.localizedDescription)")
            return false
        }
    }

    /// 更新规则状态
    public func updateRule(ruleId: String, enabled: Bool) -> Bool {
        do {
            let realm = getRealm()
            var updated = false
            try realm.write {
                if let realmRule = realm.object(ofType: CacheRuleRealm.self, forPrimaryKey: ruleId) {
                    realmRule.isEnabled = enabled
                    invalidateCache()
                    WebBridgeLogger.shared.info("Updated rule \(ruleId): enabled=\(enabled)")
                    updated = true
                }
            }
            return updated
        } catch {
            WebBridgeLogger.shared.error("Failed to update rule: \(error.localizedDescription)")
            return false
        }
    }

    /// 清空所有规则
    public func clearAllRules() -> Bool {
        do {
            let realm = getRealm()
            try realm.write {
                realm.delete(realm.objects(CacheRuleRealm.self))
                invalidateCache()
                WebBridgeLogger.shared.info("Cleared all cache rules")
            }
            return true
        } catch {
            WebBridgeLogger.shared.error("Failed to clear rules: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Rule Matching

    /// 检查 URL 是否应该被缓存
    public func shouldCache(url: URL) -> (shouldCache: Bool, matchedRule: CacheRule?) {
        let enabledRules = getEnabledRules()

        // 按优先级从高到低检查
        for rule in enabledRules {
            if rule.matches(url: url) {
                return (true, rule)
            }
        }

        return (false, nil)
    }

    /// 获取匹配 URL 的规则
    public func getMatchedRule(for url: URL) -> CacheRule? {
        return shouldCache(url: url).matchedRule
    }

    /// 获取规则匹配的所有缓存条目
    public func getCacheEntries(for rule: CacheRule) -> Observable<[CacheEntryInfo]> {
        return Observable.create { observer in
            let entries = WebCompressedCacheStore.shared.getAllEntries()

            let matchedEntries = entries.filter { entry in
                guard let url = URL(string: entry.url) else { return false }
                return rule.matches(url: url)
            }

            observer.onNext(matchedEntries)
            observer.onCompleted()
            return Disposables.create()
        }
    }

    /// 按规则删除缓存
    public func deleteCacheByRule(rule: CacheRule) -> Observable<Int> {
        return Observable.create { observer in
            do {
                var deletedCount = 0

                switch rule.type {
                case .domain:
                    // 域名类型：转换为 glob 模式
                    let globPattern = "https://\(rule.pattern)/**"
                    deletedCount = try WebCompressedCacheStore.shared.deleteByGlob(pattern: globPattern)

                case .glob:
                    // 直接使用 glob 模式
                    deletedCount = try WebCompressedCacheStore.shared.deleteByGlob(pattern: rule.pattern)

                case .regex:
                    // 正则表达式：需要遍历所有缓存条目
                    let entries = WebCompressedCacheStore.shared.getAllEntries()
                    for entry in entries {
                        if let url = URL(string: entry.url) {
                            if rule.matches(url: url) {
                                if WebCompressedCacheStore.shared.delete(key: entry.key) {
                                    deletedCount += 1
                                }
                            }
                        }
                    }

                case .exact:
                    // 精确匹配
                    if let entry = WebCompressedCacheStore.shared.getAllEntries().first(where: { $0.url == rule.pattern }) {
                        if WebCompressedCacheStore.shared.delete(key: entry.key) {
                            deletedCount = 1
                        }
                    }
                }

                WebBridgeLogger.shared.info("Deleted \(deletedCount) entries for rule: \(rule.name)")
                observer.onNext(deletedCount)
                observer.onCompleted()
            } catch {
                observer.onError(error)
            }

            return Disposables.create()
        }
    }

    // MARK: - Preset Rules

    /// 检查并添加预设规则
    private func checkAndAddPresetRules() {
        let existingIds = Set(getRealm().objects(CacheRuleRealm.self).map { $0.id })

        for presetRule in CacheRule.presetRules {
            if !existingIds.contains(presetRule.id) {
                _ = addRule(presetRule)
            }
        }
    }

    /// 重置为预设规则
    public func resetToPresetRules() -> Bool {
        clearAllRules()
        return addRules(CacheRule.presetRules) == CacheRule.presetRules.count
    }

    // MARK: - Cache

    private func invalidateCache() {
        cacheLock.lock()
        rulesCache.removeAll()
        cacheLock.unlock()
    }
}

// MARK: - Realm Model

class CacheRuleRealm: Object {
    @objc dynamic public var id: String = UUID().uuidString
    @objc dynamic public var name: String = ""
    @objc dynamic public var typeRaw: String = CacheRuleType.domain.rawValue
    @objc dynamic public var resourceTypeRaw: String = CacheResourceType.staticResource.rawValue
    @objc dynamic public var pattern: String = ""
    @objc dynamic public var isEnabled: Bool = true
    @objc dynamic public var createdAt: Date = Date()
    @objc dynamic public var priority: Int = 0

    override public class func primaryKey() -> String? {
        return "id"
    }

    public var type: CacheRuleType {
        get { return CacheRuleType(rawValue: typeRaw) ?? .domain }
        set { typeRaw = newValue.rawValue }
    }

    public var resourceType: CacheResourceType {
        get { return CacheResourceType(rawValue: resourceTypeRaw) ?? .staticResource }
        set { resourceTypeRaw = newValue.rawValue }
    }

    convenience init(from rule: CacheRule) {
        self.init()
        self.id = rule.id
        self.name = rule.name
        self.type = rule.type
        self.resourceType = rule.resourceType
        self.pattern = rule.pattern
        self.isEnabled = rule.isEnabled
        self.createdAt = rule.createdAt
        self.priority = rule.priority
    }

    func toCacheRule() -> CacheRule {
        return CacheRule(
            id: id,
            name: name,
            type: type,
            pattern: pattern,
            resourceType: resourceType,
            isEnabled: isEnabled,
            priority: priority
        )
    }
}
