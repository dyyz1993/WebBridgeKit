//
//  MockHistoryServiceTests.swift
//  ServicesTests
//

import XCTest
@testable import WebBridgeKit

final class MockHistoryServiceTests: XCTestCase {

    private var sut: MockHistoryService!

    override func setUp() {
        super.setUp()
        sut = MockHistoryService()
    }

    override func tearDown() {
        sut.clearMockData()
        sut = nil
        super.tearDown()
    }

    func testInitialStateIsEmpty() {
        XCTAssertEqual(sut.getTotalCount(), 0)
        XCTAssertTrue(sut.getAllHistories().isEmpty)
    }

    func testAddOrUpdateHistoryCreatesEntry() {
        let url = URL(string: "https://example.com")!
        sut.addOrUpdateHistory(url: url, title: "Example", favicon: nil)

        XCTAssertEqual(sut.getTotalCount(), 1)
        let history = sut.findHistory(url: url)
        XCTAssertNotNil(history)
        XCTAssertEqual(history?.title, "Example")
        XCTAssertEqual(history?.url, "https://example.com")
    }

    func testAddOrUpdateHistoryUpdatesExisting() {
        let url = URL(string: "https://example.com")!
        sut.addOrUpdateHistory(url: url, title: "First", favicon: nil)
        sut.addOrUpdateHistory(url: url, title: nil, favicon: nil)

        XCTAssertEqual(sut.getTotalCount(), 1)
        let history = sut.findHistory(url: url)
        XCTAssertEqual(history?.visitCount, 2)
        XCTAssertEqual(history?.title, "First")
    }

    func testAddOrUpdateHistoryUpdatesFavicon() {
        let url = URL(string: "https://example.com")!
        sut.addOrUpdateHistory(url: url, title: "Example", favicon: nil)
        let faviconData = Data("favicon".utf8)
        sut.addOrUpdateHistory(url: url, title: nil, favicon: faviconData)

        let history = sut.findHistory(url: url)
        XCTAssertEqual(history?.favicon, faviconData)
    }

