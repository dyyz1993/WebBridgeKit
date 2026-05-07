//
//  RealmFavoriteServiceTests.swift
//  ServicesTests
//

import XCTest
@testable import WebBridgeKit

final class RealmFavoriteServiceTests: XCTestCase {

    func testSharedSingleton() {
        XCTAssertNotNil(RealmFavoriteService.shared)
        XCTAssertTrue(RealmFavoriteService.shared === RealmFavoriteService.shared)
    }

    func testConformsToFavoriteServiceProtocol() {
        XCTAssertTrue(RealmFavoriteService.shared is FavoriteServiceProtocol)
    }

    func testInitWithCustomManager() {
        let service = RealmFavoriteService()
        XCTAssertNotNil(service)
        XCTAssertTrue(service is FavoriteServiceProtocol)
    }
}
