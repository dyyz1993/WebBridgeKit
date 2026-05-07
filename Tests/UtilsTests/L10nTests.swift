//
//  L10nTests.swift
//  UtilsTests
//

import XCTest
@testable import WebBridgeKit

final class L10nTests: XCTestCase {

    func testTrReturnsKeyAsFallback() {
        let result = L10n.tr("nonexistent.key.test")
        XCTAssertEqual(result, "nonexistent.key.test")
    }

    func testTrWithArgsFormatsString() {
        let result = L10n.tr("test.format", "value1", "value2")
        XCTAssertTrue(result.contains("test.format") || result.contains("value1"))
    }

    func testTrWithEmptyKey() {
        let result = L10n.tr("")
        XCTAssertEqual(result, "")
    }

    func testTrWithSpecialCharacters() {
        let result = L10n.tr("key.with.special.chars!@#$%")
        XCTAssertEqual(result, "key.with.special.chars!@#$%")
    }

    func testTrWithUnicodeKey() {
        let result = L10n.tr("测试键")
        XCTAssertEqual(result, "测试键")
    }

    func testTrWithCustomTableName() {
        let result = L10n.tr("some.key", tableName: "NonExistentTable")
        XCTAssertEqual(result, "some.key")
    }

    func testTrWithMultipleArgs() {
        let result = L10n.tr("%@ and %@ and %@", "a", "b", "c")
        XCTAssertTrue(result.contains("a"))
        XCTAssertTrue(result.contains("b"))
        XCTAssertTrue(result.contains("c"))
    }

    func testTrWithNoArgs() {
        let result = L10n.tr("simple.key")
        XCTAssertEqual(result, "simple.key")
    }

    func testTrWithIntegerArg() {
        let result = L10n.tr("count.%ld", 42)
        XCTAssertTrue(result.contains("42"))
    }
}
