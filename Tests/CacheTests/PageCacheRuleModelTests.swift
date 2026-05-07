import XCTest
@testable import WebBridgeKit

final class PageCacheRuleModelTests: XCTestCase {

    func testPageCacheRuleInitWithDefaults() {
        let rule = PageCacheRule(
            name: "Test",
            includePatterns: ["https://example.com/**"]
        )
        XCTAssertFalse(rule.id.isEmpty)
        XCTAssertEqual(rule.name, "Test")
        XCTAssertTrue(rule.isEnabled)
        XCTAssertNil(rule.lastCachedAt)
        XCTAssertTrue(rule.excludePatterns.isEmpty)
    }

    func testPageCacheRuleInitWithAllParams() {
        let date = Date()
        let rule = PageCacheRule(
            id: "test-id",
            name: "Custom",
            includePatterns: ["https://*.test.com/**"],
            excludePatterns: ["https://*.test.com/login/**"],
            isEnabled: false,
            createdAt: date,
            lastCachedAt: date
        )
        XCTAssertEqual(rule.id, "test-id")
        XCTAssertEqual(rule.name, "Custom")
        XCTAssertFalse(rule.isEnabled)
        XCTAssertEqual(rule.excludePatterns, ["https://*.test.com/login/**"])
        XCTAssertEqual(rule.lastCachedAt, date)
    }

    func testPageCacheRuleMatchesIncludePattern() {
        let rule = PageCacheRule(
            name: "Test",
            includePatterns: ["https://example.com/**"]
        )
        XCTAssertTrue(rule.matches(url: URL(string: "https://example.com/page")!))
        XCTAssertFalse(rule.matches(url: URL(string: "https://other.com/page")!))
    }

    func testPageCacheRuleExcludeOverridesInclude() {
        let rule = PageCacheRule(
            name: "Test",
            includePatterns: ["https://example.com/**"],
            excludePatterns: ["https://example.com/login/**"]
        )
        XCTAssertFalse(rule.matches(url: URL(string: "https://example.com/login")!))
        XCTAssertTrue(rule.matches(url: URL(string: "https://example.com/home")!))
    }

    func testPageCacheRuleDisabledNeverMatches() {
        let rule = PageCacheRule(
            name: "Test",
            includePatterns: ["https://example.com/**"],
            isEnabled: false
        )
        XCTAssertFalse(rule.matches(url: URL(string: "https://example.com/page")!))
    }

    func testPageCacheRuleDisplayDescriptionNoExclude() {
        let rule = PageCacheRule(
            name: "Test",
            includePatterns: ["https://example.com/**"]
        )
        XCTAssertTrue(rule.displayDescription.contains("Test"))
    }

    func testPageCacheRuleDisplayDescriptionWithExclude() {
        let rule = PageCacheRule(
            name: "Test",
            includePatterns: ["https://example.com/**"],
            excludePatterns: ["https://example.com/admin/**"]
        )
        XCTAssertTrue(rule.displayDescription.contains("Test"))
        XCTAssertTrue(rule.displayDescription.contains("排除"))
    }

    func testPageCacheRuleShortDescription() {
        let rule = PageCacheRule(
            name: "Test",
            includePatterns: ["https://a.com/**", "https://b.com/**"],
            excludePatterns: ["https://a.com/admin/**"]
        )
        XCTAssertTrue(rule.shortDescription.contains("2 包含"))
        XCTAssertTrue(rule.shortDescription.contains("1 排除"))
    }

    func testCachedPageInfoInit() {
        let info = CachedPageInfo(
            id: "page-1",
            url: "https://example.com",
            title: "Example",
            ruleId: "rule-1",
            ruleName: "Test Rule",
            resourceCount: 10,
            totalSize: 1024,
            cachedAt: Date()
        )
        XCTAssertEqual(info.id, "page-1")
        XCTAssertEqual(info.url, "https://example.com")
        XCTAssertTrue(info.isOfflineAvailable)
        XCTAssertFalse(info.isExcluded)
    }

