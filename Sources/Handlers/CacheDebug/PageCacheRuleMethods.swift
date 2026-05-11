//
//  PageCacheRuleMethods.swift
//  WebBridgeKit
//
//  页面缓存规则管理方法 (新系统)
//

import Foundation

extension WebCacheDebugHandler {

    // MARK: - 页面缓存规则管理方法 (新系统)

    func getPageRules(completion: @escaping (Any) -> Void) {
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

    func addPageRule(ruleParams: [String: Any], completion: @escaping (Any) -> Void) {
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

    func updatePageRule(ruleParams: [String: Any], completion: @escaping (Any) -> Void) {
        guard let ruleId = ruleParams["id"] as? String,
              let name = ruleParams["name"] as? String else {
            reject(error: "Invalid rule parameters: id and name are required", completion: completion)
            return
        }

        let includePatterns = ruleParams["includePatterns"] as? [String] ?? []
        let excludePatterns = ruleParams["excludePatterns"] as? [String] ?? []
        let isEnabled = ruleParams["isEnabled"] as? Bool ?? true

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

    func deletePageRule(ruleId: String, completion: @escaping (Any) -> Void) {
        let success = PageCacheRuleManager.shared.deleteRule(ruleId: ruleId)

        let result: [String: Any] = [
            "success": success,
            "message": success ? "Page cache rule deleted" : "Failed to delete rule",
            "ruleId": ruleId
        ]

        resolve(result, completion: completion)
    }

    func clearAllPageRules(completion: @escaping (Any) -> Void) {
        let success = PageCacheRuleManager.shared.clearAllRules()

        let result: [String: Any] = [
            "success": success,
            "message": success ? "All page cache rules cleared" : "Failed to clear rules"
        ]

        resolve(result, completion: completion)
    }

    func resetToPresetPageRules(completion: @escaping (Any) -> Void) {
        let success = PageCacheRuleManager.shared.resetToPresetRules()

        let result: [String: Any] = [
            "success": success,
            "message": success ? "Reset to preset page cache rules" : "Failed to reset rules"
        ]

        resolve(result, completion: completion)
    }

    func addExcludePattern(ruleId: String, pattern: String, completion: @escaping (Any) -> Void) {
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

    func removeExcludePattern(ruleId: String, pattern: String, completion: @escaping (Any) -> Void) {
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
}
