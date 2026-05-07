//
//  MockFavoriteServiceAdvancedTests.swift
//  WebBridgeKitTests
//

import XCTest
@testable import WebBridgeKit

final class MockFavoriteServiceAdvancedTests: XCTestCase {

    private var sut: MockFavoriteService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = MockFavoriteService()
    }

    override func tearDownWithError() throws {
        sut = nil
        try super.tearDownWithError()
    }

    // MARK: - Initial State

    func testInitialStateIsEmpty() {
        XCTAssertEqual(sut.getTotalCount(), 0)
        XCTAssertTrue(sut.getAllFavoritesArray().isEmpty)
    }

    func testFindNonExistentReturnsNil() {
        XCTAssertNil(sut.findFavorite(url: URL(string: "https://nonexistent.com")!))
        XCTAssertNil(sut.findFavorite(id: "nonexistent-id"))
    }

    func testDeleteNonExistentDoesNotCrash() {
        sut.deleteFavorite(id: "nonexistent-id")
        sut.deleteFavorite(url: URL(string: "https://nonexistent.com")!)
        XCTAssertEqual(sut.getTotalCount(), 0)
    }

    func testTogglePinNonExistentReturnsFalse() {
        XCTAssertFalse(sut.togglePin(id: "nonexistent-id"))
    }

    func testUpdateCacheModeNonExistentDoesNotCrash() {
        sut.updateCacheMode(id: "nonexistent-id", enabled: true)
        XCTAssertEqual(sut.getTotalCount(), 0)
    }

    func testUpdateSortOrderEmptyDoesNotCrash() {
        sut.updateSortOrder(favorites: [])
        XCTAssertEqual(sut.getTotalCount(), 0)
    }

    // MARK: - addFavorite: Default Title

    func testAddFavoriteUsesHostAsDefaultTitle() {
        let url = URL(string: "https://www.example.com/path")!
        let favorite = sut.addFavorite(url: url, title: nil, favicon: nil)

        XCTAssertEqual(favorite?.title, "www.example.com")
    }

    func testAddFavoriteWithExplicitTitle() {
        let url = URL(string: "https://example.com")!
        let favorite = sut.addFavorite(url: url, title: "My Title", favicon: nil)

        XCTAssertEqual(favorite?.title, "My Title")
    }

    // MARK: - addFavorite: Duplicate Handling

    func testAddDuplicateFavoriteReturnsExistingAndPreservesTitle() {
        let url = URL(string: "https://example.com")!

        let first = sut.addFavorite(url: url, title: "First", favicon: nil)
        let second = sut.addFavorite(url: url, title: "Second", favicon: nil)

        XCTAssertEqual(first?.id, second?.id)
        XCTAssertEqual(second?.title, "First")
        XCTAssertEqual(sut.getTotalCount(), 1)
    }

    // MARK: - addFavorite: Favicon

    func testAddFavoriteStoresFavicon() {
        let url = URL(string: "https://example.com")!
        let faviconData = Data("favicon".utf8)

        let favorite = sut.addFavorite(url: url, title: "Example", favicon: faviconData)

        XCTAssertEqual(favorite?.favicon, faviconData)
    }

    func testAddDuplicateFavoriteUpdatesFaviconIfNil() {
        let url = URL(string: "https://example.com")!
        let laterFavicon = Data("later".utf8)

        sut.addFavorite(url: url, title: "Example", favicon: nil)
        let updated = sut.addFavorite(url: url, title: nil, favicon: laterFavicon)

        XCTAssertEqual(updated?.favicon, laterFavicon)
    }

    func testAddDuplicateFavoriteDoesNotOverwriteExistingFavicon() {
        let url = URL(string: "https://example.com")!
        let originalFavicon = Data("original".utf8)
        let newFavicon = Data("new".utf8)

        sut.addFavorite(url: url, title: "Example", favicon: originalFavicon)
        let updated = sut.addFavorite(url: url, title: nil, favicon: newFavicon)

        XCTAssertEqual(updated?.favicon, originalFavicon)
    }

    // MARK: - Sort Order

    func testAddFavoriteAssignsIncrementingSortOrder() {
        let fav1 = sut.addFavorite(url: URL(string: "https://a.com")!, title: "A", favicon: nil)
        let fav2 = sut.addFavorite(url: URL(string: "https://b.com")!, title: "B", favicon: nil)
        let fav3 = sut.addFavorite(url: URL(string: "https://c.com")!, title: "C", favicon: nil)

        XCTAssertEqual(fav1?.sortOrder, 0)
        XCTAssertEqual(fav2?.sortOrder, 1)
        XCTAssertEqual(fav3?.sortOrder, 2)
    }

    func testGetAllFavoritesArraySortedByPinThenOrder() {
        let fav1 = sut.addFavorite(url: URL(string: "https://a.com")!, title: "A", favicon: nil)
        let fav2 = sut.addFavorite(url: URL(string: "https://b.com")!, title: "B", favicon: nil)
        let fav3 = sut.addFavorite(url: URL(string: "https://c.com")!, title: "C", favicon: nil)

        sut.togglePin(id: fav2!.id)

        let sorted = sut.getAllFavoritesArray()
        XCTAssertEqual(sorted.count, 3)
        XCTAssertEqual(sorted[0].url, "https://b.com")
        XCTAssertTrue(sorted[0].isPinned)
    }

    func testUpdateSortOrderReordersItems() {
        let fav1 = sut.addFavorite(url: URL(string: "https://a.com")!, title: "A", favicon: nil)
        let fav2 = sut.addFavorite(url: URL(string: "https://b.com")!, title: "B", favicon: nil)
        let fav3 = sut.addFavorite(url: URL(string: "https://c.com")!, title: "C", favicon: nil)

        sut.updateSortOrder(favorites: [fav3!, fav1!, fav2!])

        let sorted = sut.getAllFavoritesArray()
        XCTAssertEqual(sorted[0].id, fav3?.id)
        XCTAssertEqual(sorted[1].id, fav1?.id)
        XCTAssertEqual(sorted[2].id, fav2?.id)
    }

    // MARK: - Pin Toggle

    func testTogglePinSwitchesState() {
        let fav = sut.addFavorite(url: URL(string: "https://example.com")!, title: "Example", favicon: nil)

        XCTAssertFalse(fav!.isPinned)

        let pinned = sut.togglePin(id: fav!.id)
        XCTAssertTrue(pinned)

        let found = sut.findFavorite(id: fav!.id)
        XCTAssertTrue(found?.isPinned ?? false)

        let unpinned = sut.togglePin(id: fav!.id)
        XCTAssertFalse(unpinned)
    }

    func testMultiplePinsSortedCorrectly() {
        let fav1 = sut.addFavorite(url: URL(string: "https://a.com")!, title: "A", favicon: nil)
        let fav2 = sut.addFavorite(url: URL(string: "https://b.com")!, title: "B", favicon: nil)
        let fav3 = sut.addFavorite(url: URL(string: "https://c.com")!, title: "C", favicon: nil)

        sut.togglePin(id: fav3!.id)
        sut.togglePin(id: fav1!.id)

        let sorted = sut.getAllFavoritesArray()
        XCTAssertTrue(sorted[0].isPinned)
        XCTAssertTrue(sorted[1].isPinned)
        XCTAssertFalse(sorted[2].isPinned)
    }

    // MARK: - Cache Mode

    func testUpdateCacheModeEnablesAndDisables() {
        let fav = sut.addFavorite(url: URL(string: "https://example.com")!, title: "Example", favicon: nil)

        XCTAssertFalse(fav!.enableCacheMode)

        sut.updateCacheMode(id: fav!.id, enabled: true)
        XCTAssertTrue(sut.findFavorite(id: fav!.id)?.enableCacheMode ?? false)

        sut.updateCacheMode(id: fav!.id, enabled: false)
        XCTAssertFalse(sut.findFavorite(id: fav!.id)?.enableCacheMode ?? true)
    }

    // MARK: - updateFavorite

    func testUpdateFavoriteModifiesTitle() {
        let fav = sut.addFavorite(url: URL(string: "https://example.com")!, title: "Original", favicon: nil)

        fav?.title = "Updated"
        if let fav = fav {
            sut.updateFavorite(fav)
        }

        XCTAssertEqual(sut.findFavorite(id: fav!.id)?.title, "Updated")
    }

    // MARK: - deleteFavorite

    func testDeleteByIdRemovesFavorite() {
        let fav = sut.addFavorite(url: URL(string: "https://example.com")!, title: "Example", favicon: nil)

        sut.deleteFavorite(id: fav!.id)

        XCTAssertNil(sut.findFavorite(id: fav!.id))
        XCTAssertEqual(sut.getTotalCount(), 0)
    }

    func testDeleteByUrlRemovesFavorite() {
        let url = URL(string: "https://example.com")!
        sut.addFavorite(url: url, title: "Example", favicon: nil)

        sut.deleteFavorite(url: url)

        XCTAssertNil(sut.findFavorite(url: url))
        XCTAssertEqual(sut.getTotalCount(), 0)
    }

    func testDeleteOneFavoriteDoesNotAffectOthers() {
        let favA = sut.addFavorite(url: URL(string: "https://a.com")!, title: "A", favicon: nil)
        sut.addFavorite(url: URL(string: "https://b.com")!, title: "B", favicon: nil)

        sut.deleteFavorite(id: favA!.id)

        XCTAssertEqual(sut.getTotalCount(), 1)
        XCTAssertNotNil(sut.findFavorite(url: URL(string: "https://b.com")!))
    }

    // MARK: - addMockData

    func testAddMockDataWithTitles() {
        sut.addMockData(
            urls: ["https://apple.com", "https://google.com"],
            titles: ["Apple", "Google"]
        )

        XCTAssertEqual(sut.getTotalCount(), 2)
        XCTAssertEqual(sut.findFavorite(url: URL(string: "https://apple.com")!)?.title, "Apple")
        XCTAssertEqual(sut.findFavorite(url: URL(string: "https://google.com")!)?.title, "Google")
    }

    func testAddMockDataWithInvalidURLsSkipped() {
        sut.addMockData(urls: ["not-a-url", "", "https://valid.com"])
        XCTAssertGreaterThanOrEqual(sut.getTotalCount(), 1)
        XCTAssertNotNil(sut.findFavorite(url: URL(string: "https://valid.com")!))
    }

    func testAddMockDataEmptyArray() {
        sut.addMockData(urls: [])
        XCTAssertEqual(sut.getTotalCount(), 0)
    }

    func testClearMockDataRemovesAll() {
        sut.addMockData(urls: ["https://a.com", "https://b.com", "https://c.com"])
        XCTAssertEqual(sut.getTotalCount(), 3)

        sut.clearMockData()
        XCTAssertEqual(sut.getTotalCount(), 0)
    }

    // MARK: - In-Memory Realm Mode

    func testInMemoryRealmModeInitialization() {
        let realmSut = MockFavoriteService(useInMemoryRealm: true)
        realmSut.clearMockData()
        XCTAssertEqual(realmSut.getTotalCount(), 0)
    }

    func testInMemoryRealmModeAddAndFind() {
        let realmSut = MockFavoriteService(useInMemoryRealm: true)
        realmSut.clearMockData()
        let url = URL(string: "https://example.com")!

        let favorite = realmSut.addFavorite(url: url, title: "Example", favicon: nil)

        XCTAssertNotNil(favorite)
        XCTAssertEqual(favorite?.url, "https://example.com")

        let found = realmSut.findFavorite(url: url)
        XCTAssertNotNil(found)
    }

    func testInMemoryRealmModeTogglePin() {
        let realmSut = MockFavoriteService(useInMemoryRealm: true)
        realmSut.clearMockData()
        let url = URL(string: "https://example.com")!

        let favorite = realmSut.addFavorite(url: url, title: "Example", favicon: nil)
        XCTAssertFalse(favorite!.isPinned)

        let pinned = realmSut.togglePin(id: favorite!.id)
        XCTAssertTrue(pinned)
    }

    func testInMemoryRealmModeUpdateCacheMode() {
        let realmSut = MockFavoriteService(useInMemoryRealm: true)
        realmSut.clearMockData()
        let url = URL(string: "https://example.com")!

        let favorite = realmSut.addFavorite(url: url, title: "Example", favicon: nil)
        realmSut.updateCacheMode(id: favorite!.id, enabled: true)

        let found = realmSut.findFavorite(id: favorite!.id)
        XCTAssertTrue(found?.enableCacheMode ?? false)
    }

    func testInMemoryRealmModeDelete() {
        let realmSut = MockFavoriteService(useInMemoryRealm: true)
        realmSut.clearMockData()
        let url = URL(string: "https://example.com")!

        let favorite = realmSut.addFavorite(url: url, title: "Example", favicon: nil)
        let favoriteId = favorite!.id
        realmSut.deleteFavorite(id: favoriteId)

        XCTAssertEqual(realmSut.getTotalCount(), 0)
    }

    func testInMemoryRealmModeUpdateSortOrder() {
        let realmSut = MockFavoriteService(useInMemoryRealm: true)
        realmSut.clearMockData()
        let fav1 = realmSut.addFavorite(url: URL(string: "https://a.com")!, title: "A", favicon: nil)
        let fav2 = realmSut.addFavorite(url: URL(string: "https://b.com")!, title: "B", favicon: nil)

        realmSut.updateSortOrder(favorites: [fav2!, fav1!])

        let sorted = realmSut.getAllFavoritesArray()
        XCTAssertEqual(sorted[0].id, fav2?.id)
        XCTAssertEqual(sorted[1].id, fav1?.id)
    }

    func testInMemoryRealmModeGetAllFavoritesArray() {
        let realmSut = MockFavoriteService(useInMemoryRealm: true)
        realmSut.clearMockData()
        realmSut.addFavorite(url: URL(string: "https://a.com")!, title: "A", favicon: nil)
        realmSut.addFavorite(url: URL(string: "https://b.com")!, title: "B", favicon: nil)

        let all = realmSut.getAllFavoritesArray()
        XCTAssertEqual(all.count, 2)
    }

    // MARK: - Protocol Conformance

    func testConformsToFavoriteServiceProtocol() {
        let service: FavoriteServiceProtocol = MockFavoriteService()
        let fav = service.addFavorite(url: URL(string: "https://test.com")!, title: "Test", favicon: nil)

        XCTAssertNotNil(fav)
        XCTAssertEqual(service.getTotalCount(), 1)
    }
}
