//
//  DebugErrorPageManagerTests.swift
//  UtilsTests
//

import XCTest
@testable import WebBridgeKit

final class DebugErrorPageManagerTests: XCTestCase {

    private var sut: DebugErrorPageManager!

    override func setUp() {
        super.setUp()
        sut = DebugErrorPageManager.shared
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testSharedSingleton() {
        XCTAssertNotNil(DebugErrorPageManager.shared)
        XCTAssertTrue(DebugErrorPageManager.shared === DebugErrorPageManager.shared)
    }

    func testGenerateErrorPageContainsURL() {
        let url = URL(string: "https://example.com/test")!
        let error = NSError(domain: "TestError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Not Found"])
        let html = sut.generateErrorPage(url: url, error: error)

        XCTAssertTrue(html.contains("https://example.com/test"))
    }

    func testGenerateErrorPageContainsErrorMessage() {
        let url = URL(string: "https://example.com")!
        let error = NSError(domain: "TestError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Internal Server Error"])
        let html = sut.generateErrorPage(url: url, error: error)

        XCTAssertTrue(html.contains("Internal Server Error"))
    }

    func testGenerateErrorPageWithDebugInfo() {
        let url = URL(string: "https://example.com")!
        let error = NSError(domain: "Test", code: 0, userInfo: nil)
        let debugInfo: [String: Any] = ["statusCode": 500, "retryCount": 3]
        let html = sut.generateErrorPage(url: url, error: error, debugInfo: debugInfo)

        XCTAssertTrue(html.contains("调试信息"))
        XCTAssertTrue(html.contains("statusCode"))
        XCTAssertTrue(html.contains("retryCount"))
    }

    func testGenerateErrorPageWithNilDebugInfo() {
        let url = URL(string: "https://example.com")!
        let error = NSError(domain: "Test", code: 0, userInfo: nil)
        let html = sut.generateErrorPage(url: url, error: error, debugInfo: nil)

        XCTAssertFalse(html.contains("调试信息"))
    }

    func testGenerateErrorPageHTMLStructure() {
        let url = URL(string: "https://example.com")!
        let error = NSError(domain: "Test", code: 0, userInfo: nil)
        let html = sut.generateErrorPage(url: url, error: error)

        XCTAssertTrue(html.contains("<!DOCTYPE html>"))
        XCTAssertTrue(html.contains("<html>"))
        XCTAssertTrue(html.contains("<head>"))
        XCTAssertTrue(html.contains("</html>"))
        XCTAssertTrue(html.contains("</body>"))
    }

    func testGenerateErrorPageContainsReloadButton() {
        let url = URL(string: "https://example.com")!
        let error = NSError(domain: "Test", code: 0, userInfo: nil)
        let html = sut.generateErrorPage(url: url, error: error)

        XCTAssertTrue(html.contains("重新加载") || html.contains("reload"))
    }

    func testGenerateErrorPageContainsCopyButton() {
        let url = URL(string: "https://example.com")!
        let error = NSError(domain: "Test", code: 0, userInfo: nil)
        let html = sut.generateErrorPage(url: url, error: error)

        XCTAssertTrue(html.contains("复制 URL") || html.contains("copy"))
    }

    func testGenerateErrorPageContainsTitle() {
        let url = URL(string: "https://example.com")!
        let error = NSError(domain: "Test", code: 0, userInfo: nil)
        let html = sut.generateErrorPage(url: url, error: error)

        XCTAssertTrue(html.contains("加载失败"))
    }

    func testGenerateErrorPageWithDifferentErrorTypes() {
        let url = URL(string: "https://example.com")!

        let networkError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: [NSLocalizedDescriptionKey: "No internet"])
        let html = sut.generateErrorPage(url: url, error: networkError)
        XCTAssertTrue(html.contains("No internet"))
    }

    func testGenerateErrorPageDebugInfoSectionStructure() {
        let url = URL(string: "https://example.com")!
        let error = NSError(domain: "Test", code: 0, userInfo: nil)
        let debugInfo: [String: Any] = ["key1": "value1", "key2": 42]
        let html = sut.generateErrorPage(url: url, error: error, debugInfo: debugInfo)

        XCTAssertTrue(html.contains("debug-section"))
        XCTAssertTrue(html.contains("key1"))
        XCTAssertTrue(html.contains("value1"))
    }
}