    func testCachedPageInfoFormattedSize() {
        let info = CachedPageInfo(
            id: "1", url: "", title: "", ruleId: "", ruleName: "",
            resourceCount: 0, totalSize: 1024, cachedAt: Date()
        )
        XCTAssertFalse(info.formattedSize.isEmpty)
    }

    func testCachedPageInfoFormattedCachedAt() {
        let info = CachedPageInfo(
            id: "1", url: "", title: "", ruleId: "", ruleName: "",
            resourceCount: 0, totalSize: 0, cachedAt: Date()
        )
        XCTAssertFalse(info.formattedCachedAt.isEmpty)
    }

    func testRuleWithPagesInit() {
        let rule = PageCacheRule(name: "Test", includePatterns: ["https://example.com/**"])
        let info = CachedPageInfo(
            id: "1", url: "https://example.com", title: "Test",
            ruleId: rule.id, ruleName: rule.name,
            resourceCount: 5, totalSize: 2048, cachedAt: Date()
        )
        let rwp = RuleWithPages(rule: rule, cachedPages: [info], isExpanded: true)
        XCTAssertEqual(rwp.id, rule.id)
        XCTAssertEqual(rwp.totalPagesCount, 1)
        XCTAssertEqual(rwp.totalSize, 2048)
        XCTAssertTrue(rwp.isExpanded)
    }

    func testRuleWithPagesEmpty() {
        let rule = PageCacheRule(name: "Test", includePatterns: ["https://example.com/**"])
        let rwp = RuleWithPages(rule: rule)
        XCTAssertEqual(rwp.totalPagesCount, 0)
        XCTAssertEqual(rwp.totalSize, 0)
        XCTAssertEqual(rwp.excludedCount, 0)
    }

    func testRuleWithPagesFormattedTotalSize() {
        let rule = PageCacheRule(name: "Test", includePatterns: ["https://example.com/**"])
        let info = CachedPageInfo(
            id: "1", url: "", title: "", ruleId: "", ruleName: "",
            resourceCount: 0, totalSize: 50000, cachedAt: Date()
        )
        let rwp = RuleWithPages(rule: rule, cachedPages: [info])
        XCTAssertFalse(rwp.formattedTotalSize.isEmpty)
    }

    func testRuleWithPagesExcludedCount() {
        let rule = PageCacheRule(name: "Test", includePatterns: ["https://example.com/**"])
        let info1 = CachedPageInfo(
            id: "1", url: "", title: "", ruleId: "", ruleName: "",
            resourceCount: 0, totalSize: 0, cachedAt: Date(), isExcluded: true
        )
        let info2 = CachedPageInfo(
            id: "2", url: "", title: "", ruleId: "", ruleName: "",
            resourceCount: 0, totalSize: 0, cachedAt: Date(), isExcluded: false
        )
        let rwp = RuleWithPages(rule: rule, cachedPages: [info1, info2])
        XCTAssertEqual(rwp.excludedCount, 1)
    }

    func testPresetRules() {
        XCTAssertEqual(PageCacheRule.presetRules.count, 3)
        XCTAssertTrue(PageCacheRule.presetRules.contains(where: { $0.id == "preset-baidu" }))
        XCTAssertTrue(PageCacheRule.presetRules.contains(where: { $0.id == "preset-vip-video" }))
        XCTAssertTrue(PageCacheRule.presetRules.contains(where: { $0.id == "preset-github" }))
    }

    func testPresetBaiduRule() {
        let rule = PageCacheRule.baiduRule
        XCTAssertTrue(rule.matches(url: URL(string: "https://www.baidu.com/search?q=test")!))
        XCTAssertFalse(rule.matches(url: URL(string: "https://www.baidu.com/login")!))
    }

    func testPresetGithubRule() {
        let rule = PageCacheRule.githubRule
        XCTAssertTrue(rule.matches(url: URL(string: "https://github.com/user/repo")!))
    }
}
