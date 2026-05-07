//
//  URLRuleMatcherTests.swift
//  CacheTests
//

import XCTest
@testable import WebBridgeKit

final class URLRuleMatcherTests: XCTestCase {

    private var matcher: URLRuleMatcher!

    override func setUp() {
        super.setUp()
        matcher = URLRuleMatcher.shared
        matcher.clearAllRules()
    }

    override func tearDown() {
        matcher.clearAllRules()
        super.tearDown()
    }

    // MARK: - Exact Match

    func testExactMatchReturnsTrue() {
        let rule = ManifestCacheRule(
            name: "Exact Rule",
            matchType: .exact,
            pattern: "https://example.com/page",
            manifestURL: URL(string: "https://example.com/manifest.json")!
        )
        let url = URL(string: "https://example.com/page")!
        XCTAssertTrue(rule.matches(url: url))
    }

    func testExactMatchReturnsFalseForDifferentURL() {
        let rule = ManifestCacheRule(
            name: "Exact Rule",
            matchType: .exact,
            pattern: "https://example.com/page",
            manifestURL: URL(string: "https://example.com/manifest.json")!
        )
        let url = URL(string: "https://example.com/other")!
        XCTAssertFalse(rule.matches(url: url))
    }

    // MARK: - Domain Match

    func testDomainMatchExactHost() {
        let rule = ManifestCacheRule(
            name: "Domain Rule",
            matchType: .domain,
            pattern: "example.com",
            manifestURL: URL(string: "https://example.com/manifest.json")!
        )
        let url = URL(string: "https://example.com/page")!
        XCTAssertTrue(rule.matches(url: url))
    }

    func testDomainMatchSubdomain() {
        let rule = ManifestCacheRule(
            name: "Domain Rule",
            matchType: .domain,
            pattern: "example.com",
            manifestURL: URL(string: "https://example.com/manifest.json")!
        )
        let url = URL(string: "https://api.example.com/v1")!
        XCTAssertTrue(rule.matches(url: url))
    }

    func testDomainMatchDifferentDomain() {
        let rule = ManifestCacheRule(
            name: "Domain Rule",
            matchType: .domain,
            pattern: "example.com",
            manifestURL: URL(string: "https://example.com/manifest.json")!
        )
        let url = URL(string: "https://other.com/page")!
        XCTAssertFalse(rule.matches(url: url))
    }

    func testDomainMatchNoHostReturnsFalse() {
        let rule = ManifestCacheRule(
            name: "Domain Rule",
            matchType: .domain,
            pattern: "example.com",
            manifestURL: URL(string: "https://example.com/manifest.json")!
        )
        let url = URL(string: "data:text/html,hello")!
        XCTAssertFalse(rule.matches(url: url))
    }

    // MARK: - Path Prefix Match

    func testPathPrefixMatchReturnsTrue() {
        let rule = ManifestCacheRule(
            name: "Path Prefix",
            matchType: .pathPrefix,
            pattern: "/api/v1",
            manifestURL: URL(string: "https://example.com/manifest.json")!
        )
        let url = URL(string: "https://example.com/api/v1/users")!
        XCTAssertTrue(rule.matches(url: url))
    }

    func testPathPrefixMatchReturnsFalseForDifferentPath() {
        let rule = ManifestCacheRule(
            name: "Path Prefix",
            matchType: .pathPrefix,
            pattern: "/api/v2",
            manifestURL: URL(string: "https://example.com/manifest.json")!
        )
        let url = URL(string: "https://example.com/api/v1/users")!
        XCTAssertFalse(rule.matches(url: url))
    }

    // MARK: - Glob Match

    func testGlobMatchStar() {
        let rule = ManifestCacheRule(
            name: "Glob Rule",
            matchType: .glob,
            pattern: "https://example.com/*.js",
            manifestURL: URL(string: "https://example.com/manifest.json")!
        )
        let url = URL(string: "https://example.com/app.js")!
        XCTAssertTrue(rule.matches(url: url))
    }

    func testGlobMatchDoubleStar() {
        let rule = ManifestCacheRule(
            name: "Glob Rule",
            matchType: .glob,
            pattern: "https://example.com/**",
            manifestURL: URL(string: "https://example.com/manifest.json")!
        )
        let url = URL(string: "https://example.com/path/to/file.js")!
        XCTAssertTrue(rule.matches(url: url))
    }

    func testGlobNoMatch() {
        let rule = ManifestCacheRule(
            name: "Glob Rule",
            matchType: .glob,
            pattern: "https://other.com/**",
            manifestURL: URL(string: "https://other.com/manifest.json")!
        )
        let url = URL(string: "https://example.com/file.js")!
        XCTAssertFalse(rule.matches(url: url))
    }

    // MARK: - Regex Match

    func testRegexMatchReturnsTrue() {
        let rule = ManifestCacheRule(
            name: "Regex Rule",
            matchType: .regex,
            pattern: "https://example\\.com/v[0-9]+/.*",
            manifestURL: URL(string: "https://example.com/manifest.json")!
        )
        let url = URL(string: "https://example.com/v1/users")!
        XCTAssertTrue(rule.matches(url: url))
    }

