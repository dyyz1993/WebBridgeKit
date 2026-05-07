import XCTest
@testable import WebBridgeKit
import RxSwift
import RxCocoa

final class CacheAppInfoTests: XCTestCase {

    func testInit_WhenAllPropertiesSet_HoldsValues() {
        let info = CacheAppInfo(
            appID: "com.example.app",
            name: "Example App",
            version: "1.0.0",
            cacheSize: 1024,
            icon: Data("icon".utf8),
            pageKeys: ["page1", "page2"]
        )

        XCTAssertEqual(info.appID, "com.example.app")
        XCTAssertEqual(info.name, "Example App")
        XCTAssertEqual(info.version, "1.0.0")
        XCTAssertEqual(info.cacheSize, 1024)
        XCTAssertNotNil(info.icon)
        XCTAssertEqual(info.pageKeys, ["page1", "page2"])
    }

    func testInit_WhenOptionalFieldsNil_HoldsNilValues() {
        let info = CacheAppInfo(
            appID: "test",
            name: nil,
            version: "0.0.1",
            cacheSize: 0,
            icon: nil,
            pageKeys: []
        )

        XCTAssertEqual(info.appID, "test")
        XCTAssertNil(info.name)
        XCTAssertEqual(info.version, "0.0.1")
        XCTAssertEqual(info.cacheSize, 0)
        XCTAssertNil(info.icon)
        XCTAssertTrue(info.pageKeys.isEmpty)
    }

    func testInit_WhenEmptyPageKeys_HoldsEmptyArray() {
        let info = CacheAppInfo(
            appID: "empty-app",
            name: "Empty",
            version: "2.0.0",
            cacheSize: 5000,
            icon: nil,
            pageKeys: []
        )

        XCTAssertTrue(info.pageKeys.isEmpty)
    }

    func testInit_WhenLargeCacheSize_HoldsValue() {
        let largeSize: Int64 = 1024 * 1024 * 1024
        let info = CacheAppInfo(
            appID: "large-app",
            name: "Large",
            version: "1.0.0",
            cacheSize: largeSize,
            icon: nil,
            pageKeys: ["key1"]
        )

        XCTAssertEqual(info.cacheSize, largeSize)
    }

    func testEquality_WhenSameProperties_AreEqual() {
        let info1 = CacheAppInfo(
            appID: "same",
            name: "Same",
            version: "1.0.0",
            cacheSize: 100,
            icon: nil,
            pageKeys: ["a"]
        )

        let info2 = CacheAppInfo(
            appID: "same",
            name: "Same",
            version: "1.0.0",
            cacheSize: 100,
            icon: nil,
            pageKeys: ["a"]
        )

        XCTAssertEqual(info1.appID, info2.appID)
        XCTAssertEqual(info1.name, info2.name)
        XCTAssertEqual(info1.version, info2.version)
        XCTAssertEqual(info1.cacheSize, info2.cacheSize)
        XCTAssertEqual(info1.pageKeys, info2.pageKeys)
    }
}
