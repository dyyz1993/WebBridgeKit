//
//  PageCacheRuleManager.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-23.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import RealmSwift
import RxSwift

/// 页面缓存规则管理器
public class PageCacheRuleManager {

    public static let shared = PageCacheRuleManager()

    private let realmConfiguration: Realm.Configuration
    private var rulesCache: [String: [PageCacheRule]] = [:]
    private let cacheLock = NSLock()

    private init() {
        // 配置 Realm - 使用独立的文件以避免与其他 Realm 冲突
        self.realmConfiguration = Realm.Configuration(
            fileURL: Realm.Configuration.defaultConfiguration.fileURL?.deletingLastPathComponent().appendingPathComponent("pageCacheRules.realm"),
            schemaVersion: 2,  // 新版本号
            migrationBlock: { migration, oldSchemaVersion in
                if oldSchemaVersion < 2 {
                    // 从旧版本迁移
                    // 可以选择保留或删除旧的 CacheRule 数据
                }
            }
        )

        // 检查并添加预设规则
        checkAndAddPresetRules()
    }

    /// 获取 Realm 实例
    private func getRealm() -> Realm {
        do {
            return try Realm(configuration: realmConfiguration)
        } catch {
            WebBridgeLogger.shared.error("Realm init failed: \(error.localizedDescription)")

            // If Realm fails, delete the old file and try again
            let config = realmConfiguration
            if let fileURL = config.fileURL {
                try? FileManager.default.removeItem(at: fileURL)
            }

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
    public func getAllRules() -> [PageCacheRule] {
        return Array(getRealm().objects(PageCacheRuleRealm.self))
            .sorted { $0.createdAt > $1.createdAt }
            .map { $0.toPageCacheRule() }
    }

    /// 获取启用的规则
    public func getEnabledRules() -> [PageCacheRule] {
        return getRealm().objects(PageCacheRuleRealm.self)
            .filter("isEnabled == true")
            .sorted { $0.createdAt > $1.createdAt }
            .map { $0.toPageCacheRule() }
    }

    /// 添加规则
    public func addRule(_ rule: PageCacheRule) -> Bool {
        do {
            let realm = getRealm()
            try realm.write {
                let realmRule = PageCacheRuleRealm(from: rule)
                realm.add(realmRule, update: .all)
            }
            invalidateCache()
            WebBridgeLogger.shared.info("Added page cache rule: \(rule.name)")
            return true
        } catch {
            WebBridgeLogger.shared.error("Failed to add rule: \(error.localizedDescription)")
            return false
        }
    }

    /// 批量添加规则
    public func addRules(_ rules: [PageCacheRule]) -> Int {
        var addedCount = 0
        for rule in rules {
            if addRule(rule) {
                addedCount += 1
            }
        }
        return addedCount
    }

    /// 更新规则
    public func updateRule(_ rule: PageCacheRule) -> Bool {
        do {
            let realm = getRealm()
            try realm.write {
                let realmRule = PageCacheRuleRealm(from: rule)
                realm.add(realmRule, update: .all)
            }
            invalidateCache()
            WebBridgeLogger.shared.info("Updated page cache rule: \(rule.name)")
            return true
        } catch {
            WebBridgeLogger.shared.error("Failed to update rule: \(error.localizedDescription)")
            return false
        }
    }

    /// 删除规则
    public func deleteRule(ruleId: String) -> Bool {
        do {
            let realm = getRealm()
            var deleted = false
            try realm.write {
                if let realmRule = realm.object(ofType: PageCacheRuleRealm.self, forPrimaryKey: ruleId) {
                    realm.delete(realmRule)
                    invalidateCache()
                    WebBridgeLogger.shared.info("Deleted page cache rule: \(ruleId)")
                    deleted = true
                }
            }
            return deleted
        } catch {
            WebBridgeLogger.shared.error("Failed to delete rule: \(error.localizedDescription)")
            return false
        }
    }

    /// 清空所有规则
    public func clearAllRules() -> Bool {
        do {
            let realm = getRealm()
            try realm.write {
                realm.delete(realm.objects(PageCacheRuleRealm.self))
                invalidateCache()
                WebBridgeLogger.shared.info("Cleared all page cache rules")
            }
            return true
        } catch {
            WebBridgeLogger.shared.error("Failed to clear rules: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Rule Matching

    /// 检查 URL 是否应该被缓存
    public func shouldCache(url: URL) -> (shouldCache: Bool, matchedRule: PageCacheRule?) {
        let enabledRules = getEnabledRules()

        for rule in enabledRules {
            if rule.matches(url: url) {
                return (true, rule)
            }
        }

        return (false, nil)
    }

    /// 获取匹配 URL 的规则
    public func getMatchedRule(for url: URL) -> PageCacheRule? {
        return shouldCache(url: url).matchedRule
    }

    // MARK: - Cached Pages

    /// 获取规则下的所有缓存页面
    public func getCachedPages(for ruleId: String) -> Observable<[CachedPageInfo]> {
        return Observable.create { observer in
            // 从 WebPageOfflineCacheManager 获取缓存页面
            let pages = WebPageOfflineCacheManager.shared.getCachedPages(for: ruleId)
            observer.onNext(pages)
            observer.onCompleted()
            return Disposables.create()
        }
    }

    /// 获取所有规则及其关联的缓存页面
    public func getRulesWithPages() -> Observable<[RuleWithPages]> {
        return Observable.create { observer in
            let rules = self.getAllRules()
            // 从 WebPageOfflineCacheManager 获取每个规则下的缓存页面
            let rulesWithPages = rules.map { rule in
                let pages = WebPageOfflineCacheManager.shared.getCachedPages(for: rule.id)
                return RuleWithPages(rule: rule, cachedPages: pages, isExpanded: false)
            }
            observer.onNext(rulesWithPages)
            observer.onCompleted()
            return Disposables.create()
        }
    }

    // MARK: - Preset Rules

    /// 检查并添加预设规则
    private func checkAndAddPresetRules() {
        let existingIds = Set(getRealm().objects(PageCacheRuleRealm.self).map { $0.id })

        for presetRule in PageCacheRule.presetRules {
            if !existingIds.contains(presetRule.id) {
                _ = addRule(presetRule)
            }
        }
    }

    /// 重置为预设规则
    public func resetToPresetRules() -> Bool {
        clearAllRules()
        return addRules(PageCacheRule.presetRules) == PageCacheRule.presetRules.count
    }

    // MARK: - Cache

    private func invalidateCache() {
        cacheLock.lock()
        rulesCache.removeAll()
        cacheLock.unlock()
    }
}

// MARK: - Realm Model

class PageCacheRuleRealm: Object {
    @objc dynamic public var id: String = UUID().uuidString
    @objc dynamic public var name: String = ""
    @objc dynamic public var isEnabled: Bool = true
    @objc dynamic public var createdAt: Date = Date()
    @objc dynamic public var lastCachedAt: Date?

    // 存储模式数组（用特定分隔符分隔）
    @objc dynamic public var includePatternsStr: String = ""
    @objc dynamic public var excludePatternsStr: String = ""

    override public class func primaryKey() -> String? {
        return "id"
    }

    /// 数组分隔符
    private static let patternSeparator = "|||"

    /// 包含模式数组
    var includePatterns: [String] {
        get {
            return includePatternsStr.isEmpty ? [] : includePatternsStr.components(separatedBy: Self.patternSeparator)
        }
        set {
            includePatternsStr = newValue.joined(separator: Self.patternSeparator)
        }
    }

    /// 排除模式数组
    var excludePatterns: [String] {
        get {
            return excludePatternsStr.isEmpty ? [] : excludePatternsStr.components(separatedBy: Self.patternSeparator)
        }
        set {
            excludePatternsStr = newValue.joined(separator: Self.patternSeparator)
        }
    }

    convenience init(from rule: PageCacheRule) {
        self.init()
        self.id = rule.id
        self.name = rule.name
        self.isEnabled = rule.isEnabled
        self.createdAt = rule.createdAt
        self.lastCachedAt = rule.lastCachedAt
        self.includePatterns = rule.includePatterns
        self.excludePatterns = rule.excludePatterns
    }

    func toPageCacheRule() -> PageCacheRule {
        return PageCacheRule(
            id: id,
            name: name,
            includePatterns: includePatterns,
            excludePatterns: excludePatterns,
            isEnabled: isEnabled
        )
    }
}
