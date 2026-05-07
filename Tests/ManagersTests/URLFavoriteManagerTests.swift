//
//  URLFavoriteManagerTests.swift
//  ManagersTests
//
//  Created for WebBridgeKit test coverage.
//

import XCTest
@testable import WebBridgeKit
import RealmSwift

final class URLFavoriteManagerTests: XCTestCase {

    private var sut: URLFavoriteManager!
    private var testRealmConfig: Realm.Configuration!

    override func setUp() {
        super.setUp()
        testRealmConfig = Realm.Configuration(
            inMemoryIdentifier: "TestFavorites_\(UUID().uuidString)"
        )
        sut = URLFavoriteManager.shared
    }

    override func tearDown() {
        sut = nil
        testRealmConfig = nil
        super.tearDown()
    }

    // MARK: - Singleton

    func testShared_shouldReturnSameInstance() {
        let instance1 = URLFavoriteManager.shared
        let instance2 = URLFavoriteManager.shared
        XCTAssertTrue(instance1 === instance2, "shared should always return the same singleton instance")
    }

    // MARK: - URLFavorite Model Tests

    func testURLFavorite_shouldHavePrimaryKey() {
        XCTAssertEqual(URLFavorite.primaryKey(), "id", "Primary key should be 'id'")
    }

    func testURLFavorite_shouldHaveIndexedProperties() {
        let indexed = URLFavorite.indexedProperties()
        XCTAssertTrue(indexed.contains("url"), "url should be indexed")
        XCTAssertTrue(indexed.contains("isPinned"), "isPinned should be indexed")
        XCTAssertTrue(indexed.contains("sortOrder"), "sortOrder should be indexed")
    }

    func testURLFavorite_shouldGenerateUUID() {
        let favorite = URLFavorite()
        XCTAssertFalse(favorite.id.isEmpty, "id should not be empty")
        XCTAssertEqual(favorite.id.count, 36, "UUID string should be 36 characters")
    }

    func testURLFavorite_shouldHaveDefaultValues() {
        let favorite = URLFavorite()
        XCTAssertEqual(favorite.url, "", "Default url should be empty string")
        XCTAssertNil(favorite.title, "Default title should be nil")
        XCTAssertNil(favorite.favicon, "Default favicon should be nil")
        XCTAssertFalse(favorite.isPinned, "Default isPinned should be false")
        XCTAssertEqual(favorite.sortOrder, 0, "Default sortOrder should be 0")
        XCTAssertFalse(favorite.enableCacheMode, "Default enableCacheMode should be false")
    }

    func testURLFavorite_domain_shouldReturnHost() {
        let favorite = URLFavorite()
        favorite.url = "https://www.example.com/path"
        XCTAssertEqual(favorite.domain, "www.example.com", "domain should return the host")
    }

    func testURLFavorite_domain_shouldReturnNilForInvalidURL() {
        let favorite = URLFavorite()
        favorite.url = "not a valid url with spaces"
        XCTAssertNil(favorite.domain, "domain should be nil for invalid URL")
    }

    func testURLFavorite_domain_shouldReturnNilForEmptyURL() {
        let favorite = URLFavorite()
        favorite.url = ""
        XCTAssertNil(favorite.domain, "domain should be nil for empty URL")
    }

    func testURLFavorite_formattedCreatedAt_shouldReturnFormattedDate() {
        let favorite = URLFavorite()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let expected = formatter.string(from: favorite.createdAt)
        XCTAssertEqual(favorite.formattedCreatedAt, expected, "formattedCreatedAt should match expected format")
    }

    func testURLFavorite_identity_shouldReturnId() {
        let favorite = URLFavorite()
        XCTAssertEqual(favorite.identity, favorite.id, "identity should return id for IdentifiableType")
    }

    // MARK: - FavoriteDatabaseActor Tests (via in-memory Realm)

    private func createActor() -> FavoriteDatabaseActor {
        return FavoriteDatabaseActor(realmConfiguration: testRealmConfig)
    }

    // MARK: Add Favorite

