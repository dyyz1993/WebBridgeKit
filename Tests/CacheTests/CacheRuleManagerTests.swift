//
//  CacheRuleManagerTests.swift
//  CacheTests
//

import XCTest
@testable import WebBridgeKit

final class CacheRuleManagerTests: XCTestCase {

    private var manager: CacheRuleManager!

    override func setUp() {
        super.setUp()
        manager = CacheRuleManager.shared
        manager.clearAllRules()
    }

    override func tearDown() {
        manager.clearAllRules()
        super.tearDown()
    }

    // MARK: - Add / Remove Rules

    func testAddRule() {
        let rule = CacheRule(
            name: "Test Rule",
            type: .domain,
            pattern: "example.com"
        )
        manager.addRule(rule)

        sleep(1)

        let rules = manager.getAllRules()
        XCTAssertEqual(rules.count, 1)
        XCTAssertEqual(rules.first?.name, "Test Rule")
    }

    func testRemoveRule() {
        let rule = CacheRule(
            name: "Remove Me",
            type: .exact,
            pattern: "https://example.com/page"
        )
        manager.addRule(rule)

        sleep(1)

        manager.removeRule(id: rule.id)
        sleep(1)

        XCTAssertTrue(manager.getAllRules().isEmpty)
    }

    func testRemoveNonexistentRuleDoesNotCrash() {
        manager.removeRule(id: "nonexistent-id")
    }

    func testDeleteRuleReturnsTrue() {
        let rule = CacheRule(
            name: "Delete Me",
            type: .domain,
            pattern: "test.com"
        )
        manager.addRule(rule)

        sleep(1)

        let result = manager.deleteRule(ruleId: rule.id)
        XCTAssertTrue(result)
    }

    func testDeleteRuleReturnsFalseForNonexistent() {
        let result = manager.deleteRule(ruleId: "nonexistent")
        XCTAssertFalse(result)
    }

    // MARK: - Enable / Disable

    func testSetRuleEnabled() {
        let rule = CacheRule(
            name: "Toggle",
            type: .domain,
            pattern: "example.com"
        )
        manager.addRule(rule)

        sleep(1)

        manager.setRuleEnabled(id: rule.id, enabled: false)
        sleep(1)

        let rules = manager.getAllRules()
        XCTAssertFalse(rules.first!.isEnabled)
    }

    func testEnableDisabledRule() {
        let rule = CacheRule(
            name: "Toggle",
            type: .domain,
            pattern: "example.com"
        )
        manager.addRule(rule)

        sleep(1)

        manager.setRuleEnabled(id: rule.id, enabled: false)
        sleep(1)

        manager.setRuleEnabled(id: rule.id, enabled: true)
        sleep(1)

        let rules = manager.getAllRules()
        XCTAssertTrue(rules.first!.isEnabled)
    }

    // MARK: - Rule Matching

    func testShouldCacheExactMatch() {
        let rule = CacheRule(
            name: "Exact",
            type: .exact,
            pattern: "https://example.com/page"
        )
        manager.addRule(rule)

        sleep(1)

        let url = URL(string: "https://example.com/page")!
        let (shouldCache, matchedRule) = manager.shouldCache(url: url)
        XCTAssertTrue(shouldCache)
        XCTAssertNotNil(matchedRule)
    }

    func testShouldCacheDomainMatch() {
        let rule = CacheRule(
            name: "Domain",
            type: .domain,
            pattern: "example.com"
        )
        manager.addRule(rule)

        sleep(1)

        let url = URL(string: "https://example.com/any/path")!
        let (shouldCache, _) = manager.shouldCache(url: url)
        XCTAssertTrue(shouldCache)
    }

    func testShouldCacheWildcardDomainMatch() {
        let rule = CacheRule(
            name: "Wildcard",
            type: .domain,
            pattern: "*.example.com"
        )
        manager.addRule(rule)

        sleep(1)

        let url = URL(string: "https://api.example.com/v1")!
        let (shouldCache, _) = manager.shouldCache(url: url)
        XCTAssertTrue(shouldCache)
    }

    func testShouldCacheGlobMatch() {
        let rule = CacheRule(
            name: "Glob",
            type: .glob,
            pattern: "https://example.com/*.js"
        )
        manager.addRule(rule)

        sleep(1)

        let url = URL(string: "https://example.com/app.js")!
        let (shouldCache, _) = manager.shouldCache(url: url)
        XCTAssertTrue(shouldCache)
    }

