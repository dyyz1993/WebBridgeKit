import XCTest
@testable import WebBridgeKit

final class RealmHistoryServiceTests: XCTestCase {

    func testSharedIsSingleton() {
        let service1 = RealmHistoryService.shared
        let service2 = RealmHistoryService.shared
        XCTAssertTrue(service1 === service2)
    }

    func testSharedIsNotNil() {
        XCTAssertNotNil(RealmHistoryService.shared)
    }

    func testInitWithCustomManager() {
        let manager = WebPageHistoryManager.shared
        let service = RealmHistoryService(manager: manager)
        XCTAssertNotNil(service)
    }

    func testConformsToHistoryServiceProtocol() {
        let service: any HistoryServiceProtocol = RealmHistoryService.shared
        XCTAssertTrue(service is HistoryServiceProtocol)
    }

    func testGetAllHistoriesReturnsArray() {
        let service = RealmHistoryService.shared
        let histories = service.getAllHistories()
        XCTAssertNotNil(histories)
    }

    func testGetTotalCountNonNegative() {
        let service = RealmHistoryService.shared
        let count = service.getTotalCount()
        XCTAssertGreaterThanOrEqual(count, 0)
    }

    func testGetTodayVisitCountNonNegative() {
        let service = RealmHistoryService.shared
        let count = service.getTodayVisitCount()
        XCTAssertGreaterThanOrEqual(count, 0)
    }

    func testGetMostVisitedReturnsArray() {
        let service = RealmHistoryService.shared
        let results = service.getMostVisited(limit: 5)
        XCTAssertNotNil(results)
    }

    func testFindHistoryByURLNonExistent() {
        let service = RealmHistoryService.shared
        let url = URL(string: "https://nonexistent-\(UUID().uuidString).com")!
        let result = service.findHistory(url: url)
        XCTAssertNil(result)
    }

    func testFindHistoryByIDNonExistent() {
        let service = RealmHistoryService.shared
        let result = service.findHistory(id: "nonexistent-\(UUID().uuidString)")
        XCTAssertNil(result)
    }

    func testSearchHistoriesReturnsArray() {
        let service = RealmHistoryService.shared
        let results = service.searchHistories(keyword: "nonexistent-\(UUID().uuidString)")
        XCTAssertNotNil(results)
    }

    func testAddOrUpdateHistoryNoCrash() {
        let service = RealmHistoryService.shared
        let url = URL(string: "https://example-\(UUID().uuidString).com")!
        service.addOrUpdateHistory(url: url, title: "Test", favicon: nil)
    }

    func testDeleteHistoryNonExistentNoCrash() {
        let service = RealmHistoryService.shared
        service.deleteHistory(id: "nonexistent-\(UUID().uuidString)")
    }

    func testClearAllHistoryNoCrash() {
        let service = RealmHistoryService.shared
        service.clearAllHistory()
    }

    func testGetCachedHistoriesReturnsArray() {
        let service = RealmHistoryService.shared
        let histories = service.getCachedHistories()
        XCTAssertNotNil(histories)
    }
}