    func testActor_addFavorite_shouldCreateNewFavorite() async throws {
        let actor = createActor()
        let url = URL(string: "https://example.com")!

        let favorite = try await actor.addFavorite(url: url, title: "Example")

        XCTAssertEqual(favorite.url, "https://example.com")
        XCTAssertEqual(favorite.title, "Example")
        XCTAssertFalse(favorite.isPinned)
        XCTAssertEqual(favorite.sortOrder, 0)
    }

    func testActor_addFavorite_shouldUseHostAsDefaultTitle() async throws {
        let actor = createActor()
        let url = URL(string: "https://example.com/page")!

        let favorite = try await actor.addFavorite(url: url)

        XCTAssertEqual(favorite.title, "example.com", "Title should default to URL host")
    }

    func testActor_addFavorite_shouldIncrementSortOrder() async throws {
        let actor = createActor()
        let url1 = URL(string: "https://example1.com")!
        let url2 = URL(string: "https://example2.com")!

        _ = try await actor.addFavorite(url: url1)
        let favorite2 = try await actor.addFavorite(url: url2)

        XCTAssertEqual(favorite2.sortOrder, 1, "Second favorite should have sortOrder 1")
    }

    func testActor_addFavorite_shouldUpdateExistingFavorite() async throws {
        let actor = createActor()
        let url = URL(string: "https://example.com")!

        _ = try await actor.addFavorite(url: url, title: "Original")
        let updated = try await actor.addFavorite(url: url, title: "Updated")

        XCTAssertEqual(updated.title, "Updated", "Adding duplicate URL should update title")
    }

    func testActor_addFavorite_shouldStoreFavicon() async throws {
        let actor = createActor()
        let url = URL(string: "https://example.com")!
        let faviconData = Data([0x89, 0x50, 0x4E, 0x47])

        let favorite = try await actor.addFavorite(url: url, favicon: faviconData)

        XCTAssertEqual(favorite.favicon, faviconData, "Favicon data should be stored")
    }

    func testActor_addFavorite_shouldSetCreatedAt() async throws {
        let actor = createActor()
        let url = URL(string: "https://example.com")!
        let before = Date()

        let favorite = try await actor.addFavorite(url: url)
        let after = Date()

        XCTAssertGreaterThanOrEqual(favorite.createdAt, before, "createdAt should be >= before")
        XCTAssertLessThanOrEqual(favorite.createdAt, after, "createdAt should be <= after")
    }

    // MARK: Delete Favorite

    func testActor_deleteFavoriteById_shouldRemoveFavorite() async throws {
        let actor = createActor()
        let url = URL(string: "https://example.com")!
        let favorite = try await actor.addFavorite(url: url)

        try await actor.deleteFavorite(id: favorite.id)

        let found = try await actor.findFavorite(id: favorite.id)
        XCTAssertNil(found, "Deleted favorite should not be found")
    }

