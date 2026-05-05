//
//  NetworkServiceTests.swift
//  WebBridgeKitTests
//

import XCTest
@testable import WebBridgeKit

final class NetworkServiceTests: XCTestCase {

    // MARK: - ServiceLocator

    func testServiceLocatorSharedInstance() {
        let instance1 = ServiceLocator.shared
        let instance2 = ServiceLocator.shared
        XCTAssertTrue(instance1 === instance2, "ServiceLocator.shared should return same instance")
    }

    func testServiceLocatorModeProduction() {
        ServiceLocator.shared.setupProductionServices()
        XCTAssertEqual(ServiceLocator.shared.currentMode, .production)
    }

    func testServiceLocatorModeMock() {
        ServiceLocator.shared.setupMockServices()
        XCTAssertEqual(ServiceLocator.shared.currentMode, .mock)
    }

    func testServiceLocatorMockWithSampleData() {
        ServiceLocator.shared.setupMockServicesWithSampleData()

        XCTAssertEqual(ServiceLocator.shared.currentMode, .mock)

        let historyService = ServiceLocator.shared.historyService
        let favoritesService = ServiceLocator.shared.favoriteService

        XCTAssertTrue(historyService is MockHistoryService)
        XCTAssertTrue(favoritesService is MockFavoriteService)
    }

    func testServiceLocatorRegistersCustomServices() {
        let mockHistory = MockHistoryService()
        let mockFavorite = MockFavoriteService()

        ServiceLocator.shared.registerCustomServices(
            historyService: mockHistory,
            favoriteService: mockFavorite
        )

        XCTAssertTrue(ServiceLocator.shared.historyService is MockHistoryService)
        XCTAssertTrue(ServiceLocator.shared.favoriteService is MockFavoriteService)
    }

    func testServiceLocatorConvenienceAccess() {
        ServiceLocator.shared.setupMockServices()

        let history = ServiceLocator.history
        let favorite = ServiceLocator.favorite

        XCTAssertNotNil(history as? MockHistoryService)
        XCTAssertNotNil(favorite as? MockFavoriteService)
    }

    func testServiceLocatorReset() {
        ServiceLocator.shared.setupMockServices()
        XCTAssertEqual(ServiceLocator.shared.currentMode, .mock)

        ServiceLocator.shared.reset()
        XCTAssertEqual(ServiceLocator.shared.currentMode, .production)
    }

    // MARK: - MockHistoryService: CRUD

    private var historyService: MockHistoryService!

    override func setUp() {
        super.setUp()
        historyService = MockHistoryService()
    }

