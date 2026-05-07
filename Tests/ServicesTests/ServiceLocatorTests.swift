//
//  ServiceLocatorTests.swift
//  ServicesTests
//

import XCTest
@testable import WebBridgeKit

final class ServiceLocatorTests: XCTestCase {

    private var sut: ServiceLocator!

    override func setUp() {
        super.setUp()
        sut = ServiceLocator.shared
    }

    override func tearDown() {
        sut.reset()
        sut = nil
        super.tearDown()
    }

    func testSharedSingleton() {
        XCTAssertTrue(ServiceLocator.shared === ServiceLocator.shared)
    }

    func testSetupMockServices() {
        sut.setupMockServices()
        XCTAssertEqual(sut.currentMode, .mock)
    }

    func testSetupMockServicesWithSampleData() {
        sut.setupMockServicesWithSampleData(useInMemoryRealm: false)
        XCTAssertEqual(sut.currentMode, .mock)
        XCTAssertGreaterThanOrEqual(sut.historyService.getTotalCount(), 5)
        XCTAssertGreaterThanOrEqual(sut.favoriteService.getTotalCount(), 3)
    }

    func testSetupProductionServices() {
        sut.setupProductionServices()
        XCTAssertEqual(sut.currentMode, .production)
    }

    func testRegisterCustomServices() {
        let mockHistory = MockHistoryService()
        let mockFavorite = MockFavoriteService()
        sut.registerCustomServices(historyService: mockHistory, favoriteService: mockFavorite)

        XCTAssertTrue(sut.historyService is MockHistoryService)
        XCTAssertTrue(sut.favoriteService is MockFavoriteService)
    }

    func testRegisterPartialCustomServices() {
        sut.setupMockServices()
        let newHistory = MockHistoryService()
        sut.registerCustomServices(historyService: newHistory)

        XCTAssertTrue(sut.historyService is MockHistoryService)
        XCTAssertTrue(sut.favoriteService is MockFavoriteService)
    }

    func testClearServices() {
        sut.setupMockServices()
        sut.clearServices()
    }

    func testResetSetsProductionMode() {
        sut.setupMockServices()
        sut.reset()
        XCTAssertEqual(sut.currentMode, .production)
    }

    func testConvenienceHistoryAccessor() {
        sut.setupMockServices()
        let history = ServiceLocator.history
        XCTAssertNotNil(history)
    }

    func testConvenienceFavoriteAccessor() {
        sut.setupMockServices()
        let favorite = ServiceLocator.favorite
        XCTAssertNotNil(favorite)
    }

    func testHistoryServiceReturnsProtocol() {
        sut.setupMockServices()
        let service = sut.historyService
        XCTAssertTrue(service is HistoryServiceProtocol)
    }

    func testFavoriteServiceReturnsProtocol() {
        sut.setupMockServices()
        let service = sut.favoriteService
        XCTAssertTrue(service is FavoriteServiceProtocol)
    }

    func testModeTransitions() {
        sut.setupMockServices()
        XCTAssertEqual(sut.currentMode, .mock)
        sut.setupProductionServices()
        XCTAssertEqual(sut.currentMode, .production)
        sut.setupMockServices()
        XCTAssertEqual(sut.currentMode, .mock)
    }
}
