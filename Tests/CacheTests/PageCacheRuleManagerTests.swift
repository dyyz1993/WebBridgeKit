import XCTest
@testable import WebBridgeKit

final class PageCacheRuleManagerTests: XCTestCase {

    func testSharedIsSingleton() {
        let m1 = PageCacheRuleManager.shared
        let m2 = PageCacheRuleManager.shared
        XCTAssertTrue(m1 === m2)
    }

    func testSharedIsNotNil() {
        XCTAssertNotNil(PageCacheRuleManager.shared)
    }

    func testGetAllRulesReturnsArray() {
        let manager = PageCacheRuleManager.shared
        let rules = manager.getAllRules()
        XCTAssertNotNil(rules)
    }

    func testGetAllRulesContainsPresetRules() {
        let manager = PageCacheRuleManager.shared
        let rules = manager.getAllRules()

        XCTAssertFalse(rules.isEmpty, "Should contain preset rules")
    }

    func testGetEnabledRulesFiltersDisabled() {
        let manager = PageCacheRuleManager.shared
        let enabled = manager.getEnabledRules()

        for rule in enabled where !rule.isEnabled {
            XCTFail("Enabled rules should not contain disabled rules: \(rule.name)")
        }
    }

    func testAddRuleAppearsInGetAllRules() {
        let manager = PageCacheRuleManager.shared
        let newRule = PageCacheRule(
            id: "test-add-\(UUID().uuidString)",
            name: "Test Add Rule",
            includePatterns: ["https://test-add.example.com/**"]
        )

        let added = manager.addRule(newRule)
        XCTAssertTrue(added)

        let rules = manager.getAllRules()
        XCTAssertTrue(rules.contains(where: { $0.id == newRule.id }))

        manager.deleteRule(ruleId: newRule.id)
    }

    func testUpdateRuleModifiesExisting() {
        let manager = PageCacheRuleManager.shared
        let rule = PageCacheRule(
            id: "test-update-\(UUID().uuidString)",
            name: "Original Name",
            includePatterns: ["https://original.example.com/**"]
        )

        _ = manager.addRule(rule)

        let updated = PageCacheRule(
            id: rule.id,
            name: "Updated Name",
            includePatterns: ["https://updated.example.com/**"],
            isEnabled: false
        )
        let success = manager.updateRule(updated)
        XCTAssertTrue(success)

        let rules = manager.getAllRules()
        let found = rules.first(where: { $0.id == rule.id })
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "Updated Name")
        XCTAssertFalse(found?.isEnabled ?? true)

        manager.deleteRule(ruleId: rule.id)
    }

    func testDeleteRuleRemovesFromList() {
        let manager = PageCacheRuleManager.shared
        let rule = PageCacheRule(
            id: "test-delete-\(UUID().uuidString)",
            name: "Delete Me",
            includePatterns: ["https://delete.example.com/**"]
        )

        _ = manager.addRule(rule)
        let rulesBefore = manager.getAllRules()
        XCTAssertTrue(rulesBefore.contains(where: { $0.id == rule.id }))

        let deleted = manager.deleteRule(ruleId: rule.id)
        XCTAssertTrue(deleted)

        let rulesAfter = manager.getAllRules()
        XCTAssertFalse(rulesAfter.contains(where: { $0.id == rule.id }))
    }

    func testClearAllRulesRemovesAll() {
        let manager = PageCacheRuleManager.shared
        let rule = PageCacheRule(
            id: "test-clear-\(UUID().uuidString)",
            name: "Clear Test",
            includePatterns: ["https://clear.example.com/**"]
        )

        _ = manager.addRule(rule)
        _ = manager.clearAllRules()

        let rules = manager.getAllRules()
        XCTAssertFalse(rules.contains(where: { $0.id == rule.id }))
    }

    func testShouldCacheMatchesURL() {
        let manager = PageCacheRuleManager.shared
        let (shouldCache, matched) = manager.shouldCache(url: URL(string: "https://www.baidu.com/search?q=test")!)

        if let matched = matched {
            XCTAssertEqual(matched.id, "preset-baidu")
        }
    }

    func testShouldCacheNoMatchReturnsFalse() {
        let manager = PageCacheRuleManager.shared
        let (shouldCache, _) = manager.shouldCache(url: URL(string: "https://nonexistent-no-match-\(UUID().uuidString).com/path")!)

        XCTAssertFalse(shouldCache)
    }

    func testGetMatchedRuleForKnownURL() {
        let manager = PageCacheRuleManager.shared
        let rule = manager.getMatchedRule(for: URL(string: "https://github.com/user/repo")!)

        if let rule = rule {
            XCTAssertEqual(rule.id, "preset-github")
        }
    }

    func testResetToPresetRulesRestoresDefaults() {
        let manager = PageCacheRuleManager.shared
        let customRule = PageCacheRule(
            id: "custom-before-reset-\(UUID().uuidString)",
            name: "Custom Before Reset",
            includePatterns: ["https://custom.example.com/**"]
        )
        _ = manager.addRule(customRule)

        let success = manager.resetToPresetRules()
        XCTAssertTrue(success)

        let rules = manager.getAllRules()
        XCTAssertEqual(rules.count, PageCacheRule.presetRules.count)
        XCTAssertFalse(rules.contains(where: { $0.id == customRule.id }))
    }

    func testAddRulesBatch() {
        let manager = PageCacheRuleManager.shared
        let rule1 = PageCacheRule(id: "batch-1-\(UUID().uuidString)", name: "Batch 1", includePatterns: ["https://b1.example.com/**"])
        let rule2 = PageCacheRule(id: "batch-2-\(UUID().uuidString)", name: "Batch 2", includePatterns: ["https://b2.example.com/**"])

        let added = manager.addRules([rule1, rule2])
        XCTAssertEqual(added, 2)

        manager.deleteRule(ruleId: rule1.id)
        manager.deleteRule(ruleId: rule2.id)
    }
}
