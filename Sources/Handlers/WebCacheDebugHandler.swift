//
//  WebCacheDebugHandler.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-23.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import UIKit
import WebKit

// Framework imports

/// 缓存调试 Handler
/// 提供 JS Bridge API 用于查询和管理压缩缓存、页面级离线缓存
public class WebCacheDebugHandler: BaseWebNativeHandler {

    // MARK: - Handle Method

    public override func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
        // 从 params 中获取参数，兼容直接在 body 中传参的情况
        let params = body["params"] as? [String: Any] ?? body
        let action = params["action"] as? String ?? ""

        switch action {
        // MARK: - 压缩缓存相关 (保留)
        case "getInfo", "getCacheInfo":
            getCacheInfo(completion: completion)
        case "getMemoryInfo":
            getMemoryInfo(completion: completion)
        case "getEntries":
            let filter = params["filter"] as? String
            getEntries(filter: filter, completion: completion)
        case "getEntriesGroupedByDomain":
            getEntriesGroupedByDomain(completion: completion)
        case "isCached":
            if let urlString = params["url"] as? String,
               let url = URL(string: urlString) {
                checkIsCached(url: url, completion: completion)
            } else {
                reject(error: "Invalid URL", completion: completion)
            }
        case "deleteByPattern", "deleteByGlob":
            if let pattern = params["pattern"] as? String {
                deleteByPattern(pattern: pattern, completion: completion)
            } else {
                reject(error: "Pattern is required", completion: completion)
            }
        case "deleteByKey":
            if let key = params["key"] as? String {
                deleteByKey(key: key, completion: completion)
            } else {
                reject(error: "Key is required", completion: completion)
            }
        case "clearAll":
            clearAll(completion: completion)
        case "getConfig":
            getConfig(completion: completion)
        case "setConfig":
            if let configParams = params["config"] as? [String: Any] {
                setConfig(configParams: configParams, completion: completion)
            } else {
                reject(error: "Config is required", completion: completion)
            }

        // MARK: - 页面缓存规则管理
        case "getPageRules":
            getPageRules(completion: completion)
        case "addPageRule":
            if let ruleParams = params["rule"] as? [String: Any] {
                addPageRule(ruleParams: ruleParams, completion: completion)
            } else {
                reject(error: "Rule is required", completion: completion)
            }
        case "updatePageRule":
            if let ruleParams = params["rule"] as? [String: Any] {
                updatePageRule(ruleParams: ruleParams, completion: completion)
            } else {
                reject(error: "Rule is required", completion: completion)
            }
        case "deletePageRule":
            if let ruleId = params["ruleId"] as? String {
                deletePageRule(ruleId: ruleId, completion: completion)
            } else {
                reject(error: "Rule ID is required", completion: completion)
            }
        case "clearAllPageRules":
            clearAllPageRules(completion: completion)
        case "resetToPresetPageRules":
            resetToPresetPageRules(completion: completion)
        case "addExcludePattern":
            if let ruleId = params["ruleId"] as? String,
               let pattern = params["pattern"] as? String {
                addExcludePattern(ruleId: ruleId, pattern: pattern, completion: completion)
            } else {
                reject(error: "Rule ID and pattern are required", completion: completion)
            }
        case "removeExcludePattern":
            if let ruleId = params["ruleId"] as? String,
               let pattern = params["pattern"] as? String {
                removeExcludePattern(ruleId: ruleId, pattern: pattern, completion: completion)
            } else {
                reject(error: "Rule ID and pattern are required", completion: completion)
            }

        // MARK: - 页面缓存操作
        case "getCachedPages":
            let ruleId = params["ruleId"] as? String
            getCachedPages(ruleId: ruleId, completion: completion)
        case "cachePage":
            if let urlString = params["url"] as? String,
               let url = URL(string: urlString),
               let ruleId = params["ruleId"] as? String {
                cachePage(url: url, ruleId: ruleId, completion: completion)
            } else {
                reject(error: "URL and ruleId are required", completion: completion)
            }
        case "refreshCachedPage":
            if let pageId = params["pageId"] as? String {
                refreshCachedPage(pageId: pageId, completion: completion)
            } else {
                reject(error: "Page ID is required", completion: completion)
            }
        case "deleteCachedPage":
            if let pageId = params["pageId"] as? String {
                deleteCachedPage(pageId: pageId, completion: completion)
            } else {
                reject(error: "Page ID is required", completion: completion)
            }

        // MARK: - 旧系统规则管理 (保留向后兼容)
        case "getRules":
            getRules(completion: completion)
        case "addRule":
            if let ruleParams = params["rule"] as? [String: Any] {
                addRule(ruleParams: ruleParams, completion: completion)
            } else {
                reject(error: "Rule is required", completion: completion)
            }
        case "updateRule":
            if let ruleId = params["ruleId"] as? String {
                let enabled = params["enabled"] as? Bool
                updateRule(ruleId: ruleId, enabled: enabled, completion: completion)
            } else {
                reject(error: "Rule ID is required", completion: completion)
            }
        case "deleteRule":
            if let ruleId = params["ruleId"] as? String {
                deleteRule(ruleId: ruleId, completion: completion)
            } else {
                reject(error: "Rule ID is required", completion: completion)
            }
        case "clearAllRules":
            clearAllRules(completion: completion)
        case "resetToPresetRules":
            resetToPresetRules(completion: completion)
        case "getRuleCache":
            if let ruleId = params["ruleId"] as? String {
                getRuleCache(ruleId: ruleId, completion: completion)
            } else {
                reject(error: "Rule ID is required", completion: completion)
            }
        case "deleteRuleCache":
            if let ruleId = params["ruleId"] as? String {
                deleteRuleCache(ruleId: ruleId, completion: completion)
            } else {
                reject(error: "Rule ID is required", completion: completion)
            }
        default:
            reject(error: "Unknown action: \(action)", completion: completion)
        }
    }

    // MARK: - 压缩缓存方法 (保留)

    /// 获取缓存信息
    private func getCacheInfo(completion: @escaping (Any) -> Void) {
        let memoryInfo = WebCompressedCacheStore.shared.getMemoryInfo()
        let entries = WebCompressedCacheStore.shared.getAllEntries()

        // 按域名统计
        let domainStats = Dictionary(grouping: entries) { $0.domain }
            .mapValues { entries in
                let totalOriginalSize = entries.reduce(0) { $0 + $1.originalSize }
                let totalCompressedSize = entries.reduce(0) { $0 + $1.compressedSize }
                return [
                    "count": entries.count,
                    "originalSize": totalOriginalSize,
                    "compressedSize": totalCompressedSize,
                    "savedSpace": totalOriginalSize - totalCompressedSize
                ]
            }

        let result: [String: Any] = [
            "success": true,
            "data": [
                "totalEntries": memoryInfo.totalEntries,
                "totalOriginalSize": memoryInfo.totalOriginalSize,
                "totalCompressedSize": memoryInfo.totalCompressedSize,
                "compressionRatio": memoryInfo.compressionRatio,
                "savedSpace": memoryInfo.savedSpace,
                "formattedTotalOriginalSize": memoryInfo.formattedTotalOriginalSize,
                "formattedTotalCompressedSize": memoryInfo.formattedTotalCompressedSize,
                "formattedSavedSpace": memoryInfo.formattedSavedSpace,
                "formattedCompressionRatio": memoryInfo.formattedCompressionRatio,
                "domainStats": domainStats
            ]
        ]

        resolve(result, completion: completion)
    }

    /// 获取内存信息
    private func getMemoryInfo(completion: @escaping (Any) -> Void) {
        let memoryInfo = WebCompressedCacheStore.shared.getMemoryInfo()

        let result: [String: Any] = [
            "success": true,
            "data": [
                "totalEntries": memoryInfo.totalEntries,
                "totalOriginalSize": memoryInfo.totalOriginalSize,
                "totalCompressedSize": memoryInfo.totalCompressedSize,
                "compressionRatio": memoryInfo.compressionRatio,
                "savedSpace": memoryInfo.savedSpace,
                "formattedTotalOriginalSize": memoryInfo.formattedTotalOriginalSize,
                "formattedTotalCompressedSize": memoryInfo.formattedTotalCompressedSize,
                "formattedSavedSpace": memoryInfo.formattedSavedSpace,
                "formattedCompressionRatio": memoryInfo.formattedCompressionRatio
            ]
        ]

        resolve(result, completion: completion)
    }

    /// 获取缓存条目列表
    private func getEntries(filter: String?, completion: @escaping (Any) -> Void) {
        var entries = WebCompressedCacheStore.shared.getAllEntries()

        // 应用过滤
        if let pattern = filter {
            entries = entries.filter { GlobPattern.matches(pattern, against: $0.url) }
        }

        let result: [String: Any] = [
            "success": true,
            "data": [
                "count": entries.count,
                "entries": entries.map { $0.toDictionary() }
            ]
        ]

        resolve(result, completion: completion)
    }

    /// 按域名分组获取缓存条目
    private func getEntriesGroupedByDomain(completion: @escaping (Any) -> Void) {
        let groupedEntries = WebCompressedCacheStore.shared.getEntriesGroupedByDomain()

        let result: [String: Any] = [
            "success": true,
            "data": [
                "domains": groupedEntries.mapValues { entries in
                    entries.map { $0.toDictionary() }
                }
            ]
        ]

        resolve(result, completion: completion)
    }

    /// 检查 URL 是否已缓存
    private func checkIsCached(url: URL, completion: @escaping (Any) -> Void) {
        let key = url.sha256
        let isCached = WebCompressedCacheStore.shared.exists(key: key)
        let info = WebCompressedCacheStore.shared.getEntryInfo(key: key)

        var result: [String: Any] = [
            "success": true,
            "url": url.absoluteString,
            "cached": isCached
        ]

        if let info = info {
            result["info"] = info.toDictionary()
        }

        resolve(result, completion: completion)
    }

    /// 按 Glob 模式删除缓存
    private func deleteByPattern(pattern: String, completion: @escaping (Any) -> Void) {
        do {
            let deletedCount = try WebCompressedCacheStore.shared.deleteByGlob(pattern: pattern)

            let result: [String: Any] = [
                "success": true,
                "deletedCount": deletedCount,
                "pattern": pattern
            ]

            resolve(result, completion: completion)
        } catch {
            reject(error: "Delete failed: \(error.localizedDescription)", completion: completion)
        }
    }

    /// 按键删除缓存
    private func deleteByKey(key: String, completion: @escaping (Any) -> Void) {
        let success = WebCompressedCacheStore.shared.delete(key: key)

        let result: [String: Any] = [
            "success": success,
            "key": key
        ]

        if success {
            resolve(result, completion: completion)
        } else {
            reject(error: "Cache entry not found", completion: completion)
        }
    }

    /// 清空所有缓存
    private func clearAll(completion: @escaping (Any) -> Void) {
        WebCompressedCacheStore.shared.clearAll()

        let result: [String: Any] = [
            "success": true,
            "message": "All cache cleared"
        ]

        resolve(result, completion: completion)
    }

    /// 获取当前配置
    private func getConfig(completion: @escaping (Any) -> Void) {
        let config = WebCompressedCacheStore.shared.config

        let result: [String: Any] = [
            "success": true,
            "config": [
                "enableCompression": config.enableCompression,
                "compressionThreshold": config.compressionThreshold,
                "compressionLevel": config.compressionLevel,
                "maxCacheSize": config.maxCacheSize,
                "maxFileSize": config.maxFileSize,
                "formattedMaxCacheSize": ByteCountFormatter.string(fromByteCount: config.maxCacheSize, countStyle: .file),
                "formattedMaxFileSize": ByteCountFormatter.string(fromByteCount: Int64(config.maxFileSize), countStyle: .file)
            ]
        ]

        resolve(result, completion: completion)
    }

    /// 更新配置
    private func setConfig(configParams: [String: Any], completion: @escaping (Any) -> Void) {
        var config = WebCompressedCacheStore.shared.config

        if let enableCompression = configParams["enableCompression"] as? Bool {
            config.enableCompression = enableCompression
        }

        if let compressionThreshold = configParams["compressionThreshold"] as? Int {
            config.compressionThreshold = compressionThreshold
        }

        if let compressionLevel = configParams["compressionLevel"] as? Int {
            config.compressionLevel = min(9, max(0, compressionLevel))
        }

        if let maxCacheSize = configParams["maxCacheSize"] as? Int64 {
            config.maxCacheSize = maxCacheSize
        }

        if let maxFileSize = configParams["maxFileSize"] as? Int {
            config.maxFileSize = maxFileSize
        }

        WebCompressedCacheStore.shared.config = config

        let result: [String: Any] = [
            "success": true,
            "message": "Config updated",
            "config": [
                "enableCompression": config.enableCompression,
                "compressionThreshold": config.compressionThreshold,
                "compressionLevel": config.compressionLevel,
                "maxCacheSize": config.maxCacheSize,
                "maxFileSize": config.maxFileSize
            ]
        ]

        resolve(result, completion: completion)
    }

    // MARK: - 页面缓存规则管理方法 (新系统)

    /// 获取所有页面缓存规则
    private func getPageRules(completion: @escaping (Any) -> Void) {
        let rules = PageCacheRuleManager.shared.getAllRules()
        let rulesArray = rules.map { rule -> [String: Any] in
            [
                "id": rule.id,
                "name": rule.name,
                "includePatterns": rule.includePatterns,
                "excludePatterns": rule.excludePatterns,
                "isEnabled": rule.isEnabled,
                "createdAt": rule.createdAt.timeIntervalSince1970,
                "lastCachedAt": rule.lastCachedAt?.timeIntervalSince1970 ?? NSNull(),
                "displayDescription": rule.displayDescription
            ]
        }

        let result: [String: Any] = [
            "success": true,
            "rules": rulesArray,
            "count": rulesArray.count
        ]

        resolve(result, completion: completion)
    }

    /// 添加页面缓存规则
    private func addPageRule(ruleParams: [String: Any], completion: @escaping (Any) -> Void) {
        guard let name = ruleParams["name"] as? String,
              let includePatterns = ruleParams["includePatterns"] as? [String] else {
            reject(error: "Invalid rule parameters: name and includePatterns are required", completion: completion)
            return
        }

        let excludePatterns = ruleParams["excludePatterns"] as? [String] ?? []
        let isEnabled = ruleParams["isEnabled"] as? Bool ?? true

        let rule = PageCacheRule(
            id: UUID().uuidString,
            name: name,
            includePatterns: includePatterns,
            excludePatterns: excludePatterns,
            isEnabled: isEnabled,
            createdAt: Date(),
            lastCachedAt: nil
        )

        let success = PageCacheRuleManager.shared.addRule(rule)

        let result: [String: Any] = [
            "success": success,
            "message": success ? "Page cache rule added" : "Failed to add rule",
            "rule": [
                "id": rule.id,
                "name": rule.name,
                "includePatterns": rule.includePatterns,
                "excludePatterns": rule.excludePatterns,
                "isEnabled": rule.isEnabled,
                "displayDescription": rule.displayDescription
            ]
        ]

        resolve(result, completion: completion)
    }

    /// 更新页面缓存规则
    private func updatePageRule(ruleParams: [String: Any], completion: @escaping (Any) -> Void) {
        guard let ruleId = ruleParams["id"] as? String,
              let name = ruleParams["name"] as? String else {
            reject(error: "Invalid rule parameters: id and name are required", completion: completion)
            return
        }

        let includePatterns = ruleParams["includePatterns"] as? [String] ?? []
        let excludePatterns = ruleParams["excludePatterns"] as? [String] ?? []
        let isEnabled = ruleParams["isEnabled"] as? Bool ?? true

        // 获取现有规则以保留 createdAt
        let existingRules = PageCacheRuleManager.shared.getAllRules()
        guard let existingRule = existingRules.first(where: { $0.id == ruleId }) else {
            reject(error: "Rule not found", completion: completion)
            return
        }

        var updatedRule = PageCacheRule(
            id: ruleId,
            name: name,
            includePatterns: includePatterns,
            excludePatterns: excludePatterns,
            isEnabled: isEnabled,
            createdAt: existingRule.createdAt,
            lastCachedAt: existingRule.lastCachedAt
        )

        let success = PageCacheRuleManager.shared.updateRule(updatedRule)

        let result: [String: Any] = [
            "success": success,
            "message": success ? "Page cache rule updated" : "Failed to update rule",
            "rule": [
                "id": updatedRule.id,
                "name": updatedRule.name,
                "includePatterns": updatedRule.includePatterns,
                "excludePatterns": updatedRule.excludePatterns,
                "isEnabled": updatedRule.isEnabled
            ]
        ]

        resolve(result, completion: completion)
    }

    /// 删除页面缓存规则
    private func deletePageRule(ruleId: String, completion: @escaping (Any) -> Void) {
        let success = PageCacheRuleManager.shared.deleteRule(ruleId: ruleId)

        let result: [String: Any] = [
            "success": success,
            "message": success ? "Page cache rule deleted" : "Failed to delete rule",
            "ruleId": ruleId
        ]

        resolve(result, completion: completion)
    }

    /// 清空所有页面缓存规则
    private func clearAllPageRules(completion: @escaping (Any) -> Void) {
        let success = PageCacheRuleManager.shared.clearAllRules()

        let result: [String: Any] = [
            "success": success,
            "message": success ? "All page cache rules cleared" : "Failed to clear rules"
        ]

        resolve(result, completion: completion)
    }

    /// 重置为预设页面缓存规则
    private func resetToPresetPageRules(completion: @escaping (Any) -> Void) {
        let success = PageCacheRuleManager.shared.resetToPresetRules()

        let result: [String: Any] = [
            "success": success,
            "message": success ? "Reset to preset page cache rules" : "Failed to reset rules"
        ]

        resolve(result, completion: completion)
    }

    /// 添加排除模式
    private func addExcludePattern(ruleId: String, pattern: String, completion: @escaping (Any) -> Void) {
        let rules = PageCacheRuleManager.shared.getAllRules()
        guard let existingRule = rules.first(where: { $0.id == ruleId }) else {
            reject(error: "Rule not found", completion: completion)
            return
        }

        var updatedRule = existingRule
        updatedRule.excludePatterns.append(pattern)

        let success = PageCacheRuleManager.shared.updateRule(updatedRule)

        let result: [String: Any] = [
            "success": success,
            "message": success ? "Exclude pattern added" : "Failed to add exclude pattern",
            "ruleId": ruleId,
            "pattern": pattern,
            "excludePatterns": updatedRule.excludePatterns
        ]

        resolve(result, completion: completion)
    }

    /// 移除排除模式
    private func removeExcludePattern(ruleId: String, pattern: String, completion: @escaping (Any) -> Void) {
        let rules = PageCacheRuleManager.shared.getAllRules()
        guard let existingRule = rules.first(where: { $0.id == ruleId }) else {
            reject(error: "Rule not found", completion: completion)
            return
        }

        var updatedRule = existingRule
        updatedRule.excludePatterns.removeAll { $0 == pattern }

        let success = PageCacheRuleManager.shared.updateRule(updatedRule)

        let result: [String: Any] = [
            "success": success,
            "message": success ? "Exclude pattern removed" : "Failed to remove exclude pattern",
            "ruleId": ruleId,
            "pattern": pattern,
            "excludePatterns": updatedRule.excludePatterns
        ]

        resolve(result, completion: completion)
    }

    // MARK: - 页面缓存操作方法 (新系统)

    /// 获取已缓存的页面
    private func getCachedPages(ruleId: String?, completion: @escaping (Any) -> Void) {
        let pages: [CachedPageInfo]

        if let ruleId = ruleId {
            pages = WebPageOfflineCacheManager.shared.getCachedPages(for: ruleId)
        } else {
            pages = WebPageOfflineCacheManager.shared.getCachedPages()
        }

        let pagesArray = pages.map { page -> [String: Any] in
            [
                "id": page.id,
                "url": page.url,
                "title": page.title,
                "ruleId": page.ruleId,
                "ruleName": page.ruleName,
                "resourceCount": page.resourceCount,
                "totalSize": page.totalSize,
                "formattedSize": ByteCountFormatter.string(fromByteCount: page.totalSize, countStyle: .file),
                "cachedAt": page.cachedAt.timeIntervalSince1970,
                "isOfflineAvailable": page.isOfflineAvailable,
                "isExcluded": page.isExcluded
            ]
        }

        let result: [String: Any] = [
            "success": true,
            "pages": pagesArray,
            "count": pagesArray.count
        ]

        resolve(result, completion: completion)
    }

    /// 缓存指定页面
    private func cachePage(url: URL, ruleId: String, completion: @escaping (Any) -> Void) {
        let rules = PageCacheRuleManager.shared.getAllRules()
        guard let rule = rules.first(where: { $0.id == ruleId }) else {
            reject(error: "Rule not found", completion: completion)
            return
        }

        // 异步缓存操作
        WebPageOfflineCacheManager.shared.cachePage(
            url: url,
            rule: rule,
            progress: { _ in },
            completion: { result in
            switch result {
            case .success(let pageInfo):
                let response: [String: Any] = [
                    "success": true,
                    "message": "Page cached successfully",
                    "page": [
                        "id": pageInfo.id,
                        "url": pageInfo.url,
                        "title": pageInfo.title,
                        "ruleId": pageInfo.ruleId,
                        "ruleName": pageInfo.ruleName,
                        "resourceCount": pageInfo.resourceCount,
                        "totalSize": pageInfo.totalSize,
                        "formattedSize": ByteCountFormatter.string(fromByteCount: pageInfo.totalSize, countStyle: .file),
                        "cachedAt": pageInfo.cachedAt.timeIntervalSince1970,
                        "isOfflineAvailable": pageInfo.isOfflineAvailable
                    ]
                ]
                self.resolve(response, completion: completion)

            case .failure(let error):
                self.reject(error: "Failed to cache page: \(error.localizedDescription)", completion: completion)
            }
        })
    }

    /// 刷新已缓存的页面
    private func refreshCachedPage(pageId: String, completion: @escaping (Any) -> Void) {
        WebPageOfflineCacheManager.shared.refreshCachedPage(
            pageId: pageId,
            progress: { _ in },
            completion: { result in
            switch result {
            case .success:
                let response: [String: Any] = [
                    "success": true,
                    "message": "Page refreshed successfully",
                    "pageId": pageId
                ]
                self.resolve(response, completion: completion)

            case .failure(let error):
                self.reject(error: "Failed to refresh page: \(error.localizedDescription)", completion: completion)
            }
        })
    }

    /// 删除已缓存的页面
    private func deleteCachedPage(pageId: String, completion: @escaping (Any) -> Void) {
        let success = WebPageOfflineCacheManager.shared.deleteCachedPage(pageId: pageId)

        let result: [String: Any] = [
            "success": success,
            "message": success ? "Page cache deleted" : "Failed to delete page cache",
            "pageId": pageId
        ]

        if success {
            resolve(result, completion: completion)
        } else {
            reject(error: "Page cache not found", completion: completion)
        }
    }

    // MARK: - 旧系统规则管理方法 (保留向后兼容)

    /// 获取所有规则 (旧系统 - 保留向后兼容)
    private func getRules(completion: @escaping (Any) -> Void) {
        let rules = CacheRuleManager.shared.getAllRules()
        let rulesArray = rules.map { rule -> [String: Any] in
            [
                "id": rule.id,
                "name": rule.name,
                "type": rule.type.rawValue,
                "pattern": rule.pattern,
                "resourceType": rule.resourceType.rawValue,
                "isEnabled": rule.isEnabled,
                "priority": rule.priority,
                "displayDescription": rule.displayDescription
            ]
        }

        let result: [String: Any] = [
            "success": true,
            "rules": rulesArray,
            "count": rulesArray.count,
            "notice": "This API uses the old CacheRule system. Consider migrating to PageCacheRule."
        ]

        resolve(result, completion: completion)
    }

    /// 添加规则 (旧系统 - 保留向后兼容)
    private func addRule(ruleParams: [String: Any], completion: @escaping (Any) -> Void) {
        guard let name = ruleParams["name"] as? String,
              let typeRaw = ruleParams["type"] as? String,
              let pattern = ruleParams["pattern"] as? String,
              let type = CacheRuleType(rawValue: typeRaw) else {
            reject(error: "Invalid rule parameters", completion: completion)
            return
        }

        let priority = ruleParams["priority"] as? Int ?? 0
        let isEnabled = ruleParams["isEnabled"] as? Bool ?? true
        let resourceTypeRaw = ruleParams["resourceType"] as? String ?? CacheResourceType.staticResource.rawValue
        let resourceType = CacheResourceType(rawValue: resourceTypeRaw) ?? .staticResource

        let rule = CacheRule(
            name: name,
            type: type,
            pattern: pattern,
            resourceType: resourceType,
            isEnabled: isEnabled,
            priority: priority
        )

        CacheRuleManager.shared.addRule(rule)

        let result: [String: Any] = [
            "success": true,
            "message": "Rule added (using old CacheRule system)",
            "rule": [
                "id": rule.id,
                "name": rule.name,
                "type": rule.type.rawValue,
                "pattern": rule.pattern,
                "resourceType": rule.resourceType.rawValue,
                "isEnabled": rule.isEnabled,
                "priority": rule.priority
            ]
        ]

        resolve(result, completion: completion)
    }

    /// 更新规则状态 (旧系统 - 保留向后兼容)
    private func updateRule(ruleId: String, enabled: Bool?, completion: @escaping (Any) -> Void) {
        // 如果 enabled 为 nil，则只检查规则是否存在
        if let enabled = enabled {
            CacheRuleManager.shared.updateRule(id: ruleId, enabled: enabled)
            let result: [String: Any] = [
                "success": true,
                "message": "Rule updated (using old CacheRule system)",
                "ruleId": ruleId,
                "isEnabled": enabled
            ]
            resolve(result, completion: completion)
        } else {
            // 仅检查规则是否存在
            let rules = CacheRuleManager.shared.getAllRules()
            let exists = rules.contains { $0.id == ruleId }
            let result: [String: Any] = [
                "success": true,
                "exists": exists,
                "ruleId": ruleId
            ]
            resolve(result, completion: completion)
        }
    }

    /// 删除规则 (旧系统 - 保留向后兼容)
    private func deleteRule(ruleId: String, completion: @escaping (Any) -> Void) {
        let success = CacheRuleManager.shared.deleteRule(ruleId: ruleId)

        let result: [String: Any] = [
            "success": success,
            "message": success ? "Rule deleted (using old CacheRule system)" : "Failed to delete rule",
            "ruleId": ruleId
        ]

        resolve(result, completion: completion)
    }

    /// 清空所有规则 (旧系统 - 保留向后兼容)
    private func clearAllRules(completion: @escaping (Any) -> Void) {
        CacheRuleManager.shared.clearAllRules()

        let result: [String: Any] = [
            "success": true,
            "message": "All rules cleared (using old CacheRule system)"
        ]

        resolve(result, completion: completion)
    }

    /// 重置为预设规则 (旧系统 - 保留向后兼容)
    private func resetToPresetRules(completion: @escaping (Any) -> Void) {
        let success = CacheRuleManager.shared.resetToPresetRules()

        let result: [String: Any] = [
            "success": success,
            "message": success ? "Reset to preset rules (using old CacheRule system)" : "Failed to reset rules"
        ]

        resolve(result, completion: completion)
    }

    /// 获取规则匹配的缓存条目 (旧系统 - 保留向后兼容)
    private func getRuleCache(ruleId: String, completion: @escaping (Any) -> Void) {
        let rules = CacheRuleManager.shared.getAllRules()
        guard let rule = rules.first(where: { $0.id == ruleId }) else {
            reject(error: "Rule not found", completion: completion)
            return
        }

        let entries = WebCompressedCacheStore.shared.getAllEntries().filter { entry in
            guard let url = URL(string: entry.url) else { return false }
            return rule.matches(url: url)
        }

        let entriesArray = entries.map { entry -> [String: Any] in
            [
                "key": entry.key,
                "url": entry.url,
                "domain": entry.domain,
                "originalSize": entry.originalSize,
                "compressedSize": entry.compressedSize,
                "compressionRatio": entry.compressionRatio,
                "mimeType": entry.mimeType,
                "createdAt": entry.createdAt.timeIntervalSince1970,
                "lastAccessedAt": entry.lastAccessedAt.timeIntervalSince1970,
                "accessCount": entry.accessCount
            ]
        }

        let result: [String: Any] = [
            "success": true,
            "ruleId": ruleId,
            "ruleName": rule.name,
            "count": entriesArray.count,
            "entries": entriesArray
        ]

        resolve(result, completion: completion)
    }

    /// 删除规则匹配的缓存 (旧系统 - 保留向后兼容)
    private func deleteRuleCache(ruleId: String, completion: @escaping (Any) -> Void) {
        let rules = CacheRuleManager.shared.getAllRules()
        guard let rule = rules.first(where: { $0.id == ruleId }) else {
            reject(error: "Rule not found", completion: completion)
            return
        }

        let success = CacheRuleManager.shared.deleteCacheByRule(rule: rule)

        let result: [String: Any] = [
            "success": success,
            "ruleId": ruleId,
            "ruleName": rule.name,
            "message": success ? "Rule cache deleted (using old CacheRule system)" : "Failed to delete rule cache"
        ]

        resolve(result, completion: completion)
    }
}
