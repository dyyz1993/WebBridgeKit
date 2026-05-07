import XCTest
@testable import WebBridgeKit

final class GlobPatternTests: XCTestCase {

    func testSingleWildcardMatches() {
        XCTAssertTrue(GlobPattern.matches("*.js", against: "app.js"))
        XCTAssertTrue(GlobPattern.matches("*.js", against: "index.js"))
    }

    func testSingleWildcardNoMatch() {
        XCTAssertFalse(GlobPattern.matches("*.js", against: "app.css"))
        XCTAssertFalse(GlobPattern.matches("*.js", against: "app.js.bak"))
    }

    func testQuestionMarkMatchesSingleChar() {
        XCTAssertTrue(GlobPattern.matches("file?.txt", against: "file1.txt"))
        XCTAssertTrue(GlobPattern.matches("file?.txt", against: "fileA.txt"))
    }

    func testQuestionMarkNoMatchMultipleChars() {
        XCTAssertFalse(GlobPattern.matches("file?.txt", against: "file10.txt"))
    }

    func testDoubleWildcardPathSegments() {
        XCTAssertTrue(GlobPattern.matches("https://example.com/**", against: "https://example.com/path/to/file.js"))
        XCTAssertTrue(GlobPattern.matches("https://example.com/**", against: "https://example.com/"))
    }

    func testDoubleWildcardDeepPath() {
        XCTAssertTrue(GlobPattern.matches("**/*.min.js", against: "path/to/jquery.min.js"))
        XCTAssertTrue(GlobPattern.matches("**/*.min.js", against: "jquery.min.js"))
    }

    func testSingleWildcardNoPathTraversal() {
        XCTAssertTrue(GlobPattern.matches("https://example.com/*.js", against: "https://example.com/app.js"))
        XCTAssertFalse(GlobPattern.matches("https://example.com/*.js", against: "https://example.com/path/app.js"))
    }

    func testCharacterClassMatch() {
        XCTAssertTrue(GlobPattern.matches("file[123].txt", against: "file1.txt"))
        XCTAssertTrue(GlobPattern.matches("file[123].txt", against: "file2.txt"))
        XCTAssertTrue(GlobPattern.matches("file[123].txt", against: "file3.txt"))
    }

    func testCharacterClassNoMatch() {
        XCTAssertFalse(GlobPattern.matches("file[123].txt", against: "file4.txt"))
        XCTAssertFalse(GlobPattern.matches("file[123].txt", against: "fileA.txt"))
    }

    func testNegatedCharacterClass() {
        XCTAssertFalse(GlobPattern.matches("file[!123].txt", against: "file1.txt"))
        XCTAssertTrue(GlobPattern.matches("file[!123].txt", against: "file4.txt"))
        XCTAssertTrue(GlobPattern.matches("file[!123].txt", against: "fileA.txt"))
    }

    func testExactMatch() {
        XCTAssertTrue(GlobPattern.matches("exact", against: "exact"))
    }

    func testExactNoMatch() {
        XCTAssertFalse(GlobPattern.matches("exact", against: "notexact"))
    }

    func testEmptyPatternAndText() {
        XCTAssertTrue(GlobPattern.matches("", against: ""))
    }

    func testFilterReturnsMatching() {
        let texts = ["app.js", "style.css", "main.js", "index.html"]
        let result = GlobPattern.filter("*.js", texts: texts)
        XCTAssertEqual(result, ["app.js", "main.js"])
    }

    func testFilterNoMatches() {
        let texts = ["app.js", "style.css"]
        let result = GlobPattern.filter("*.png", texts: texts)
        XCTAssertTrue(result.isEmpty)
    }

    func testFilterAllMatch() {
        let texts = ["a.js", "b.js"]
        let result = GlobPattern.filter("*.js", texts: texts)
        XCTAssertEqual(result.count, 2)
    }

    func testGitHubDoubleWildcard() {
        XCTAssertTrue(GlobPattern.matches("https://github.com/**", against: "https://github.com"))
        XCTAssertTrue(GlobPattern.matches("https://github.com/**", against: "https://github.com/user/repo"))
        XCTAssertTrue(GlobPattern.matches("https://github.com/**", against: "https://github.com/user/repo/issues"))
    }

    func testSubdomainWildcard() {
        XCTAssertTrue(GlobPattern.matches("https://*.example.com/**", against: "https://api.example.com/v1/users"))
        XCTAssertFalse(GlobPattern.matches("https://*.example.com/**", against: "https://example.com/v1/users"))
    }

    func testMultipleWildcards() {
        XCTAssertTrue(GlobPattern.matches("https://api.*.com/**", against: "https://api.example.com/v1/users"))
    }

    func testSpecialCharactersInText() {
        XCTAssertFalse(GlobPattern.matches("test.js", against: "test.js?query=1"))
    }

    func testPatternWithDots() {
        XCTAssertTrue(GlobPattern.matches("file.txt", against: "file.txt"))
    }

    func testUrlWithPort() {
        XCTAssertTrue(GlobPattern.matches("http://localhost:*/api", against: "http://localhost:8080/api"))
    }

    func testHttpsScheme() {
        XCTAssertTrue(GlobPattern.matches("https://example.com/images/*.png", against: "https://example.com/images/logo.png"))
        XCTAssertFalse(GlobPattern.matches("https://example.com/images/*.png", against: "https://example.com/images/sub/logo.png"))
    }
}
