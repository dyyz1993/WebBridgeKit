//
//  CacheModelsTests.swift
//  WebBridgeKitTests
//

import XCTest
@testable import WebBridgeKit

final class CacheModelsTests: XCTestCase {

    // MARK: - CachedResource

    func testCachedResourceAge() {
        let past = Date().addingTimeInterval(-100)
        let resource = CachedResource(
            url: URL(string: "https://example.com/app.js")!,
            data: Data("test".utf8),
            mimeType: "application/javascript",
            cachedAt: past
        )

        XCTAssertEqual(resource.age, 100, accuracy: 1)
    }

    func testCachedResourceIsExpired() {
        let old = Date().addingTimeInterval(-600)
        let resource = CachedResource(
            url: URL(string: "https://example.com/app.js")!,
            data: Data("test".utf8),
            mimeType: "application/javascript",
            cachedAt: old
        )

        XCTAssertTrue(resource.isExpired(maxAge: 300))
        XCTAssertFalse(resource.isExpired(maxAge: 900))
    }

    func testCachedResourceFormattedSize() {
        let resource = CachedResource(
            url: URL(string: "https://example.com/app.js")!,
            data: Data(repeating: 0, count: 1024),
            mimeType: "application/javascript",
            cachedAt: Date()
        )

        let formatted = resource.formattedSize
        XCTAssertTrue(formatted.contains("KB") || formatted.contains("bytes"))
    }

    // MARK: - ResourceCacheMetadata

    func testResourceCacheMetadataInit() {
        let url = URL(string: "https://example.com/style.css")!
        let date = Date()
        let metadata = ResourceCacheMetadata(
            url: url,
            localPath: "/cache/style.css",
            mimeType: "text/css",
            cachedAt: date
        )

        XCTAssertEqual(metadata.url, url)
        XCTAssertEqual(metadata.localPath, "/cache/style.css")
        XCTAssertEqual(metadata.mimeType, "text/css")
        XCTAssertEqual(metadata.cachedAt, date)
    }

    // MARK: - CacheRequestInfo

    func testCacheRequestInfoInit() {
        let url = URL(string: "https://example.com/page")!
        let info = CacheRequestInfo(
            url: url,
            isMainFrame: true,
            httpMethod: "GET",
            hasCache: true,
            cacheAge: 42.5
        )

        XCTAssertEqual(info.url, url)
        XCTAssertEqual(info.isMainFrame, true)
        XCTAssertEqual(info.httpMethod, "GET")
        XCTAssertEqual(info.hasCache, true)
        XCTAssertEqual(info.cacheAge, 42.5)
    }

    func testCacheRequestInfoDefaultCacheAge() {
        let info = CacheRequestInfo(
            url: URL(string: "https://example.com")!,
            isMainFrame: false,
            httpMethod: "GET",
            hasCache: false
        )

        XCTAssertNil(info.cacheAge)
    }

    // MARK: - CacheStats

    func testCacheStatsHitRate() {
        let stats = CacheStats(
            totalRequests: 100,
            cacheHits: 75,
            cacheMisses: 25,
            totalCacheSize: 1024 * 1024
        )

        XCTAssertEqual(stats.hitRate, 0.75, accuracy: 0.01)
        XCTAssertEqual(stats.cacheHits, 75)
        XCTAssertEqual(stats.cacheMisses, 25)
    }

    func testCacheStatsZeroRequests() {
        let stats = CacheStats(
            totalRequests: 0,
            cacheHits: 0,
            cacheMisses: 0,
            totalCacheSize: 0
        )

        XCTAssertEqual(stats.hitRate, 0)
    }

    func testCacheStatsFormattedHitRate() {
        let stats = CacheStats(
            totalRequests: 200,
            cacheHits: 150,
            cacheMisses: 50,
            totalCacheSize: 0
        )

        XCTAssertEqual(stats.formattedHitRate, "75.0%")
    }

