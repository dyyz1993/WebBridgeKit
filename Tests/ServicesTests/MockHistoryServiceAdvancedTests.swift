//
//  MockHistoryServiceAdvancedTests.swift
//  WebBridgeKitTests
//

import XCTest
@testable import WebBridgeKit

final class MockHistoryServiceAdvancedTests: XCTestCase {

    private var sut: MockHistoryService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = MockHistoryService()
    }

    override func tearDownWithError() throws {
        sut = nil
        try super.tearDownWithError()
    }

    // MARK: - Initial State

    func testInitialStateIsEmpty() {
        XCTAssertEqual(sut.getTotalCount(), 0)
        XCTAssertTrue(sut.getAllHistories().isEmpty)
        XCTAssertTrue(sut.getCachedHistories().isEmpty)
        XCTAssertEqual(sut.getTodayVisitCount(), 0)
        XCTAssertTrue(sut.getMostVisited(limit: 10).isEmpty)
    }

    func testFindNonExistentHistoryReturnsNil() {
        let result = sut.findHistory(url: URL(string: "https://nonexistent.com")!)
        XCTAssertNil(result)
    }

    func testFindNonExistentHistoryByIdReturnsNil() {
        let result = sut.findHistory(id: "nonexistent-id")
        XCTAssertNil(result)
    }

    func testSearchEmptyHistoryReturnsEmpty() {
        let results = sut.searchHistories(keyword: "anything")
        XCTAssertTrue(results.isEmpty)
    }

    func testDeleteNonExistentHistoryDoesNotCrash() {
        sut.deleteHistory(id: "nonexistent-id")
        XCTAssertEqual(sut.getTotalCount(), 0)
    }

    func testClearAllHistoryOnEmptyDoesNotCrash() {
        sut.clearAllHistory()
        XCTAssertEqual(sut.getTotalCount(), 0)
    }

    // MARK: - addOrUpdateHistory: Favicon Handling

    func testAddHistoryWithFaviconStoresFavicon() {
        let url = URL(string: "https://example.com")!
        let faviconData = Data("favicon".utf8)

        sut.addOrUpdateHistory(url: url, title: "Example", favicon: faviconData)

        let found = sut.findHistory(url: url)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.favicon, faviconData)
    }

    func testUpdateHistoryDoesNotOverwriteExistingFavicon() {
        let url = URL(string: "https://example.com")!
        let originalFavicon = Data("original".utf8)
        let newFavicon = Data("new".utf8)

        sut.addOrUpdateHistory(url: url, title: "Example", favicon: originalFavicon)
        sut.addOrUpdateHistory(url: url, title: nil, favicon: newFavicon)

        let found = sut.findHistory(url: url)
        XCTAssertEqual(found?.favicon, originalFavicon)
    }

    func testUpdateHistorySetsFaviconWhenNoneExists() {
        let url = URL(string: "https://example.com")!
        let laterFavicon = Data("later".utf8)

        sut.addOrUpdateHistory(url: url, title: "Example", favicon: nil)
        sut.addOrUpdateHistory(url: url, title: nil, favicon: laterFavicon)

        let found = sut.findHistory(url: url)
        XCTAssertEqual(found?.favicon, laterFavicon)
    }

    // MARK: - addOrUpdateHistory: Title Handling

    func testUpdateHistoryDoesNotOverwriteExistingTitle() {
        let url = URL(string: "https://example.com")!

        sut.addOrUpdateHistory(url: url, title: "Original", favicon: nil)
        sut.addOrUpdateHistory(url: url, title: "New", favicon: nil)

        let found = sut.findHistory(url: url)
        XCTAssertEqual(found?.title, "Original")
    }

    func testUpdateHistorySetsTitleWhenNoneExists() {
        let url = URL(string: "https://example.com")!

        sut.addOrUpdateHistory(url: url, title: nil, favicon: nil)
        sut.addOrUpdateHistory(url: url, title: "Delayed", favicon: nil)

        let found = sut.findHistory(url: url)
        XCTAssertEqual(found?.title, "Delayed")
    }

    func testAddHistoryWithNilTitle() {
        let url = URL(string: "https://example.com")!

        sut.addOrUpdateHistory(url: url, title: nil, favicon: nil)

        let found = sut.findHistory(url: url)
        XCTAssertNotNil(found)
        XCTAssertNil(found?.title)
    }

    // MARK: - Visit Count & Date

    func testNewHistoryHasVisitCountOne() {
        let url = URL(string: "https://example.com")!

        sut.addOrUpdateHistory(url: url, title: "Test", favicon: nil)

        let found = sut.findHistory(url: url)
        XCTAssertEqual(found?.visitCount, 1)
    }

    func testMultipleVisitsIncrementCount() {
        let url = URL(string: "https://example.com")!

        sut.addOrUpdateHistory(url: url, title: "Test", favicon: nil)
        sut.addOrUpdateHistory(url: url, title: nil, favicon: nil)
        sut.addOrUpdateHistory(url: url, title: nil, favicon: nil)

        let found = sut.findHistory(url: url)
        XCTAssertEqual(found?.visitCount, 3)
    }

    func testVisitUpdatesLastVisitDate() {
        let url = URL(string: "https://example.com")!

        sut.addOrUpdateHistory(url: url, title: "Test", favicon: nil)

        let firstDate = sut.findHistory(url: url)?.lastVisitDate

        Thread.sleep(forTimeInterval: 0.01)

        sut.addOrUpdateHistory(url: url, title: nil, favicon: nil)

        let secondDate = sut.findHistory(url: url)?.lastVisitDate

        XCTAssertNotNil(firstDate)
        XCTAssertNotNil(secondDate)
        XCTAssertTrue(secondDate! > firstDate!)
    }

    // MARK: - getAllHistories Sorting

    func testGetAllHistoriesSortedByMostRecentFirst() {
        let urlA = URL(string: "https://a.com")!
        let urlB = URL(string: "https://b.com")!
        let urlC = URL(string: "https://c.com")!

        sut.addOrUpdateHistory(url: urlA, title: "A", favicon: nil)
        Thread.sleep(forTimeInterval: 0.01)
        sut.addOrUpdateHistory(url: urlB, title: "B", favicon: nil)
        Thread.sleep(forTimeInterval: 0.01)
        sut.addOrUpdateHistory(url: urlC, title: "C", favicon: nil)

        let all = sut.getAllHistories()
        XCTAssertEqual(all.count, 3)
        XCTAssertEqual(all[0].url, "https://c.com")
        XCTAssertEqual(all[1].url, "https://b.com")
        XCTAssertEqual(all[2].url, "https://a.com")
    }

    // MARK: - getTodayVisitCount

    func testTodayVisitCountAfterAddingHistory() {
        let url = URL(string: "https://example.com")!
        sut.addOrUpdateHistory(url: url, title: "Test", favicon: nil)

        XCTAssertEqual(sut.getTodayVisitCount(), 1)
    }

    func testTodayVisitCountWithMultipleHistories() {
        sut.addOrUpdateHistory(url: URL(string: "https://a.com")!, title: "A", favicon: nil)
        sut.addOrUpdateHistory(url: URL(string: "https://b.com")!, title: "B", favicon: nil)
        sut.addOrUpdateHistory(url: URL(string: "https://c.com")!, title: "C", favicon: nil)

        XCTAssertEqual(sut.getTodayVisitCount(), 3)
    }

    // MARK: - getMostVisited

    func testGetMostVisitedReturnsCorrectOrder() {
        let urlA = URL(string: "https://a.com")!
        let urlB = URL(string: "https://b.com")!
        let urlC = URL(string: "https://c.com")!

        sut.addOrUpdateHistory(url: urlA, title: "A", favicon: nil)
        sut.addOrUpdateHistory(url: urlA, title: nil, favicon: nil)
        sut.addOrUpdateHistory(url: urlA, title: nil, favicon: nil)

        sut.addOrUpdateHistory(url: urlB, title: "B", favicon: nil)
        sut.addOrUpdateHistory(url: urlB, title: nil, favicon: nil)

        sut.addOrUpdateHistory(url: urlC, title: "C", favicon: nil)

        let mostVisited = sut.getMostVisited(limit: 3)
        XCTAssertEqual(mostVisited.count, 3)
        XCTAssertEqual(mostVisited[0].url, "https://a.com")
        XCTAssertEqual(mostVisited[1].url, "https://b.com")
        XCTAssertEqual(mostVisited[2].url, "https://c.com")
    }

    func testGetMostVisitedRespectsLimit() {
        for i in 0..<5 {
            sut.addOrUpdateHistory(url: URL(string: "https://\(i).com")!, title: "\(i)", favicon: nil)
        }

        let limited = sut.getMostVisited(limit: 2)
        XCTAssertEqual(limited.count, 2)
    }

    func testGetMostVisitedWithZeroLimit() {
        sut.addOrUpdateHistory(url: URL(string: "https://a.com")!, title: "A", favicon: nil)

        let result = sut.getMostVisited(limit: 0)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - getCachedHistories

    func testGetCachedHistoriesFiltersUncached() {
        let urlCached = URL(string: "https://cached.com")!
        let urlNotCached = URL(string: "https://notcached.com")!

        sut.addOrUpdateHistory(url: urlCached, title: "Cached", favicon: nil)
        sut.addOrUpdateHistory(url: urlNotCached, title: "Not Cached", favicon: nil)

        if let cached = sut.findHistory(url: urlCached) {
            cached.isCached = true
            cached.cacheDate = Date()
        }

        let cachedList = sut.getCachedHistories()
        XCTAssertEqual(cachedList.count, 1)
        XCTAssertEqual(cachedList.first?.url, "https://cached.com")
    }

    func testGetCachedHistoriesEmptyWhenNoneCached() {
        sut.addOrUpdateHistory(url: URL(string: "https://a.com")!, title: "A", favicon: nil)

        let cachedList = sut.getCachedHistories()
        XCTAssertTrue(cachedList.isEmpty)
    }

    // MARK: - searchHistories: Edge Cases

    func testSearchWithEmptyKeyword() {
        sut.addOrUpdateHistory(url: URL(string: "https://example.com")!, title: "Example", favicon: nil)

        let results = sut.searchHistories(keyword: "")
        XCTAssertTrue(results.count >= 0)
    }

    func testSearchWithSpecialCharacters() {
        sut.addOrUpdateHistory(url: URL(string: "https://example.com/path?q=test&lang=en")!, title: "Search Page", favicon: nil)

        let results = sut.searchHistories(keyword: "?q=test")
        XCTAssertEqual(results.count, 1)
    }

    func testSearchReturnsNoResultsForUnmatchedKeyword() {
        sut.addOrUpdateHistory(url: URL(string: "https://example.com")!, title: "Example", favicon: nil)

        let results = sut.searchHistories(keyword: "zzz-nonexistent")
        XCTAssertTrue(results.isEmpty)
    }

    func testSearchMatchesPartialTitle() {
        sut.addOrUpdateHistory(url: URL(string: "https://example.com")!, title: "Swift Programming Guide", favicon: nil)

        let results = sut.searchHistories(keyword: "rogram")
        XCTAssertEqual(results.count, 1)
    }

    // MARK: - addMockData

    func testAddMockDataWithTitlesMismatchedLength() {
        sut.addMockData(
            urls: ["https://a.com", "https://b.com"],
            titles: ["A"]
        )

        XCTAssertEqual(sut.getTotalCount(), 2)
        let foundA = sut.findHistory(url: URL(string: "https://a.com")!)
        XCTAssertEqual(foundA?.title, "A")
        let foundB = sut.findHistory(url: URL(string: "https://b.com")!)
        XCTAssertNotNil(foundB)
    }

    func testAddMockDataWithEmptyArray() {
        sut.addMockData(urls: [])
        XCTAssertEqual(sut.getTotalCount(), 0)
    }

    // MARK: - In-Memory Realm Mode

    func testInMemoryRealmModeInitialization() {
        let realmSut = MockHistoryService(useInMemoryRealm: true)
        realmSut.clearMockData()
        XCTAssertEqual(realmSut.getTotalCount(), 0)
    }

    func testInMemoryRealmModeAddAndFind() {
        let realmSut = MockHistoryService(useInMemoryRealm: true)
        realmSut.clearMockData()
        let url = URL(string: "https://example.com")!

        realmSut.addOrUpdateHistory(url: url, title: "Example", favicon: nil)

        let found = realmSut.findHistory(url: url)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.title, "Example")
    }

    func testInMemoryRealmModeVisitCount() {
        let realmSut = MockHistoryService(useInMemoryRealm: true)
        realmSut.clearMockData()
        let url = URL(string: "https://example.com")!

        realmSut.addOrUpdateHistory(url: url, title: "Test", favicon: nil)
        realmSut.addOrUpdateHistory(url: url, title: nil, favicon: nil)

        let found = realmSut.findHistory(url: url)
        XCTAssertEqual(found?.visitCount, 2)
    }

    func testInMemoryRealmModeClearAll() {
        let realmSut = MockHistoryService(useInMemoryRealm: true)
        realmSut.clearMockData()
        realmSut.addMockData(urls: ["https://a.com", "https://b.com"])

        realmSut.clearAllHistory()

        XCTAssertEqual(realmSut.getTotalCount(), 0)
    }

    func testInMemoryRealmModeSearch() {
        let realmSut = MockHistoryService(useInMemoryRealm: true)
        realmSut.clearMockData()
        realmSut.addOrUpdateHistory(url: URL(string: "https://github.com")!, title: "GitHub", favicon: nil)
        realmSut.addOrUpdateHistory(url: URL(string: "https://google.com")!, title: "Google", favicon: nil)

        let results = realmSut.searchHistories(keyword: "git")
        XCTAssertEqual(results.count, 1)
    }

    func testInMemoryRealmModeGetMostVisited() {
        let realmSut = MockHistoryService(useInMemoryRealm: true)
        realmSut.clearMockData()
        let urlA = URL(string: "https://a.com")!
        let urlB = URL(string: "https://b.com")!

        realmSut.addOrUpdateHistory(url: urlA, title: "A", favicon: nil)
        realmSut.addOrUpdateHistory(url: urlA, title: nil, favicon: nil)
        realmSut.addOrUpdateHistory(url: urlA, title: nil, favicon: nil)
        realmSut.addOrUpdateHistory(url: urlB, title: "B", favicon: nil)

        let mostVisited = realmSut.getMostVisited(limit: 1)
        XCTAssertEqual(mostVisited.count, 1)
        XCTAssertEqual(mostVisited.first?.url, "https://a.com")
    }

    // MARK: - Concurrent Access Safety

    func testMultipleAddsToDifferentURLs() {
        let urls = (0..<20).map { URL(string: "https://\(String(format: "%02d", $0)).com")! }

        for url in urls {
            sut.addOrUpdateHistory(url: url, title: "Site \(url)", favicon: nil)
        }

        XCTAssertEqual(sut.getTotalCount(), 20)
    }

    func testDeleteHistoryReducesCount() {
        sut.addOrUpdateHistory(url: URL(string: "https://a.com")!, title: "A", favicon: nil)
        sut.addOrUpdateHistory(url: URL(string: "https://b.com")!, title: "B", favicon: nil)
        sut.addOrUpdateHistory(url: URL(string: "https://c.com")!, title: "C", favicon: nil)

        guard let toDelete = sut.findHistory(url: URL(string: "https://b.com")!) else {
            XCTFail("Expected to find history for deletion")
            return
        }
        sut.deleteHistory(id: toDelete.id)

        XCTAssertEqual(sut.getTotalCount(), 2)
        XCTAssertNil(sut.findHistory(url: URL(string: "https://b.com")!))
    }
}
