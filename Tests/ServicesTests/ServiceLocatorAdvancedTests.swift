//
//  ServiceLocatorAdvancedTests.swift
//  WebBridgeKitTests
//

import XCTest
@testable import WebBridgeKit

final class ServiceLocatorAdvancedTests: XCTestCase {

    private let locator = ServiceLocator.shared

    override func setUpWithError() throws {
        try super.setUpWithError()
        locator.setupMockServices()
    }

    override func tearDownWithError() throws {
        locator.reset()
        try super.tearDownWithError()
    }

    // MARK: - ServiceMode

    func testServiceModeProductionEquality() {
        XCTAssertEqual(ServiceLocator.ServiceMode.production, .production)
    }

    func testServiceModeMockEquality() {
        XCTAssertEqual(ServiceLocator.ServiceMode.mock, .mock)
    }

    func testServiceModeProductionNotEqualMock() {
        XCTAssertNotEqual(ServiceLocator.ServiceMode.production, .mock)
    }

    // MARK: - setupProductionServices

    func testSetupProductionServicesSetsMode() {
        locator.setupProductionServices()

        XCTAssertEqual(locator.currentMode, .production)
        XCTAssertTrue(locator.historyService is RealmHistoryService)
        XCTAssertTrue(locator.favoriteService is RealmFavoriteService)
    }

    // MARK: - setupMockServices

    func testSetupMockServicesSetsMode() {
        locator.setupMockServices()

        XCTAssertEqual(locator.currentMode, .mock)
        XCTAssertTrue(locator.historyService is MockHistoryService)
        XCTAssertTrue(locator.favoriteService is MockFavoriteService)
    }

    func testSetupMockServicesWithInMemoryRealm() {
        locator.setupMockServices(useInMemoryRealm: true)

        XCTAssertEqual(locator.currentMode, .mock)
        XCTAssertTrue(locator.historyService is MockHistoryService)
        XCTAssertTrue(locator.favoriteService is MockFavoriteService)
    }

    func testSetupMockServicesWithInMemoryRealmFalse() {
        locator.setupMockServices(useInMemoryRealm: false)

        XCTAssertEqual(locator.currentMode, .mock)
    }

    // MARK: - setupMockServicesWithSampleData

    func testSetupMockServicesWithSampleDataPopulatesHistory() {
        locator.setupMockServicesWithSampleData()

        XCTAssertEqual(locator.currentMode, .mock)
        let count = locator.historyService.getTotalCount()
        XCTAssertEqual(count, 5)

        XCTAssertNotNil(locator.historyService.findHistory(url: URL(string: "https://www.apple.com")!))
        XCTAssertNotNil(locator.historyService.findHistory(url: URL(string: "https://www.github.com")!))
    }

    func testSetupMockServicesWithSampleDataPopulatesFavorites() {
        locator.setupMockServicesWithSampleData()

        XCTAssertEqual(locator.currentMode, .mock)
        let count = locator.favoriteService.getTotalCount()
        XCTAssertEqual(count, 3)

        XCTAssertNotNil(locator.favoriteService.findFavorite(url: URL(string: "https://www.apple.com")!))
        XCTAssertNotNil(locator.favoriteService.findFavorite(url: URL(string: "https://www.google.com")!))
    }

    func testSetupMockServicesWithSampleDataInMemoryRealm() {
        locator.setupMockServicesWithSampleData(useInMemoryRealm: true)

        XCTAssertEqual(locator.currentMode, .mock)
        XCTAssertGreaterThanOrEqual(locator.historyService.getTotalCount(), 1)
        XCTAssertGreaterThanOrEqual(locator.favoriteService.getTotalCount(), 1)
    }

    // MARK: - registerCustomServices

    func testRegisterOnlyHistoryService() {
        let customHistory = MockHistoryService()

        locator.registerCustomServices(historyService: customHistory, favoriteService: nil)

        XCTAssertTrue(locator.historyService is MockHistoryService)
    }

    func testRegisterOnlyFavoriteService() {
        let customFavorite = MockFavoriteService()

        locator.registerCustomServices(historyService: nil, favoriteService: customFavorite)

        XCTAssertTrue(locator.favoriteService is MockFavoriteService)
    }

    func testRegisterNilServicesDoesNotChangeExisting() {
        locator.setupMockServices()
        let previousHistoryType = String(describing: type(of: locator.historyService))
        let previousFavoriteType = String(describing: type(of: locator.favoriteService))

        locator.registerCustomServices(historyService: nil, favoriteService: nil)

        XCTAssertEqual(String(describing: type(of: locator.historyService)), previousHistoryType)
        XCTAssertEqual(String(describing: type(of: locator.favoriteService)), previousFavoriteType)
    }

    // MARK: - Convenience Access

    func testStaticHistoryReturnsService() {
        locator.setupMockServices()

        let history = ServiceLocator.history
        XCTAssertNotNil(history)
    }

    func testStaticFavoriteReturnsService() {
        locator.setupMockServices()

        let favorite = ServiceLocator.favorite
        XCTAssertNotNil(favorite)
    }

    // MARK: - reset

    func testResetRestoresProductionMode() {
        locator.setupMockServices()
        XCTAssertEqual(locator.currentMode, .mock)

        locator.reset()

        XCTAssertEqual(locator.currentMode, .production)
        XCTAssertTrue(locator.historyService is RealmHistoryService)
        XCTAssertTrue(locator.favoriteService is RealmFavoriteService)
    }

    // MARK: - clearServices

    func testClearServicesNilifiesAllServices() {
        locator.setupMockServices()
        locator.clearServices()
        XCTAssertEqual(locator.currentMode, .mock)
    }

    func testClearServicesThenSetupMockRestoresServices() {
        locator.clearServices()
        locator.setupMockServices()

        XCTAssertEqual(locator.currentMode, .mock)
        XCTAssertTrue(locator.historyService is MockHistoryService)
        XCTAssertTrue(locator.favoriteService is MockFavoriteService)
    }

    // MARK: - Singleton

    func testSharedInstanceIsAlwaysSame() {
        let instance1 = ServiceLocator.shared
        let instance2 = ServiceLocator.shared
        XCTAssertTrue(instance1 === instance2)
    }
}
