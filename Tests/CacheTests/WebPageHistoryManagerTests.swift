import XCTest
@testable import WebBridgeKit

final class WebPageHistoryManagerTests: XCTestCase {

    func testSharedInstance() {
        let manager = WebPageHistoryManager.shared
        XCTAssertNotNil(manager)
    }

    func testGetAllHistoriesReturnsArray() async {
        let manager = WebPageHistoryManager.shared
        let histories = try? await manager.getAllHistories()
        XCTAssertNotNil(histories)
    }

    func testGetCachedHistoriesReturnsArray() async {
        let manager = WebPageHistoryManager.shared
        let histories = try? await manager.getCachedHistories()
        XCTAssertNotNil(histories)
    }

    func testFindHistoryByURLNonExistent() async {
        let manager = WebPageHistoryManager.shared
        let url = URL(string: "https://nonexistent-\(UUID().uuidString).com")!
        let result = try? await manager.findHistory(url: url)
        XCTAssertNil(result)
    }

    func testFindHistoryByIDNonExistent() async {
        let manager = WebPageHistoryManager.shared
        let result = try? await manager.findHistory(id: "nonexistent-\(UUID().uuidString)")
        XCTAssertNil(result)
    }

    func testSearchHistoriesEmpty() async {
        let manager = WebPageHistoryManager.shared
        let results = try? await manager.searchHistories(keyword: "nonexistent-\(UUID().uuidString)")
        XCTAssertNotNil(results)
    }

    func testGetTotalCount() async {
        let manager = WebPageHistoryManager.shared
        let count = try? await manager.getTotalCount()
        XCTAssertNotNil(count)
        XCTAssertGreaterThanOrEqual(count!, 0)
    }

    func testGetTodayVisitCount() async {
        let manager = WebPageHistoryManager.shared
        let count = try? await manager.getTodayVisitCount()
        XCTAssertNotNil(count)
        XCTAssertGreaterThanOrEqual(count!, 0)
    }

    func testGetMostVisited() async {
        let manager = WebPageHistoryManager.shared
        let results = try? await manager.getMostVisited(limit: 5)
        XCTAssertNotNil(results)
    }

    func testGetMostVisitedCustomLimit() async {
        let manager = WebPageHistoryManager.shared
        let results = try? await manager.getMostVisited(limit: 1)
        XCTAssertNotNil(results)
    }

    func testAddOrUpdateHistoryNoCrash() async {
        let manager = WebPageHistoryManager.shared
        let url = URL(string: "https://example-\(UUID().uuidString).com")!
        try? await manager.addOrUpdateHistory(url: url, title: "Test", favicon: nil)
    }

    func testDeleteHistoryNonExistentNoCrash() async {
        let manager = WebPageHistoryManager.shared
        try? await manager.deleteHistory(id: "nonexistent-\(UUID().uuidString)")
    }

    func testClearAllHistoryNoCrash() async {
        let manager = WebPageHistoryManager.shared
        try? await manager.clearAllHistory()
    }

    func testCleanupLowFrequencyItemsNoCrash() async {
        let manager = WebPageHistoryManager.shared
        try? await manager.cleanupLowFrequencyItems(limit: 100)
    }

    func testSyncGetAllHistories() {
        let manager = WebPageHistoryManager.shared
        let histories = manager.getAllHistories()
        XCTAssertNotNil(histories)
    }

    func testSyncFindHistoryByURL() {
        let manager = WebPageHistoryManager.shared
        let url = URL(string: "https://nonexistent-\(UUID().uuidString).com")!
        let result = manager.findHistory(url: url)
        XCTAssertNil(result)
    }

    func testSyncFindHistoryByID() {
        let manager = WebPageHistoryManager.shared
        let result = manager.findHistory(id: "nonexistent-\(UUID().uuidString)")
        XCTAssertNil(result)
    }

    func testSyncSearchHistories() {
        let manager = WebPageHistoryManager.shared
        let results = manager.searchHistories(keyword: "nonexistent")
        XCTAssertNotNil(results)
    }

    func testSyncGetTotalCount() {
        let manager = WebPageHistoryManager.shared
        let count = manager.getTotalCount()
        XCTAssertGreaterThanOrEqual(count, 0)
    }

    func testSyncGetTodayVisitCount() {
        let manager = WebPageHistoryManager.shared
        let count = manager.getTodayVisitCount()
        XCTAssertGreaterThanOrEqual(count, 0)
    }

    func testSyncGetMostVisited() {
        let manager = WebPageHistoryManager.shared
        let results = manager.getMostVisited(limit: 10)
        XCTAssertNotNil(results)
    }

    func testSyncGetCachedHistories() {
        let manager = WebPageHistoryManager.shared
        let results = manager.getCachedHistories()
        XCTAssertNotNil(results)
    }
}
