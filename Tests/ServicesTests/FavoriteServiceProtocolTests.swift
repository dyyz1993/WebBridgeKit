//
//  FavoriteServiceProtocolTests.swift
//  ServicesTests
//

import XCTest
@testable import WebBridgeKit

final class FavoriteServiceProtocolTests: XCTestCase {

    private var sut: MockFavoriteService!

    override func setUp() {
        super.setUp()
        sut = MockFavoriteService()
    }

    override func tearDown() {
        sut.clearMockData()
        sut = nil
        super.tearDown()
    }

    func testAddFavoriteReturnsFavorite() {
        let url = URL(string: "https://example.com")!
        let favorite = sut.addFavorite(url: url, title: "Example", favicon: nil)

        XCTAssertNotNil(favorite)
        XCTAssertEqual(favorite?.url, "https://example.com")
        XCTAssertEqual(favorite?.title, "Example")
        XCTAssertNotNil(favorite?.id)
    }

    func testAddFavoriteWithFavicon() {
        let url = URL(string: "https://example.com")!
        let faviconData = Data("icon".utf8)
        let favorite = sut.addFavorite(url: url, title: "Example", favicon: faviconData)

        XCTAssertEqual(favorite?.favicon, faviconData)
    }

    func testAddFavoriteDefaultTitle() {
        let url = URL(string: "https://www.example.com/path")!
        let favorite = sut.addFavorite(url: url, title: nil, favicon: nil)

        XCTAssertEqual(favorite?.title, "www.example.com")
    }

    func testUpdateFavorite() {
        let url = URL(string: "https://example.com")!
        let favorite = sut.addFavorite(url: url, title: "Original", favicon: nil)!
        favorite.title = "Updated"
        sut.updateFavorite(favorite)

        let found = sut.findFavorite(id: favorite.id)
        XCTAssertEqual(found?.title, "Updated")
    }

    func testDeleteFavoriteByID() {
        let url = URL(string: "https://example.com")!
        let favorite = sut.addFavorite(url: url, title: "Test", favicon: nil)!

        sut.deleteFavorite(id: favorite.id)
        XCTAssertEqual(sut.getTotalCount(), 0)
    }

    func testDeleteFavoriteByURL() {
        let url = URL(string: "https://example.com")!
        sut.addFavorite(url: url, title: "Test", favicon: nil)

        sut.deleteFavorite(url: url)
        XCTAssertEqual(sut.getTotalCount(), 0)
    }

    func testFindFavoriteByURL() {
        let url = URL(string: "https://example.com")!
        sut.addFavorite(url: url, title: "Test", favicon: nil)

        let found = sut.findFavorite(url: url)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.url, "https://example.com")
    }

    func testFindFavoriteByURLNotFound() {
        XCTAssertNil(sut.findFavorite(url: URL(string: "https://nonexistent.com")!))
    }

    func testFindFavoriteByID() {
        let url = URL(string: "https://example.com")!
        let favorite = sut.addFavorite(url: url, title: "Test", favicon: nil)!

        let found = sut.findFavorite(id: favorite.id)
        XCTAssertNotNil(found)
    }

    func testFindFavoriteByIDNotFound() {
        XCTAssertNil(sut.findFavorite(id: "nonexistent"))
    }

    func testGetTotalCount() {
        sut.addFavorite(url: URL(string: "https://a.com")!, title: nil, favicon: nil)
        sut.addFavorite(url: URL(string: "https://b.com")!, title: nil, favicon: nil)
        XCTAssertEqual(sut.getTotalCount(), 2)
    }

    func testTogglePin() {
        let url = URL(string: "https://example.com")!
        let favorite = sut.addFavorite(url: url, title: "Test", favicon: nil)!

        let pinned = sut.togglePin(id: favorite.id)
        XCTAssertTrue(pinned)

        let unpinned = sut.togglePin(id: favorite.id)
        XCTAssertFalse(unpinned)
    }

    func testTogglePinNonExistentReturnsFalse() {
        XCTAssertFalse(sut.togglePin(id: "nonexistent"))
    }

    func testUpdateCacheMode() {
        let url = URL(string: "https://example.com")!
        let favorite = sut.addFavorite(url: url, title: "Test", favicon: nil)!

        sut.updateCacheMode(id: favorite.id, enabled: true)
        let found = sut.findFavorite(id: favorite.id)
        XCTAssertTrue(found?.enableCacheMode ?? false)
    }

    func testUpdateSortOrder() {
        let f1 = sut.addFavorite(url: URL(string: "https://a.com")!, title: "A", favicon: nil)!
        let f2 = sut.addFavorite(url: URL(string: "https://b.com")!, title: "B", favicon: nil)!

        sut.updateSortOrder(favorites: [f2, f1])

        let found2 = sut.findFavorite(id: f2.id)
        let found1 = sut.findFavorite(id: f1.id)
        XCTAssertLessThan(found2?.sortOrder ?? 1, found1?.sortOrder ?? 0)
    }

    func testDuplicateFavoriteReturnsSame() {
        let url = URL(string: "https://example.com")!
        let first = sut.addFavorite(url: url, title: "First", favicon: nil)
        let second = sut.addFavorite(url: url, title: "Second", favicon: nil)

        XCTAssertEqual(first?.id, second?.id)
        XCTAssertEqual(sut.getTotalCount(), 1)
    }

    func testSearchFavoritesByURL() {
        sut.addFavorite(url: URL(string: "https://github.com/repo")!, title: "Repo", favicon: nil)
        sut.addFavorite(url: URL(string: "https://example.com")!, title: "Other", favicon: nil)

        let results = sut.searchFavorites(keyword: "github")
        XCTAssertEqual(results.count, 1)
    }

    func testSearchFavoritesArrayByURL() {
        sut.addFavorite(url: URL(string: "https://github.com/repo")!, title: "Repo", favicon: nil)
        sut.addFavorite(url: URL(string: "https://example.com")!, title: "Other", favicon: nil)

        let array = sut.getAllFavoritesArray()
        XCTAssertEqual(array.count, 2)
    }

    func testGetAllFavoritesArraySorted() {
        sut.addFavorite(url: URL(string: "https://a.com")!, title: "A", favicon: nil)
        sut.addFavorite(url: URL(string: "https://b.com")!, title: "B", favicon: nil)

        let array = sut.getAllFavoritesArray()
        XCTAssertEqual(array.count, 2)
    }
}
