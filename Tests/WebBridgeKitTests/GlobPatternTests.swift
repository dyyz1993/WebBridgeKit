//
//  GlobPatternTests.swift
//  WebBridgeKitTests
//
//  Created by Claude on 2025-01-23.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import XCTest
@testable import WebBridgeKit

/// Glob 模式匹配单元测试
final class GlobPatternTests: XCTestCase {

    // MARK: - 基础通配符测试

    func testSingleAsterisk() {
        XCTAssertTrue(GlobPattern.matches("*.js", against: "app.js"))
        XCTAssertFalse(GlobPattern.matches("*.js", against: "app.css"))
    }

    func testQuestionMark() {
        XCTAssertTrue(GlobPattern.matches("file?.txt", against: "file1.txt"))
        XCTAssertFalse(GlobPattern.matches("file?.txt", against: "file10.txt"))
    }

    // MARK: - 路径通配符测试

    func testSingleAsteriskInPath() {
        XCTAssertTrue(GlobPattern.matches("https://example.com/*.js", against: "https://example.com/app.js"))
        XCTAssertFalse(GlobPattern.matches("https://example.com/*.js", against: "https://example.com/path/app.js"))
    }

    func testDoubleAsteriskInPath() {
        XCTAssertTrue(GlobPattern.matches("https://example.com/**", against: "https://example.com/path/to/file.js"))
        XCTAssertTrue(GlobPattern.matches("https://example.com/**", against: "https://example.com/file.js"))
    }

    func testDoubleAsteriskWithSubdirectories() {
        XCTAssertTrue(GlobPattern.matches("https://example.com/images/*.png", against: "https://example.com/images/logo.png"))
        XCTAssertFalse(GlobPattern.matches("https://example.com/images/*.png", against: "https://example.com/images/sub/logo.png"))
    }

    // MARK: - 域名通配符测试

    func testDomainWildcard() {
        XCTAssertTrue(GlobPattern.matches("https://*.example.com/**", against: "https://api.example.com/v1/users"))
        XCTAssertTrue(GlobPattern.matches("https://api.*.com/**", against: "https://api.example.com/v1/users"))
    }

    // MARK: - 字符集测试

    func testCharacterClass() {
        XCTAssertTrue(GlobPattern.matches("file[123].txt", against: "file1.txt"))
        XCTAssertTrue(GlobPattern.matches("file[123].txt", against: "file2.txt"))
        XCTAssertFalse(GlobPattern.matches("file[123].txt", against: "file4.txt"))
    }

    func testNegatedCharacterClass() {
        XCTAssertFalse(GlobPattern.matches("file[!123].txt", against: "file1.txt"))
        XCTAssertTrue(GlobPattern.matches("file[!123].txt", against: "file4.txt"))
    }

    // MARK: - GitHub 相关测试（修复 ** 通配符 bug）

    func testGitHubDoubleAsterisk() {
        // 根目录应该匹配
        XCTAssertTrue(GlobPattern.matches("https://github.com/**", against: "https://github.com"),
                      "GitHub root URL should match https://github.com/**")

        // 子路径应该匹配
        XCTAssertTrue(GlobPattern.matches("https://github.com/**", against: "https://github.com/user/repo"),
                      "GitHub repo URL should match https://github.com/**")

        // 深层路径应该匹配
        XCTAssertTrue(GlobPattern.matches("https://github.com/**", against: "https://github.com/user/repo/issues"),
                      "GitHub issues URL should match https://github.com/**")
    }

    // MARK: - 百度相关测试

    func testBaiduDoubleAsterisk() {
        XCTAssertTrue(GlobPattern.matches("https://*.baidu.com/**", against: "https://www.baidu.com"))
        XCTAssertTrue(GlobPattern.matches("https://*.baidu.com/**", against: "https://news.baidu.com/article"))
    }

    // MARK: - 复杂组合测试

    func testComplexPattern() {
        XCTAssertTrue(GlobPattern.matches("**/*.min.js", against: "path/to/jquery.min.js"))
    }

    // MARK: - 边界情况测试

    func testEmptyPatternAndText() {
        XCTAssertTrue(GlobPattern.matches("", against: ""))
    }

    func testExactMatch() {
        XCTAssertTrue(GlobPattern.matches("exact", against: "exact"))
        XCTAssertFalse(GlobPattern.matches("exact", against: "notexact"))
    }

    // MARK: - 排除模式测试

    func testExcludePattern() {
        // VIP 视频规则测试
        let includePatterns = ["https://*.vip.com/video/**", "https://*.vip.com/movie/**"]
        let excludePatterns = ["https://*.vip.com/login*", "https://*.vip.com/register*"]

        // 应该匹配包含模式
        XCTAssertTrue(GlobPattern.matches(includePatterns[0], against: "https://www.vip.com/video/123"))

        // 应该匹配排除模式
        XCTAssertTrue(GlobPattern.matches(excludePatterns[0], against: "https://www.vip.com/login"))

        // 排除后不应该缓存
        let url = URL(string: "https://www.vip.com/login")!
        let shouldCache = includePatterns.contains { pattern in
            guard GlobPattern.matches(pattern, against: url.absoluteString) else { return true }
            return !excludePatterns.contains { excludePattern in
                GlobPattern.matches(excludePattern, against: url.absoluteString)
            }
        }
        XCTAssertFalse(shouldCache, "Login page should be excluded from caching")
    }
}
