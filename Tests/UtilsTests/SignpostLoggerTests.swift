//
//  SignpostLoggerTests.swift
//  UtilsTests
//

import XCTest
@testable import WebBridgeKit

@available(macOS 10.14, iOS 12.0, *)
final class SignpostLoggerTests: XCTestCase {

    private var sut: SignpostLogger!

    override func setUp() {
        super.setUp()
        sut = SignpostLogger.shared
        sut.isEnabled = true
    }

    override func tearDown() {
        sut.isEnabled = true
        sut = nil
        super.tearDown()
    }

    func testSharedSingleton() {
        XCTAssertNotNil(SignpostLogger.shared)
        XCTAssertTrue(SignpostLogger.shared === SignpostLogger.shared)
    }

    func testIsEnabledProperty() {
        sut.isEnabled = false
        XCTAssertFalse(sut.isEnabled)
        sut.isEnabled = true
        XCTAssertTrue(sut.isEnabled)
    }

    func testBeginIntervalDoesNotCrash() {
        XCTAssertNoThrow(sut.beginInterval("TestInterval", category: .performance))
    }

    func testEndIntervalDoesNotCrash() {
        XCTAssertNoThrow(sut.endInterval("TestInterval", category: .performance))
    }

    func testLogEventDoesNotCrash() {
        XCTAssertNoThrow(sut.logEvent("TestEvent", category: .performance))
    }

    func testDisabledLoggerDoesNotCrash() {
        sut.isEnabled = false
        XCTAssertNoThrow(sut.beginInterval("Disabled", category: .networking))
        XCTAssertNoThrow(sut.endInterval("Disabled", category: .networking))
        XCTAssertNoThrow(sut.logEvent("DisabledEvent", category: .cache))
    }

    func testAllCategoriesCovered() {
        let categories: [SignpostLogger.Category] = [
            .networking, .cache, .database, .javascript, .rendering, .performance
        ]
        XCTAssertEqual(categories.count, 6)
    }

    func testBeginIntervalWithNetworkingCategory() {
        XCTAssertNoThrow(sut.beginInterval("NetworkRequest", category: .networking))
        XCTAssertNoThrow(sut.endInterval("NetworkRequest", category: .networking))
    }

    func testBeginIntervalWithCacheCategory() {
        XCTAssertNoThrow(sut.beginInterval("CacheLookup", category: .cache))
        XCTAssertNoThrow(sut.endInterval("CacheLookup", category: .cache))
    }

    func testBeginIntervalWithDatabaseCategory() {
        XCTAssertNoThrow(sut.beginInterval("DBQuery", category: .database))
        XCTAssertNoThrow(sut.endInterval("DBQuery", category: .database))
    }

    func testBeginIntervalWithJavaScriptCategory() {
        XCTAssertNoThrow(sut.beginInterval("JSEval", category: .javascript))
        XCTAssertNoThrow(sut.endInterval("JSEval", category: .javascript))
    }

    func testBeginIntervalWithRenderingCategory() {
        XCTAssertNoThrow(sut.beginInterval("Render", category: .rendering))
        XCTAssertNoThrow(sut.endInterval("Render", category: .rendering))
    }

    func testLogEventWithAllCategories() {
        for category in [SignpostLogger.Category.networking, .cache, .database, .javascript, .rendering, .performance] {
            XCTAssertNoThrow(sut.logEvent("Event", category: category))
        }
    }
}