    func testCacheStatsFormattedCacheSize() {
        let stats = CacheStats(
            totalRequests: 1,
            cacheHits: 0,
            cacheMisses: 1,
            totalCacheSize: 2048
        )

        XCTAssertTrue(stats.formattedCacheSize.contains("KB"))
    }

    // MARK: - CacheRule

    func testCacheRuleInitGeneratesID() {
        let rule = CacheRule(
            name: "Test Rule",
            type: .domain,
            pattern: "example.com"
        )

        XCTAssertFalse(rule.id.isEmpty)
        XCTAssertEqual(rule.name, "Test Rule")
        XCTAssertEqual(rule.type, .domain)
        XCTAssertEqual(rule.pattern, "example.com")
        XCTAssertEqual(rule.resourceType, .staticResource)
        XCTAssertEqual(rule.isEnabled, true)
        XCTAssertEqual(rule.priority, 0)
    }

    func testCacheRuleInitWithCustomID() {
        let rule = CacheRule(
            id: "custom-id",
            name: "Test",
            type: .exact,
            pattern: "https://example.com",
            resourceType: .dynamicResource,
            isEnabled: false,
            priority: 10
        )

        XCTAssertEqual(rule.id, "custom-id")
        XCTAssertEqual(rule.type, .exact)
        XCTAssertEqual(rule.resourceType, .dynamicResource)
        XCTAssertEqual(rule.isEnabled, false)
        XCTAssertEqual(rule.priority, 10)
    }

    func testCacheRuleDomainMatchExact() {
        let rule = CacheRule(name: "Test", type: .domain, pattern: "example.com")
        let url = URL(string: "https://example.com/page")!

        XCTAssertTrue(rule.matches(url: url))
    }

    func testCacheRuleDomainMatchWildcard() {
        let rule = CacheRule(name: "Test", type: .domain, pattern: "*.example.com")
        let subUrl = URL(string: "https://sub.example.com/page")!

        XCTAssertTrue(rule.matches(url: subUrl))
    }

    func testCacheRuleDomainMatchNoSubdomain() {
        let rule = CacheRule(name: "Test", type: .domain, pattern: "*.example.com")
        let baseUrl = URL(string: "https://example.com/page")!

        XCTAssertTrue(rule.matches(url: baseUrl))
    }

    func testCacheRuleDomainNoMatch() {
        let rule = CacheRule(name: "Test", type: .domain, pattern: "example.com")
        let url = URL(string: "https://other.com/page")!

        XCTAssertFalse(rule.matches(url: url))
    }

    func testCacheRuleExactMatch() {
        let rule = CacheRule(name: "Test", type: .exact, pattern: "https://example.com/exact")
        let matchUrl = URL(string: "https://example.com/exact")!
        let noMatchUrl = URL(string: "https://example.com/other")!

        XCTAssertTrue(rule.matches(url: matchUrl))
        XCTAssertFalse(rule.matches(url: noMatchUrl))
    }

    func testCacheRuleRegexMatch() {
        let rule = CacheRule(name: "Test", type: .regex, pattern: "https://example\\.com/\\d+")
        let matchUrl = URL(string: "https://example.com/123")!
        let noMatchUrl = URL(string: "https://example.com/abc")!

        XCTAssertTrue(rule.matches(url: matchUrl))
        XCTAssertFalse(rule.matches(url: noMatchUrl))
    }

    func testCacheRuleDisabledDoesNotMatch() {
        let rule = CacheRule(name: "Test", type: .domain, pattern: "example.com", isEnabled: false)
        let url = URL(string: "https://example.com")!

        XCTAssertFalse(rule.matches(url: url))
    }

    func testCacheRuleGlobMatch() {
        let rule = CacheRule(name: "Test", type: .glob, pattern: "https://example.com/*.js")
        let matchUrl = URL(string: "https://example.com/app.js")!
        let noMatchUrl = URL(string: "https://example.com/app.css")!

        XCTAssertTrue(rule.matches(url: matchUrl))
        XCTAssertFalse(rule.matches(url: noMatchUrl))
    }