    func testActor_deleteFavoriteById_shouldThrowWhenNotFound() async {
        let actor = createActor()

        do {
            try await actor.deleteFavorite(id: "non-existent-id")
            XCTFail("Should throw error for non-existent ID")
        } catch let error as WebBridgeError {
            if case .invalidInput(let message) = error {
                XCTAssertTrue(message.contains("not found"), "Error should mention not found")
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testActor_deleteFavoriteByUrl_shouldRemoveFavorite() async throws {
        let actor = createActor()
        let url = URL(string: "https://example.com")!
        _ = try await actor.addFavorite(url: url)

        try await actor.deleteFavorite(url: url)

        let found = try await actor.findFavorite(url: url)
        XCTAssertNil(found, "Deleted favorite should not be found")
    }

    func testActor_deleteFavoriteByUrl_shouldThrowWhenNotFound() async {
        let actor = createActor()
        let url = URL(string: "https://nonexistent.com")!

        do {
            try await actor.deleteFavorite(url: url)
            XCTFail("Should throw error for non-existent URL")
        } catch let error as WebBridgeError {
            if case .invalidInput(let message) = error {
                XCTAssertTrue(message.contains("not found"), "Error should mention not found")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: Query Operations

    func testActor_getAllFavorites_shouldReturnAllSorted() async throws {
        let actor = createActor()
        _ = try await actor.addFavorite(url: URL(string: "https://a.com")!, title: "A")
        _ = try await actor.addFavorite(url: URL(string: "https://b.com")!, title: "B")

        let favorites = try await actor.getAllFavorites()

        XCTAssertEqual(favorites.count, 2, "Should return all favorites")
    }

    func testActor_findFavoriteByUrl_shouldReturnMatching() async throws {
        let actor = createActor()
        let url = URL(string: "https://example.com")!
        _ = try await actor.addFavorite(url: url, title: "Example")

        let found = try await actor.findFavorite(url: url)

        XCTAssertNotNil(found, "Should find favorite by URL")
        XCTAssertEqual(found?.title, "Example")
    }

    func testActor_findFavoriteByUrl_shouldReturnNilWhenNotFound() async throws {
        let actor = createActor()

        let found = try await actor.findFavorite(url: URL(string: "https://missing.com")!)

        XCTAssertNil(found, "Should return nil for missing URL")
    }

    func testActor_findFavoriteById_shouldReturnMatching() async throws {
        let actor = createActor()
        let favorite = try await actor.addFavorite(url: URL(string: "https://example.com")!)

        let found = try await actor.findFavorite(id: favorite.id)

        XCTAssertNotNil(found, "Should find favorite by ID")
        XCTAssertEqual(found?.url, "https://example.com")
    }

    func testActor_findFavoriteById_shouldReturnNilWhenNotFound() async throws {
        let actor = createActor()

        let found = try await actor.findFavorite(id: "nonexistent-id")

        XCTAssertNil(found, "Should return nil for missing ID")
    }

    func testActor_searchFavorites_shouldMatchTitle() async throws {
        let actor = createActor()
        _ = try await actor.addFavorite(url: URL(string: "https://example.com")!, title: "My Website")
        _ = try await actor.addFavorite(url: URL(string: "https://other.com")!, title: "Other Page")

        let results = try await actor.searchFavorites(keyword: "website")

        XCTAssertEqual(results.count, 1, "Should find one match for 'website'")
        XCTAssertEqual(results.first?.title, "My Website")
    }

    func testActor_searchFavorites_shouldMatchUrl() async throws {
        let actor = createActor()
        _ = try await actor.addFavorite(url: URL(string: "https://example.com/page")!, title: "Test")

        let results = try await actor.searchFavorites(keyword: "example")

        XCTAssertEqual(results.count, 1, "Should find match in URL")
    }

    func testActor_searchFavorites_shouldBeCaseInsensitive() async throws {
        let actor = createActor()
        _ = try await actor.addFavorite(url: URL(string: "https://example.com")!, title: "UPPERCASE Title")

        let results = try await actor.searchFavorites(keyword: "uppercase")

        XCTAssertEqual(results.count, 1, "Search should be case insensitive")
    }

    func testActor_searchFavorites_shouldReturnEmptyForNoMatch() async throws {
        let actor = createActor()
        _ = try await actor.addFavorite(url: URL(string: "https://example.com")!, title: "Test")

        let results = try await actor.searchFavorites(keyword: "zzzznonexistent")

        XCTAssertTrue(results.isEmpty, "Should return empty for no match")
    }

    func testActor_getTotalCount_shouldReturnCorrectCount() async throws {
        let actor = createActor()
        XCTAssertEqual(try await actor.getTotalCount(), 0, "Initial count should be 0")

        _ = try await actor.addFavorite(url: URL(string: "https://a.com")!)
        XCTAssertEqual(try await actor.getTotalCount(), 1, "Count should be 1 after adding")

        _ = try await actor.addFavorite(url: URL(string: "https://b.com")!)
        XCTAssertEqual(try await actor.getTotalCount(), 2, "Count should be 2 after adding second")
    }

    // MARK: - Toggle Pin

    func testActor_togglePin_shouldToggleFromFalseToTrue() async throws {
        let actor = createActor()
        let favorite = try await actor.addFavorite(url: URL(string: "https://example.com")!)

        let result = try await actor.togglePin(id: favorite.id)

        XCTAssertTrue(result, "Pin should be true after toggling from false")
    }

    func testActor_togglePin_shouldToggleBack() async throws {
        let actor = createActor()
        let favorite = try await actor.addFavorite(url: URL(string: "https://example.com")!)

        _ = try await actor.togglePin(id: favorite.id)
        let result = try await actor.togglePin(id: favorite.id)

        XCTAssertFalse(result, "Pin should be false after toggling back")
    }

    func testActor_togglePin_shouldThrowForNonExistentId() async {
        let actor = createActor()

        do {
            _ = try await actor.togglePin(id: "nonexistent")
            XCTFail("Should throw for non-existent ID")
        } catch let error as WebBridgeError {
            if case .invalidInput(let message) = error {
                XCTAssertTrue(message.contains("not found"))
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Cache Mode

    func testActor_updateCacheMode_shouldEnableCacheMode() async throws {
        let actor = createActor()
        let favorite = try await actor.addFavorite(url: URL(string: "https://example.com")!)

        try await actor.updateCacheMode(id: favorite.id, enabled: true)

        let found = try await actor.findFavorite(id: favorite.id)
        XCTAssertTrue(found?.enableCacheMode ?? false, "Cache mode should be enabled")
    }

    func testActor_updateCacheMode_shouldDisableCacheMode() async throws {
        let actor = createActor()
        let favorite = try await actor.addFavorite(url: URL(string: "https://example.com")!)

        try await actor.updateCacheMode(id: favorite.id, enabled: true)
        try await actor.updateCacheMode(id: favorite.id, enabled: false)

        let found = try await actor.findFavorite(id: favorite.id)
        XCTAssertFalse(found?.enableCacheMode ?? true, "Cache mode should be disabled")
    }

    func testActor_updateCacheMode_shouldThrowForNonExistentId() async {
        let actor = createActor()

        do {
            try await actor.updateCacheMode(id: "nonexistent", enabled: true)
            XCTFail("Should throw for non-existent ID")
        } catch let error as WebBridgeError {
            if case .invalidInput(let message) = error {
                XCTAssertTrue(message.contains("not found"))
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Sort Order

    func testActor_updateSortOrder_shouldUpdateOrder() async throws {
        let actor = createActor()
        let f1 = try await actor.addFavorite(url: URL(string: "https://a.com")!, title: "A")
        let f2 = try await actor.addFavorite(url: URL(string: "https://b.com")!, title: "B")

        try await actor.updateSortOrder(favorites: [f2, f1])

        let found1 = try await actor.findFavorite(id: f1.id)
        let found2 = try await actor.findFavorite(id: f2.id)

        XCTAssertEqual(found1?.sortOrder, 1, "First favorite should now be at sortOrder 1")
        XCTAssertEqual(found2?.sortOrder, 0, "Second favorite should now be at sortOrder 0")
    }

    func testActor_updateSortOrder_withEmptyArray_shouldNotThrow() async throws {
        let actor = createActor()

        XCTAssertNoThrow(try await actor.updateSortOrder(favorites: []),
                          "Updating sort order with empty array should not throw")
    }

    // MARK: - Update Favorite

    func testActor_updateFavorite_shouldPersistChanges() async throws {
        let actor = createActor()
        var favorite = try await actor.addFavorite(url: URL(string: "https://example.com")!, title: "Old")

        favorite.title = "New Title"
        try await actor.updateFavorite(favorite)

        let found = try await actor.findFavorite(id: favorite.id)
        XCTAssertEqual(found?.title, "New Title", "Title should be updated")
    }

    // MARK: - Sorted Results (pinned first)

    func testActor_getAllFavorites_shouldSortPinnedFirst() async throws {
        let actor = createActor()
        let f1 = try await actor.addFavorite(url: URL(string: "https://a.com")!, title: "A")
        let f2 = try await actor.addFavorite(url: URL(string: "https://b.com")!, title: "B")

        _ = try await actor.togglePin(id: f2.id)

        let all = try await actor.getAllFavorites()

        XCTAssertEqual(all.first?.url, "https://b.com", "Pinned item should come first")
        XCTAssertEqual(all.last?.url, "https://a.com", "Non-pinned item should come last")
    }
}