    func testShouldCacheRegexMatch() {
        let rule = CacheRule(
            name: "Regex",
            type: .regex,
            pattern: "https://example\\.com/v[0-9]+/.*"
        )
        manager.addRule(rule)

        sleep(1)

        let url = URL(string: "https://example.com/v2/users")!
        let (shouldCache, _) = manager.shouldCache(url: url)
        XCTAssertTrue(shouldCache)
    }

    func testShouldCacheNoMatchReturnsFalse() {
        let rule = CacheRule(
            name: "Domain",
            type: .domain,
            pattern: "other.com"
        )
        manager.addRule(rule)

        sleep(1)

        let url = URL(string: "https://example.com/page")!
        let (shouldCache, matchedRule) = manager.shouldCache(url: url)
        XCTAssertFalse(shouldCache)
        XCTAssertNil(matchedRule)
    }

    func testDisabledRuleDoesNotMatch() {
        var rule = CacheRule(
            name: "Disabled",
            type: .exact,
            pattern: "https://example.com/disabled"
        )
        rule.isEnabled = false
        manager.addRule(rule)

        sleep(1)

        let url = URL(string: "https://example.com/disabled")!
        let (shouldCache, _) = manager.shouldCache(url: url)
        XCTAssertFalse(shouldCache)
    }

    // MARK: - Update Rule

    func testUpdateRuleName() {
        let rule = CacheRule(
            name: "Original",
            type: .domain,
            pattern: "example.com"
        )
        manager.addRule(rule)

        sleep(1)

        manager.updateRule(id: rule.id, name: "Updated")
        sleep(1)

        let rules = manager.getAllRules()
        XCTAssertEqual(rules.first?.name, "Updated")
    }

    func testUpdateRuleEnabled() {
        let rule = CacheRule(
            name: "Test",
            type: .domain,
            pattern: "example.com"
        )
        manager.addRule(rule)

        sleep(1)

        manager.updateRule(id: rule.id, enabled: false)
        sleep(1)

        let rules = manager.getAllRules()
        XCTAssertFalse(rules.first!.isEnabled)
    }

    // MARK: - Clear All

    func testClearAllRules() {
        manager.addRule(CacheRule(name: "A", type: .domain, pattern: "a.com"))
        manager.addRule(CacheRule(name: "B", type: .domain, pattern: "b.com"))

        sleep(1)

        manager.clearAllRules()
        sleep(1)

        XCTAssertTrue(manager.getAllRules().isEmpty)
    }

    // MARK: - Default / Reset

    func testResetToPresetRulesReturnsTrue() {
        let result = manager.resetToPresetRules()
        XCTAssertTrue(result)
    }

    // MARK: - CacheRule Model

    func testCacheRuleInit() {
        let rule = CacheRule(
            id: "custom-id",
            name: "Test",
            type: .glob,
            pattern: "*.js",
            resourceType: .dynamicResource,
            isEnabled: false,
            priority: 50
        )
        XCTAssertEqual(rule.id, "custom-id")
        XCTAssertEqual(rule.name, "Test")
        XCTAssertEqual(rule.type, .glob)
        XCTAssertEqual(rule.pattern, "*.js")
        XCTAssertEqual(rule.resourceType, .dynamicResource)
        XCTAssertFalse(rule.isEnabled)
        XCTAssertEqual(rule.priority, 50)
    }

    func testCacheRuleAutoGeneratesID() {
        let rule = CacheRule(
            name: "Auto",
            type: .domain,
            pattern: "example.com"
        )
        XCTAssertFalse(rule.id.isEmpty)
    }

    func testCacheRuleDisplayDescription() {
        let rule = CacheRule(
            name: "Test",
            type: .domain,
            pattern: "example.com"
        )
        XCTAssertFalse(rule.displayDescription.isEmpty)
        XCTAssertTrue(rule.displayDescription.contains("example.com"))
    }

    // MARK: - deleteCacheByRule

    func testDeleteCacheByRule() {
        let rule = CacheRule(
            name: "Delete Cache",
            type: .domain,
            pattern: "test.com"
        )
        manager.addRule(rule)
        sleep(1)

        let result = manager.deleteCacheByRule(rule: rule)
        XCTAssertTrue(result)
    }
}