    func testCacheRuleDisplayDescription() {
        let rule = CacheRule(name: "Test", type: .domain, pattern: "example.com", resourceType: .staticResource)
        XCTAssertTrue(rule.displayDescription.contains("example.com"))
        XCTAssertTrue(rule.displayDescription.contains("域名"))
    }

    // MARK: - CacheRule Codable

    func testCacheRuleCodableRoundTrip() throws {
        let rule = CacheRule(
            id: "test-id",
            name: "Test Rule",
            type: .domain,
            pattern: "example.com",
            resourceType: .dynamicResource,
            isEnabled: true,
            priority: 5
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(rule)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CacheRule.self, from: data)

        XCTAssertEqual(decoded.id, rule.id)
        XCTAssertEqual(decoded.name, rule.name)
        XCTAssertEqual(decoded.type, rule.type)
        XCTAssertEqual(decoded.pattern, rule.pattern)
        XCTAssertEqual(decoded.resourceType, rule.resourceType)
        XCTAssertEqual(decoded.isEnabled, rule.isEnabled)
        XCTAssertEqual(decoded.priority, rule.priority)
    }

    // MARK: - PageCacheRule

    func testPageCacheRuleInit() {
        let rule = PageCacheRule(
            name: "Test Rule",
            includePatterns: ["https://example.com/**"],
            excludePatterns: ["https://example.com/login/**"]
        )

        XCTAssertFalse(rule.id.isEmpty)
        XCTAssertEqual(rule.name, "Test Rule")
        XCTAssertEqual(rule.includePatterns, ["https://example.com/**"])
        XCTAssertEqual(rule.excludePatterns, ["https://example.com/login/**"])
        XCTAssertEqual(rule.isEnabled, true)
        XCTAssertNil(rule.lastCachedAt)
    }

    func testPageCacheRuleMatchesInclude() {
        let rule = PageCacheRule(
            name: "Test",
            includePatterns: ["https://example.com/**"]
        )
        let url = URL(string: "https://example.com/page")!

        XCTAssertTrue(rule.matches(url: url))
    }

    func testPageCacheRuleExcludesOverrideIncludes() {
        let rule = PageCacheRule(
            name: "Test",
            includePatterns: ["https://example.com/**"],
            excludePatterns: ["https://example.com/login/**"]
        )
        let loginUrl = URL(string: "https://example.com/login/page")!

        XCTAssertFalse(rule.matches(url: loginUrl))
    }

    func testPageCacheRuleNoMatch() {
        let rule = PageCacheRule(
            name: "Test",
            includePatterns: ["https://example.com/**"]
        )
        let url = URL(string: "https://other.com/page")!

        XCTAssertFalse(rule.matches(url: url))
    }

    func testPageCacheRuleDisabledDoesNotMatch() {
        let rule = PageCacheRule(
            name: "Test",
            includePatterns: ["https://example.com/**"],
            isEnabled: false
        )
        let url = URL(string: "https://example.com/page")!

        XCTAssertFalse(rule.matches(url: url))
    }

    func testPageCacheRuleCodableRoundTrip() throws {
        let rule = PageCacheRule(
            id: "test-id",
            name: "Test Rule",
            includePatterns: ["https://example.com/**"],
            excludePatterns: ["https://example.com/login/**"],
            isEnabled: true,
            createdAt: Date(),
            lastCachedAt: Date()
        )

        let data = try JSONEncoder().encode(rule)
        let decoded = try JSONDecoder().decode(PageCacheRule.self, from: data)

        XCTAssertEqual(decoded.id, rule.id)
        XCTAssertEqual(decoded.name, rule.name)
        XCTAssertEqual(decoded.includePatterns, rule.includePatterns)
        XCTAssertEqual(decoded.excludePatterns, rule.excludePatterns)
        XCTAssertEqual(decoded.isEnabled, rule.isEnabled)
    }