    func testFindHistoryByURL() {
        let url = URL(string: "https://example.com")!
        sut.addOrUpdateHistory(url: url, title: "Test", favicon: nil)

        let found = sut.findHistory(url: url)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.url, "https://example.com")
    }

    func testFindHistoryByURLNotFound() {
        let url = URL(string: "https://nonexistent.com")!
        XCTAssertNil(sut.findHistory(url: url))
    }

    func testFindHistoryByID() {
        let url = URL(string: "https://example.com")!
        sut.addOrUpdateHistory(url: url, title: "Test", favicon: nil)
        let id = sut.findHistory(url: url)?.id

        let found = sut.findHistory(id: id!)
        XCTAssertNotNil(found)
    }

    func testFindHistoryByIDNotFound() {
        XCTAssertNil(sut.findHistory(id: "nonexistent-id"))
    }

    func testDeleteHistoryByID() {
        let url = URL(string: "https://example.com")!
        sut.addOrUpdateHistory(url: url, title: "Test", favicon: nil)
        let id = sut.findHistory(url: url)?.id ?? ""
        sut.deleteHistory(id: id)
        XCTAssertEqual(sut.getTotalCount(), 0)
        XCTAssertNil(sut.findHistory(url: url))
    }

    func testClearAllHistory() {
        sut.addOrUpdateHistory(url: URL(string: "https://a.com")!, title: nil, favicon: nil)
        sut.addOrUpdateHistory(url: URL(string: "https://b.com")!, title: nil, favicon: nil)

        sut.clearAllHistory()
        XCTAssertEqual(sut.getTotalCount(), 0)
    }

    func testSearchHistoriesByURL() {
        sut.addOrUpdateHistory(url: URL(string: "https://github.com/test")!, title: "Repo", favicon: nil)
        sut.addOrUpdateHistory(url: URL(string: "https://example.com")!, title: "Other", favicon: nil)

        let results = sut.searchHistories(keyword: "github")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.url, "https://github.com/test")
    }

    func testSearchHistoriesByTitle() {
        sut.addOrUpdateHistory(url: URL(string: "https://a.com")!, title: "GitHub Repository", favicon: nil)
        sut.addOrUpdateHistory(url: URL(string: "https://b.com")!, title: "Other Site", favicon: nil)

        let results = sut.searchHistories(keyword: "github")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "GitHub Repository")
    }

    func testSearchHistoriesCaseInsensitive() {
        sut.addOrUpdateHistory(url: URL(string: "https://github.com")!, title: "GitHub", favicon: nil)

        let results = sut.searchHistories(keyword: "GITHUB")
        XCTAssertEqual(results.count, 1)
    }

    func testGetTotalCount() {
        sut.addOrUpdateHistory(url: URL(string: "https://a.com")!, title: nil, favicon: nil)
        sut.addOrUpdateHistory(url: URL(string: "https://b.com")!, title: nil, favicon: nil)
        sut.addOrUpdateHistory(url: URL(string: "https://c.com")!, title: nil, favicon: nil)

        XCTAssertEqual(sut.getTotalCount(), 3)
    }

    func testGetTodayVisitCount() {
        sut.addOrUpdateHistory(url: URL(string: "https://a.com")!, title: nil, favicon: nil)
        sut.addOrUpdateHistory(url: URL(string: "https://b.com")!, title: nil, favicon: nil)

        XCTAssertGreaterThanOrEqual(sut.getTodayVisitCount(), 2)
    }

    func testGetMostVisited() {
        let urlA = URL(string: "https://a.com")!
        let urlB = URL(string: "https://b.com")!
        let urlC = URL(string: "https://c.com")!

        sut.addOrUpdateHistory(url: urlA, title: nil, favicon: nil)
        sut.addOrUpdateHistory(url: urlA, title: nil, favicon: nil)
        sut.addOrUpdateHistory(url: urlA, title: nil, favicon: nil)
        sut.addOrUpdateHistory(url: urlB, title: nil, favicon: nil)
        sut.addOrUpdateHistory(url: urlB, title: nil, favicon: nil)
        sut.addOrUpdateHistory(url: urlC, title: nil, favicon: nil)

        let mostVisited = sut.getMostVisited(limit: 2)
        XCTAssertEqual(mostVisited.count, 2)
        XCTAssertEqual(mostVisited.first?.url, "https://a.com")
        XCTAssertEqual(mostVisited.last?.url, "https://b.com")
    }

    func testGetCachedHistoriesEmpty() {
        let results = sut.getCachedHistories()
        XCTAssertTrue(results.isEmpty)
    }

    func testGetAllHistoriesSortedByLastVisitDate() {
        sut.addOrUpdateHistory(url: URL(string: "https://a.com")!, title: "First", favicon: nil)
        sut.addOrUpdateHistory(url: URL(string: "https://b.com")!, title: "Second", favicon: nil)

        let histories = sut.getAllHistories()
        XCTAssertEqual(histories.count, 2)
        XCTAssertGreaterThanOrEqual(histories[0].lastVisitDate, histories[1].lastVisitDate)
    }

    func testAddMockData() {
        sut.addMockData(urls: [
            "https://www.apple.com",
            "https://www.github.com",
            "https://www.google.com"
        ])

        XCTAssertEqual(sut.getTotalCount(), 3)
    }

    func testAddMockDataWithTitles() {
        sut.addMockData(
            urls: ["https://example.com"],
            titles: ["Example Title"]
        )

        let history = sut.findHistory(url: URL(string: "https://example.com")!)
        XCTAssertEqual(history?.title, "Example Title")
    }

    func testAddMockDataWithInvalidURL() {
        sut.addMockData(urls: ["not-a-valid-url-!!"])
        XCTAssertEqual(sut.getTotalCount(), 0)
    }

    func testClearMockData() {
        sut.addMockData(urls: ["https://a.com", "https://b.com"])
        sut.clearMockData()
        XCTAssertEqual(sut.getTotalCount(), 0)
    }

    func testDeleteNonExistentDoesNotCrash() {
        sut.deleteHistory(id: "nonexistent")
        XCTAssertEqual(sut.getTotalCount(), 0)
    }
}
