//
//  PageCacheOperationMethods.swift
//  WebBridgeKit
//
//  页面缓存操作方法 + 旧系统规则管理方法 (向后兼容)
//

import Foundation

extension WebCacheDebugHandler {

    // MARK: - 页面缓存操作方法 (新系统)

    func getCachedPages(ruleId: String?, completion: @escaping (Any) -> Void) {
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

    func cachePage(url: URL, ruleId: String, completion: @escaping (Any) -> Void) {
        let rules = PageCacheRuleManager.shared.getAllRules()
        guard let rule = rules.first(where: { $0.id == ruleId }) else {
            reject(error: "Rule not found", completion: completion)
            return
        }

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

    func refreshCachedPage(pageId: String, completion: @escaping (Any) -> Void) {
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

    func deleteCachedPage(pageId: String, completion: @escaping (Any) -> Void) {
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

    func getRules(completion: @escaping (Any) -> Void) {
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

    func addRule(ruleParams: [String: Any], completion: @escaping (Any) -> Void) {
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

    func updateRule(ruleId: String, enabled: Bool?, completion: @escaping (Any) -> Void) {
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

    func deleteRule(ruleId: String, completion: @escaping (Any) -> Void) {
        let success = CacheRuleManager.shared.deleteRule(ruleId: ruleId)

        let result: [String: Any] = [
            "success": success,
            "message": success ? "Rule deleted (using old CacheRule system)" : "Failed to delete rule",
            "ruleId": ruleId
        ]

        resolve(result, completion: completion)
    }

    func clearAllRules(completion: @escaping (Any) -> Void) {
        CacheRuleManager.shared.clearAllRules()

        let result: [String: Any] = [
            "success": true,
            "message": "All rules cleared (using old CacheRule system)"
        ]

        resolve(result, completion: completion)
    }

    func resetToPresetRules(completion: @escaping (Any) -> Void) {
        let success = CacheRuleManager.shared.resetToPresetRules()

        let result: [String: Any] = [
            "success": success,
            "message": success ? "Reset to preset rules (using old CacheRule system)" : "Failed to reset rules"
        ]

        resolve(result, completion: completion)
    }

    func getRuleCache(ruleId: String, completion: @escaping (Any) -> Void) {
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

    func deleteRuleCache(ruleId: String, completion: @escaping (Any) -> Void) {
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