    func testPageCacheRuleDisplayDescription() {
        let rule = PageCacheRule(
            name: "Example",
            includePatterns: ["https://example.com/**"],
            excludePatterns: ["https://example.com/login/**"]
        )

        XCTAssertTrue(rule.displayDescription.contains("Example"))
        XCTAssertTrue(rule.displayDescription.contains("排除"))
    }

    func testPageCacheRuleShortDescription() {
        let rule = PageCacheRule(
            name: "Example",
            includePatterns: ["https://a.com/**", "https://b.com/**"],
            excludePatterns: ["https://a.com/login/**"]
        )

        XCTAssertTrue(rule.shortDescription.contains("2"))
        XCTAssertTrue(rule.shortDescription.contains("1"))
    }

    // MARK: - PageCacheRule Presets

    func testPresetBaiduRule() {
        let rule = PageCacheRule.baiduRule
        XCTAssertEqual(rule.name, "百度")
        XCTAssertTrue(rule.matches(url: URL(string: "https://www.baidu.com/search?q=test")!))
        XCTAssertFalse(rule.matches(url: URL(string: "https://www.baidu.com/login/index")!))
    }

    func testPresetGithubRule() {
        let rule = PageCacheRule.githubRule
        XCTAssertTrue(rule.matches(url: URL(string: "https://github.com/user/repo")!))
    }

    func testPresetRulesCount() {
        XCTAssertEqual(PageCacheRule.presetRules.count, 3)
    }

    // MARK: - CachedPageInfo

    func testCachedPageInfoFormattedSize() {
        let info = CachedPageInfo(
            id: "1",
            url: "https://example.com",
            title: "Test",
            ruleId: "rule-1",
            ruleName: "Rule",
            resourceCount: 10,
            totalSize: 2048,
            cachedAt: Date()
        )

        XCTAssertTrue(info.formattedSize.contains("KB"))
    }

    // MARK: - RuleWithPages

    func testRuleWithPagesTotals() {
        let rule = PageCacheRule(name: "Test", includePatterns: ["https://example.com/**"])
        let pages = [
            CachedPageInfo(id: "1", url: "https://example.com/a", title: "A", ruleId: rule.id, ruleName: "Test", resourceCount: 5, totalSize: 1024, cachedAt: Date()),
            CachedPageInfo(id: "2", url: "https://example.com/b", title: "B", ruleId: rule.id, ruleName: "Test", resourceCount: 3, totalSize: 2048, cachedAt: Date(), isExcluded: true)
        ]

        let ruleWithPages = RuleWithPages(rule: rule, cachedPages: pages)

        XCTAssertEqual(ruleWithPages.totalPagesCount, 2)
        XCTAssertEqual(ruleWithPages.totalSize, 3072)
        XCTAssertEqual(ruleWithPages.excludedCount, 1)
    }

    // MARK: - WebCacheStatistics

    func testWebCacheStatisticsFormattedSize() {
        let stats = WebCacheStatistics()
        stats.domain = "example.com"
        stats.totalSize = 1024 * 512
        stats.fileCount = 10

        XCTAssertTrue(stats.formattedSize.contains("KB") || stats.formattedSize.contains("MB"))
    }

    func testWebCacheStatisticsPrimaryKey() {
        XCTAssertEqual(WebCacheStatistics.primaryKey(), "domain")
    }

    func testWebCacheStatisticsIndexedProperties() {
        let indexed = WebCacheStatistics.indexedProperties()
        XCTAssertTrue(indexed.contains("domain"))
        XCTAssertTrue(indexed.contains("lastUpdate"))
    }

    func testWebCacheStatisticsDefaultValues() {
        let stats = WebCacheStatistics()
        XCTAssertEqual(stats.totalSize, 0)
        XCTAssertEqual(stats.fileCount, 0)
    }
}
