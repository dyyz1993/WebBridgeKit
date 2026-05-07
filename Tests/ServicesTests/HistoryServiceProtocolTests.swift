//
//  HistoryServiceProtocolTests.swift
//  ServicesTests
//

import XCTest
@testable import WebBridgeKit

final class HistoryServiceProtocolTests: XCTestCase {

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

    func testConformsToHistoryServiceProtocol() {
        XCTAssertTrue(sut is HistoryServiceProtocol)
    }

    func testAddOrUpdateHistory() {
        let url = URL(string: "https://example.com")!
        sut.addOrUpdateHistory(url: url, title: "Example", favicon: nil)

        XCTAssertEqual(sut.getTotalCount(), 1)
    }

    func testAddOrUpdateHistoryWithAllFields() {
        let url = URL(string: "https://example.com")!
        let favicon = Data("icon".utf8)
        sut.addOrUpdateHistory(url: url, title: "Example", favicon: favicon)

        let history = sut.findHistory(url: url)
        XCTAssertNotNil(history)
        XCTAssertEqual(history?.title, "Example")
        XCTAssertEqual(history?.favicon, favicon)
    }

    func testDeleteHistory() {
        let url = URL(string: "https://example.com")!
        sut.addOrUpdateHistory(url: url, title: "Test", favicon: nil)
        let id = sut.findHistory(url: url)?.id ?? ""
        sut.deleteHistory(id: id)
        XCTAssertEqual(sut.getTotalCount(), 0)
    }

    func testClearAllHistory() {
        sut.addOrUpdateHistory(url: URL(string: "https://a.com")!, title: nil, favicon: nil)
        sut.addOrUpdateHistory(url: URL(string: "https://b.com")!, title: nil, favicon: nil)

        sut.clearAllHistory()
        XCTAssertTrue(sut.getAllHistories().isEmpty)
    }

    func testGetAllHistories() {
        sut.addOrUpdateHistory(url: URL(string: "https://a.com")!, title: "A", favicon: nil)
        sut.addOrUpdateHistory(url: URL(string: "https://b.com")!, title: "B", favicon: nil)

        let histories = sut.getAllHistories()
        XCTAssertEqual(histories.count, 2)
    }

    func testGetCachedHistories() {
        sut.addOrUpdateHistory(url: URL(string: "https://a.com")!, title: nil, favicon: nil)
        let cached = sut.getCachedHistories()
        XCTAssertTrue(cached.isEmpty)
    }

    func testFindHistoryByURL() {
        let url = URL(string: "https://example.com")!
        sut.addOrUpdateHistory(url: url, title: "Test", favicon: nil)

        let found = sut.findHistory(url: url)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.url, "https://example.com")
    }

    func testFindHistoryByID() {
        let url = URL(string: "https://example.com")!
        sut.addOrUpdateHistory(url: url, title: "Test", favicon: nil)
        let id = sut.findHistory(url: url)?.id

        let found = sut.findHistory(id: id!)
        XCTAssertNotNil(found)
    }

    func testSearchHistories() {
        sut.addOrUpdateHistory(url: URL(string: "https://github.com/repo")!, title: "My Repo", favicon: nil)
        sut.addOrUpdateHistory(url: URL(string: "https://example.com")!, title: "Other", favicon: nil)

        let results = sut.searchHistories(keyword: "repo")
        XCTAssertEqual(results.count, 1)
    }

    func testGetTotalCount() {
        XCTAssertEqual(sut.getTotalCount(), 0)
        sut.addOrUpdateHistory(url: URL(string: "https://a.com")!, title: nil, favicon: nil)
        XCTAssertEqual(sut.getTotalCount(), 1)
    }

    func testGetTodayVisitCount() {
        sut.addOrUpdateHistory(url: URL(string: "https://a.com")!, title: nil, favicon: nil)
        XCTAssertGreaterThanOrEqual(sut.getTodayVisitCount(), 1)
    }

    func testGetMostVisited() {
        let urlA = URL(string: "https://a.com")!
        sut.addOrUpdateHistory(url: urlA, title: nil, favicon: nil)
        sut.addOrUpdateHistory(url: urlA, title: nil, favicon: nil)
        sut.addOrUpdateHistory(url: URL(string: "https://b.com")!, title: nil, favicon: nil)

        let mostVisited = sut.getMostVisited(limit: 1)
        XCTAssertEqual(mostVisited.count, 1)
        XCTAssertEqual(mostVisited.first?.url, "https://a.com")
    }

    func testGetMostVisitedWithLimit() {
        for i in 0..<5 {
            let url = URL(string: "https://example\(i).com")!
            sut.addOrUpdateHistory(url: url, title: nil, favicon: nil)
        }

        let limited = sut.getMostVisited(limit: 3)
        XCTAssertEqual(limited.count, 3)
    }

    func testVisitCountIncrementOnRevisit() {
        let url = URL(string: "https://example.com")!
        sut.addOrUpdateHistory(url: url, title: nil, favicon: nil)
        sut.addOrUpdateHistory(url: url, title: nil, favicon: nil)
        sut.addOrUpdateHistory(url: url, title: nil, favicon: nil)

        let history = sut.findHistory(url: url)
        XCTAssertEqual(history?.visitCount, 3)
    }

    func testGetHistoriesArray() {
        sut.addOrUpdateHistory(url: URL(string: "https://a.com")!, title: "A", favicon: nil)
        let array = sut.getAllHistoriesArray()
        XCTAssertEqual(array.count, 1)
    }
}