    func testAddHistory() {
        let url = URL(string: "https://example.com")!
        historyService.addOrUpdateHistory(url: url, title: "Example", favicon: nil)

        let found = historyService.findHistory(url: url)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.url, "https://example.com")
        XCTAssertEqual(found?.title, "Example")
    }

    func testUpdateHistoryIncrementVisitCount() {
        let url = URL(string: "https://example.com")!
        historyService.addOrUpdateHistory(url: url, title: "Example", favicon: nil)
        historyService.addOrUpdateHistory(url: url, title: nil, favicon: nil)

        let found = historyService.findHistory(url: url)
        XCTAssertEqual(found?.visitCount, 2)
    }

    func testUpdateHistoryPreservesExistingTitle() {
        let url = URL(string: "https://example.com")!
        historyService.addOrUpdateHistory(url: url, title: "Original", favicon: nil)
        historyService.addOrUpdateHistory(url: url, title: "New", favicon: nil)

        let found = historyService.findHistory(url: url)
        XCTAssertEqual(found?.title, "Original")
    }

    func testDeleteHistoryById() {
        let url = URL(string: "https://example.com")!
        historyService.addOrUpdateHistory(url: url, title: "Example", favicon: nil)

        guard let found = historyService.findHistory(url: url) else {
            XCTFail("History should exist before deletion")
            return
        }
        historyService.deleteHistory(id: found.id)

        XCTAssertNil(historyService.findHistory(url: url))
    }

    func testClearAllHistory() {
        historyService.addOrUpdateHistory(url: URL(string: "https://a.com")!, title: "A", favicon: nil)
        historyService.addOrUpdateHistory(url: URL(string: "https://b.com")!, title: "B", favicon: nil)
        historyService.clearAllHistory()

        XCTAssertEqual(historyService.getAllHistories().count, 0)
    }

    func testGetAllHistoriesSortedByDate() {
        let urlA = URL(string: "https://a.com")!
        let urlB = URL(string: "https://b.com")!
        historyService.addOrUpdateHistory(url: urlA, title: "A", favicon: nil)
        historyService.addOrUpdateHistory(url: urlB, title: "B", favicon: nil)

        let all = historyService.getAllHistories()
        XCTAssertEqual(all.count, 2)
        XCTAssertGreaterThanOrEqual(all.first?.lastVisitDate ?? Date.distantPast,
                                    all.last?.lastVisitDate ?? Date.distantFuture)
    }

    func testFindHistoryById() {
        let url = URL(string: "https://example.com")!
        historyService.addOrUpdateHistory(url: url, title: "Example", favicon: nil)

        guard let added = historyService.findHistory(url: url) else {
            XCTFail("Should find history by URL")
            return
        }
        let found = historyService.findHistory(id: added.id)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.url, "https://example.com")
    }

    func testFindHistoryByNonExistentId() {
        XCTAssertNil(historyService.findHistory(id: "nonexistent-id"))
    }

    func testSearchHistoriesByUrl() {
        historyService.addOrUpdateHistory(url: URL(string: "https://github.com/test")!, title: "GitHub", favicon: nil)
        historyService.addOrUpdateHistory(url: URL(string: "https://example.com")!, title: "Example", favicon: nil)

        let results = historyService.searchHistories(keyword: "github")
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.first?.url.contains("github") ?? false)
    }

    func testSearchHistoriesByTitle() {
        historyService.addOrUpdateHistory(url: URL(string: "https://example.com")!, title: "Swift Programming", favicon: nil)
        historyService.addOrUpdateHistory(url: URL(string: "https://other.com")!, title: "Kotlin Guide", favicon: nil)

        let results = historyService.searchHistories(keyword: "swift")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Swift Programming")
    }

    func testSearchHistoriesCaseInsensitive() {
        historyService.addOrUpdateHistory(url: URL(string: "https://example.com")!, title: "GitHub", favicon: nil)

        let results = historyService.searchHistories(keyword: "GITHUB")
        XCTAssertEqual(results.count, 1)
    }

    func testGetTotalCount() {
        XCTAssertEqual(historyService.getTotalCount(), 0)

        historyService.addOrUpdateHistory(url: URL(string: "https://a.com")!, title: nil, favicon: nil)
        historyService.addOrUpdateHistory(url: URL(string: "https://b.com")!, title: nil, favicon: nil)

        XCTAssertEqual(historyService.getTotalCount(), 2)
    }

    func testAddMockData() {
        historyService.addMockData(urls: [
            "https://apple.com",
            "https://google.com",
            "https://github.com"
        ])

        XCTAssertEqual(historyService.getTotalCount(), 3)
    }

    func testAddMockDataWithTitles() {
        historyService.addMockData(
            urls: ["https://apple.com"],
            titles: ["Apple"]
        )

        let found = historyService.findHistory(url: URL(string: "https://apple.com")!)
        XCTAssertEqual(found?.title, "Apple")
    }

    func testAddMockDataInvalidURL() {
        historyService.addMockData(urls: ["", "http://[::1"])
        XCTAssertEqual(historyService.getTotalCount(), 0)
    }

    func testClearMockData() {
        historyService.addMockData(urls: ["https://a.com", "https://b.com"])
        XCTAssertEqual(historyService.getTotalCount(), 2)

        historyService.clearMockData()
        XCTAssertEqual(historyService.getTotalCount(), 0)
    }

    func testGetMostVisited() {
        let urlA = URL(string: "https://a.com")!
        let urlB = URL(string: "https://b.com")!

        historyService.addOrUpdateHistory(url: urlA, title: "A", favicon: nil)
        historyService.addOrUpdateHistory(url: urlA, title: nil, favicon: nil)
        historyService.addOrUpdateHistory(url: urlA, title: nil, favicon: nil)
        historyService.addOrUpdateHistory(url: urlB, title: "B", favicon: nil)

        let mostVisited = historyService.getMostVisited(limit: 1)
        XCTAssertEqual(mostVisited.count, 1)
        XCTAssertEqual(mostVisited.first?.url, "https://a.com")
    }

    // MARK: - MockFavoriteService: CRUD

    private var favoriteService: MockFavoriteService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        favoriteService = MockFavoriteService()
        historyService = MockHistoryService()
    }

    func testAddFavorite() {
        let url = URL(string: "https://example.com")!
        let favorite = favoriteService.addFavorite(url: url, title: "Example", favicon: nil)

        XCTAssertNotNil(favorite)
        XCTAssertEqual(favorite?.url, "https://example.com")
        XCTAssertEqual(favorite?.title, "Example")
    }

    func testAddFavoriteDuplicateReturnsExisting() {
        let url = URL(string: "https://example.com")!
        let first = favoriteService.addFavorite(url: url, title: "First", favicon: nil)
        let second = favoriteService.addFavorite(url: url, title: "Second", favicon: nil)

        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        XCTAssertEqual(first?.id, second?.id)
        XCTAssertEqual(second?.title, "First")
    }

    func testAddFavoriteUsesHostAsDefaultTitle() {
        let url = URL(string: "https://example.com")!
        let favorite = favoriteService.addFavorite(url: url, title: nil, favicon: nil)

        XCTAssertEqual(favorite?.title, "example.com")
    }

    func testDeleteFavoriteById() {
        let url = URL(string: "https://example.com")!
        let favorite = favoriteService.addFavorite(url: url, title: "Example", favicon: nil)

        XCTAssertNotNil(favorite)
        favoriteService.deleteFavorite(id: favorite!.id)
        XCTAssertNil(favoriteService.findFavorite(id: favorite!.id))
    }

    func testDeleteFavoriteByUrl() {
        let url = URL(string: "https://example.com")!
        favoriteService.addFavorite(url: url, title: "Example", favicon: nil)
        favoriteService.deleteFavorite(url: url)

        XCTAssertNil(favoriteService.findFavorite(url: url))
    }

    func testFindFavoriteByUrl() {
        let url = URL(string: "https://example.com")!
        favoriteService.addFavorite(url: url, title: "Example", favicon: nil)

        let found = favoriteService.findFavorite(url: url)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.url, "https://example.com")
    }

    func testFindFavoriteById() {
        let url = URL(string: "https://example.com")!
        let favorite = favoriteService.addFavorite(url: url, title: "Example", favicon: nil)

        let found = favoriteService.findFavorite(id: favorite!.id)
        XCTAssertNotNil(found)
    }

    func testFindFavoriteNonExistent() {
        XCTAssertNil(favoriteService.findFavorite(url: URL(string: "https://nonexistent.com")!))
        XCTAssertNil(favoriteService.findFavorite(id: "nonexistent-id"))
    }

    func testFavoriteGetTotalCount() {
        XCTAssertEqual(favoriteService.getTotalCount(), 0)

        favoriteService.addFavorite(url: URL(string: "https://a.com")!, title: "A", favicon: nil)
        favoriteService.addFavorite(url: URL(string: "https://b.com")!, title: "B", favicon: nil)

        XCTAssertEqual(favoriteService.getTotalCount(), 2)
    }

    func testTogglePin() {
        let url = URL(string: "https://example.com")!
        let favorite = favoriteService.addFavorite(url: url, title: "Example", favicon: nil)

        XCTAssertFalse(favorite!.isPinned)
        let pinned = favoriteService.togglePin(id: favorite!.id)
        XCTAssertTrue(pinned)
        let unpinned = favoriteService.togglePin(id: favorite!.id)
        XCTAssertFalse(unpinned)
    }

    func testTogglePinNonExistent() {
        let result = favoriteService.togglePin(id: "nonexistent")
        XCTAssertFalse(result)
    }

    func testUpdateCacheMode() {
        let url = URL(string: "https://example.com")!
        let favorite = favoriteService.addFavorite(url: url, title: "Example", favicon: nil)

        XCTAssertFalse(favorite!.enableCacheMode)
        favoriteService.updateCacheMode(id: favorite!.id, enabled: true)

        let updated = favoriteService.findFavorite(id: favorite!.id)
        XCTAssertTrue(updated?.enableCacheMode ?? false)
    }

    func testUpdateSortOrder() {
        let fav1 = favoriteService.addFavorite(url: URL(string: "https://a.com")!, title: "A", favicon: nil)
        let fav2 = favoriteService.addFavorite(url: URL(string: "https://b.com")!, title: "B", favicon: nil)

        favoriteService.updateSortOrder(favorites: [fav2!, fav1!])

        XCTAssertEqual(favoriteService.findFavorite(id: fav2!.id)?.sortOrder, 0)
        XCTAssertEqual(favoriteService.findFavorite(id: fav1!.id)?.sortOrder, 1)
    }

    func testAddMockFavoriteData() {
        favoriteService.addMockData(urls: [
            "https://apple.com",
            "https://google.com"
        ])
        XCTAssertEqual(favoriteService.getTotalCount(), 2)
    }

    func testClearMockFavoriteData() {
        favoriteService.addMockData(urls: ["https://a.com"])
        favoriteService.clearMockData()
        XCTAssertEqual(favoriteService.getTotalCount(), 0)
    }

    func testUpdateFavorite() {
        let url = URL(string: "https://example.com")!
        let favorite = favoriteService.addFavorite(url: url, title: "Original", favicon: nil)

        favorite?.title = "Updated"
        if let fav = favorite {
            favoriteService.updateFavorite(fav)
        }

        let found = favoriteService.findFavorite(url: url)
        XCTAssertEqual(found?.title, "Updated")
    }

    // MARK: - HistoryServiceProtocol Compliance

    func testMockHistoryConformsToProtocol() {
        let service: HistoryServiceProtocol = MockHistoryService()
        service.addOrUpdateHistory(url: URL(string: "https://test.com")!, title: "Test", favicon: nil)

        XCTAssertEqual(service.getAllHistories().count, 1)
    }

    func testMockFavoriteConformsToProtocol() {
        let service: FavoriteServiceProtocol = MockFavoriteService()
        let fav = service.addFavorite(url: URL(string: "https://test.com")!, title: "Test", favicon: nil)

        XCTAssertNotNil(fav)
    }

    // MARK: - ServiceMode

    func testServiceModeEquality() {
        XCTAssertEqual(ServiceLocator.ServiceMode.production, .production)
        XCTAssertEqual(ServiceLocator.ServiceMode.mock, .mock)
        XCTAssertNotEqual(ServiceLocator.ServiceMode.production, .mock)
    }
}
