//
//  WebPageHistoryTests.swift
//  ModelsTests
//

import XCTest
@testable import WebBridgeKit

final class WebPageHistoryTests: XCTestCase {

    // MARK: - Primary Key

    func testPrimaryKeyIsID() {
        XCTAssertEqual(WebPageHistory.primaryKey(), "id")
    }

    // MARK: - Indexed Properties

    func testIndexedProperties() {
        let indexed = WebPageHistory.indexedProperties()
        XCTAssertTrue(indexed.contains("url"))
        XCTAssertTrue(indexed.contains("isCached"))
        XCTAssertTrue(indexed.contains("lastVisitDate"))
        XCTAssertTrue(indexed.contains("ruleId"))
    }

    // MARK: - Default Values

    func testDefaultValues() {
        let history = WebPageHistory()
        XCTAssertFalse(history.id.isEmpty)
        XCTAssertEqual(history.url, "")
        XCTAssertNil(history.title)
        XCTAssertNil(history.favicon)
        XCTAssertNil(history.htmlPath)
        XCTAssertEqual(history.cachedSize, 0)
        XCTAssertFalse(history.isCached)
        XCTAssertFalse(history.isPinned)
        XCTAssertFalse(history.isFavorite)
        XCTAssertEqual(history.visitCount, 0)
        XCTAssertFalse(history.isExcluded)
        XCTAssertNil(history.ruleId)
        XCTAssertNil(history.ruleName)
        XCTAssertNil(history.cacheDate)
        XCTAssertNil(history.thumbnail)
    }

    // MARK: - Formatted Size

    func testFormattedSizeZeroBytes() {
        let history = WebPageHistory()
        history.cachedSize = 0
        XCTAssertFalse(history.formattedSize.isEmpty, "formattedSize should not be empty for zero bytes")
    }

    func testFormattedSizeKB() {
        let history = WebPageHistory()
        history.cachedSize = 2048
        XCTAssertTrue(history.formattedSize.contains("KB"))
    }

    func testFormattedSizeMB() {
        let history = WebPageHistory()
        history.cachedSize = 5 * 1024 * 1024
        XCTAssertTrue(history.formattedSize.contains("MB"))
    }

    // MARK: - Has Thumbnail

    func testHasThumbnailFalseWhenNil() {
        let history = WebPageHistory()
        XCTAssertFalse(history.hasThumbnail)
    }

    // MARK: - Cache Directory

    func testCacheDirectoryNilWhenNotCached() {
        let history = WebPageHistory()
        XCTAssertNil(history.cacheDirectory)
    }

    // MARK: - Unique IDs

    func testUniqueIDsAreGenerated() {
        let h1 = WebPageHistory()
        let h2 = WebPageHistory()
        XCTAssertNotEqual(h1.id, h2.id)
    }

    // MARK: - Property Assignment

    func testPropertyAssignment() {
        let history = WebPageHistory()
        history.url = "https://example.com"
        history.title = "Example"
        history.isCached = true
        history.isPinned = true
        history.isFavorite = true
        history.visitCount = 5
        history.ruleId = "rule-1"
        history.ruleName = "Test Rule"

        XCTAssertEqual(history.url, "https://example.com")
        XCTAssertEqual(history.title, "Example")
        XCTAssertTrue(history.isCached)
        XCTAssertTrue(history.isPinned)
        XCTAssertTrue(history.isFavorite)
        XCTAssertEqual(history.visitCount, 5)
        XCTAssertEqual(history.ruleId, "rule-1")
        XCTAssertEqual(history.ruleName, "Test Rule")
    }
}
