//
//  URLFavoriteTests.swift
//  ModelsTests
//

import XCTest
@testable import WebBridgeKit

final class URLFavoriteTests: XCTestCase {

    // MARK: - Primary Key

    func testPrimaryKeyIsID() {
        XCTAssertEqual(URLFavorite.primaryKey(), "id")
    }

    // MARK: - Indexed Properties

    func testIndexedProperties() {
        let indexed = URLFavorite.indexedProperties()
        XCTAssertTrue(indexed.contains("url"))
        XCTAssertTrue(indexed.contains("isPinned"))
        XCTAssertTrue(indexed.contains("sortOrder"))
    }

    // MARK: - Default Values

    func testDefaultValues() {
        let favorite = URLFavorite()
        XCTAssertFalse(favorite.id.isEmpty)
        XCTAssertEqual(favorite.url, "")
        XCTAssertNil(favorite.title)
        XCTAssertNil(favorite.favicon)
        XCTAssertFalse(favorite.isPinned)
        XCTAssertEqual(favorite.sortOrder, 0)
        XCTAssertFalse(favorite.enableCacheMode)
    }

    // MARK: - Unique IDs

    func testUniqueIDsAreGenerated() {
        let f1 = URLFavorite()
        let f2 = URLFavorite()
        XCTAssertNotEqual(f1.id, f2.id)
    }

    // MARK: - Formatted Created At

    func testFormattedCreatedAtContainsDate() {
        let favorite = URLFavorite()
        let formatted = favorite.formattedCreatedAt
        XCTAssertFalse(formatted.isEmpty)
        XCTAssertTrue(formatted.contains("-"))
        XCTAssertTrue(formatted.contains(":"))
    }

    // MARK: - Domain Extraction

    func testDomainExtractionWithValidURL() {
        let favorite = URLFavorite()
        favorite.url = "https://www.example.com/page"
        XCTAssertEqual(favorite.domain, "www.example.com")
    }

    func testDomainExtractionWithSimpleURL() {
        let favorite = URLFavorite()
        favorite.url = "https://example.com"
        XCTAssertEqual(favorite.domain, "example.com")
    }

    func testDomainReturnsNilForInvalidURL() {
        let favorite = URLFavorite()
        favorite.url = "not a url"
        XCTAssertNil(favorite.domain)
    }

    func testDomainReturnsNilForEmptyURL() {
        let favorite = URLFavorite()
        XCTAssertNil(favorite.domain)
    }

    // MARK: - Identity (IdentifiableType)

    func testIdentityReturnsID() {
        let favorite = URLFavorite()
        XCTAssertEqual(favorite.identity, favorite.id)
    }

    // MARK: - Property Assignment

    func testPropertyAssignment() {
        let favorite = URLFavorite()
        favorite.url = "https://example.com"
        favorite.title = "Example Site"
        favorite.isPinned = true
        favorite.sortOrder = 10
        favorite.enableCacheMode = true

        XCTAssertEqual(favorite.url, "https://example.com")
        XCTAssertEqual(favorite.title, "Example Site")
        XCTAssertTrue(favorite.isPinned)
        XCTAssertEqual(favorite.sortOrder, 10)
        XCTAssertTrue(favorite.enableCacheMode)
    }
}
