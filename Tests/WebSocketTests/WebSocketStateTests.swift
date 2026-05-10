//
//  WebSocketStateTests.swift
//  WebBridgeKitTests
//

import XCTest
@testable import WebBridgeKit

final class WebSocketStateTests: XCTestCase {

    // MARK: - RawValue

    func testRawValue_disconnected() {
        XCTAssertEqual(WebSocketState.disconnected.rawValue, "disconnected")
    }

    func testRawValue_connecting() {
        XCTAssertEqual(WebSocketState.connecting.rawValue, "connecting")
    }

    func testRawValue_connected() {
        XCTAssertEqual(WebSocketState.connected.rawValue, "connected")
    }

    func testRawValue_disconnecting() {
        XCTAssertEqual(WebSocketState.disconnecting.rawValue, "disconnecting")
    }

    func testRawValue_reconnecting() {
        XCTAssertEqual(WebSocketState.reconnecting.rawValue, "reconnecting")
    }

    // MARK: - isOperational

    func testIsOperational_connectedReturnsTrue() {
        XCTAssertTrue(WebSocketState.connected.isOperational)
    }

    func testIsOperational_disconnectedReturnsFalse() {
        XCTAssertFalse(WebSocketState.disconnected.isOperational)
    }

    func testIsOperational_connectingReturnsFalse() {
        XCTAssertFalse(WebSocketState.connecting.isOperational)
    }

    func testIsOperational_disconnectingReturnsFalse() {
        XCTAssertFalse(WebSocketState.disconnecting.isOperational)
    }

    func testIsOperational_reconnectingReturnsFalse() {
        XCTAssertFalse(WebSocketState.reconnecting.isOperational)
    }

    // MARK: - All Cases Covered

    func testAllCases_countIs5() {
        let allCases: [WebSocketState] = [
            .disconnected, .connecting, .connected,
            .disconnecting, .reconnecting
        ]
        XCTAssertEqual(allCases.count, 5)
    }

    func testAllCases_haveDistinctRawValues() {
        let rawValues = Set([
            WebSocketState.disconnected.rawValue,
            WebSocketState.connecting.rawValue,
            WebSocketState.connected.rawValue,
            WebSocketState.disconnecting.rawValue,
            WebSocketState.reconnecting.rawValue
        ])
        XCTAssertEqual(rawValues.count, 5)
    }

    func testAllCases_onlyConnectedIsOperational() {
        let states: [WebSocketState] = [
            .disconnected, .connecting, .connected,
            .disconnecting, .reconnecting
        ]
        let operationalCount = states.filter(\.isOperational).count
        XCTAssertEqual(operationalCount, 1)
        XCTAssertTrue(states.first(where: \.isOperational) == .connected)
    }

    // MARK: - Equatable

    func testEquatable_sameCaseEqual() {
        XCTAssertEqual(WebSocketState.connected, .connected)
        XCTAssertEqual(WebSocketState.disconnected, .disconnected)
    }

    func testEquatable_differentCaseNotEqual() {
        XCTAssertNotEqual(WebSocketState.connected, .disconnected)
        XCTAssertNotEqual(WebSocketState.connecting, .reconnecting)
    }
}