    func testRegexMatchReturnsFalse() {
        let rule = ManifestCacheRule(
            name: "Regex Rule",
            matchType: .regex,
            pattern: "https://example\\.com/v[0-9]+/.*",
            manifestURL: URL(string: "https://example.com/manifest.json")!
        )
        let url = URL(string: "https://example.com/alpha/users")!
        XCTAssertFalse(rule.matches(url: url))
    }

    func testRegexInvalidPatternReturnsFalse() {
        let rule = ManifestCacheRule(
            name: "Bad Regex",
            matchType: .regex,
            pattern: "[invalid(regex",
            manifestURL: URL(string: "https://example.com/manifest.json")!
        )
        let url = URL(string: "https://example.com/")!
        XCTAssertFalse(rule.matches(url: url))
    }

    // MARK: - Disabled Rule

    func testDisabledRuleDoesNotMatch() {
        var rule = ManifestCacheRule(
            name: "Disabled Rule",
            matchType: .exact,
            pattern: "https://example.com/page",
            manifestURL: URL(string: "https://example.com/manifest.json")!
        )
        rule.isEnabled = false
        let url = URL(string: "https://example.com/page")!
        XCTAssertFalse(rule.matches(url: url))
    }

    // MARK: - Priority

    func testMatchTypePriorityOrdering() {
        XCTAssertGreaterThan(MatchType.exact, MatchType.domain)
        XCTAssertGreaterThan(MatchType.domain, MatchType.pathPrefix)
        XCTAssertGreaterThan(MatchType.pathPrefix, MatchType.glob)
        XCTAssertGreaterThan(MatchType.glob, MatchType.regex)
    }

    // MARK: - Matcher Integration

    func testMatchReturnsNilForNoRules() {
        let url = URL(string: "https://example.com/page")!
        XCTAssertNil(matcher.match(url: url))
    }

    func testAddExactRuleAndMatch() {
        matcher.addExactRule(
            name: "Test",
            url: "https://example.com/page",
            manifestURL: URL(string: "https://example.com/manifest.json")!
        )

        sleep(1)

        let url = URL(string: "https://example.com/page")!
        let result = matcher.match(url: url)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.matchType, .exact)
    }

    func testAddDomainRuleAndMatch() {
        matcher.addDomainRule(
            name: "Domain",
            domain: "example.com",
            manifestURL: URL(string: "https://example.com/manifest.json")!
        )

        sleep(1)

        let url = URL(string: "https://example.com/any/path")!
        let result = matcher.match(url: url)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.matchType, .domain)
    }

    func testRemoveRule() {
        matcher.addExactRule(
            name: "Remove Me",
            url: "https://example.com/remove",
            manifestURL: URL(string: "https://example.com/manifest.json")!
        )

        sleep(1)

        let rules = matcher.getAllRules()
        guard let ruleId = rules.first?.id else {
            XCTFail("Rule should be added")
            return
        }

        matcher.removeRule(id: ruleId)
        sleep(1)

        XCTAssertTrue(matcher.getAllRules().isEmpty)
    }

    func testClearAllRules() {
        matcher.addExactRule(
            name: "A",
            url: "https://a.com",
            manifestURL: URL(string: "https://a.com/m.json")!
        )
        matcher.addExactRule(
            name: "B",
            url: "https://b.com",
            manifestURL: URL(string: "https://b.com/m.json")!
        )

        sleep(1)

        matcher.clearAllRules()
        sleep(1)

        XCTAssertTrue(matcher.getAllRules().isEmpty)
    }

    func testHigherPriorityWins() {
        matcher.addDomainRule(
            name: "Low",
            domain: "example.com",
            manifestURL: URL(string: "https://example.com/low.json")!,
            priority: 10
        )
        matcher.addExactRule(
            name: "High",
            url: "https://example.com/page",
            manifestURL: URL(string: "https://example.com/high.json")!,
            priority: 100
        )

        sleep(1)

        let url = URL(string: "https://example.com/page")!
        let result = matcher.match(url: url)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.priority, 100)
    }

    func testSetRuleEnabled() {
        matcher.addExactRule(
            name: "Toggle",
            url: "https://example.com/toggle",
            manifestURL: URL(string: "https://example.com/m.json")!
        )

        sleep(1)

        let rules = matcher.getAllRules()
        let ruleId = rules.first!.id

        matcher.setRuleEnabled(id: ruleId, enabled: false)
        sleep(1)

        let url = URL(string: "https://example.com/toggle")!
        XCTAssertNil(matcher.match(url: url))
    }

    // MARK: - MatchType Comparable

    func testMatchTypeLessThan() {
        XCTAssertTrue(MatchType.regex < MatchType.glob)
        XCTAssertTrue(MatchType.glob < MatchType.pathPrefix)
        XCTAssertFalse(MatchType.exact < MatchType.exact)
    }
}
