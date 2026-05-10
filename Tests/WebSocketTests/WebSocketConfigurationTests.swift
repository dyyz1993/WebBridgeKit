//
//  WebSocketConfigurationTests.swift
//  WebBridgeKitTests
//

import XCTest
@testable import WebBridgeKit

final class WebSocketConfigurationTests: XCTestCase {

    // MARK: - ReconnectPolicy Default

    func testReconnectPolicyDefault_maxRetriesIs5() {
        XCTAssertEqual(ReconnectPolicy.default.maxRetries, 5)
    }

    func testReconnectPolicyDefault_baseIntervalIs1Second() {
        XCTAssertEqual(ReconnectPolicy.default.baseInterval, 1.0)
    }

    func testReconnectPolicyDefault_maxIntervalIs30Seconds() {
        XCTAssertEqual(ReconnectPolicy.default.maxInterval, 30.0)
    }

    func testReconnectPolicyDefault_multiplierIs2() {
        XCTAssertEqual(ReconnectPolicy.default.multiplier, 2.0)
    }

    // MARK: - ReconnectPolicy Custom Values

    func testReconnectPolicyCustom_allFieldsSet() {
        let policy = ReconnectPolicy(maxRetries: 10, baseInterval: 2.0, maxInterval: 60.0, multiplier: 3.0)
        XCTAssertEqual(policy.maxRetries, 10)
        XCTAssertEqual(policy.baseInterval, 2.0)
        XCTAssertEqual(policy.maxInterval, 60.0)
        XCTAssertEqual(policy.multiplier, 3.0)
    }

    func testReconnectPolicyInitUsesDefaultsWhenOmitted() {
        let policy = ReconnectPolicy()
        XCTAssertEqual(policy.maxRetries, 5)
        XCTAssertEqual(policy.baseInterval, 1.0)
        XCTAssertEqual(policy.maxInterval, 30.0)
        XCTAssertEqual(policy.multiplier, 2.0)
    }

    // MARK: - ReconnectPolicy Equatable

    func testReconnectPolicyEquatable_sameValuesAreEqual() {
        let a = ReconnectPolicy(maxRetries: 3, baseInterval: 1.5, maxInterval: 20.0, multiplier: 2.5)
        let b = ReconnectPolicy(maxRetries: 3, baseInterval: 1.5, maxInterval: 20.0, multiplier: 2.5)
        XCTAssertEqual(a, b)
    }

    func testReconnectPolicyEquatable_differentMaxRetriesNotEqual() {
        let a = ReconnectPolicy(maxRetries: 3, baseInterval: 1.0, maxInterval: 10.0, multiplier: 2.0)
        let b = ReconnectPolicy(maxRetries: 4, baseInterval: 1.0, maxInterval: 10.0, multiplier: 2.0)
        XCTAssertNotEqual(a, b)
    }

    func testReconnectPolicyEquatable_differentBaseIntervalNotEqual() {
        let a = ReconnectPolicy(maxRetries: 3, baseInterval: 1.0, maxInterval: 10.0, multiplier: 2.0)
        let b = ReconnectPolicy(maxRetries: 3, baseInterval: 2.0, maxInterval: 10.0, multiplier: 2.0)
        XCTAssertNotEqual(a, b)
    }

    func testReconnectPolicyEquatable_defaultMatchesExplicitDefault() {
        let explicit = ReconnectPolicy(maxRetries: 5, baseInterval: 1.0, maxInterval: 30.0, multiplier: 2.0)
        XCTAssertEqual(ReconnectPolicy.default, explicit)
    }

    // MARK: - ReconnectPolicy interval(for:)

    func testReconnectPolicyInterval_attempt0ReturnsBaseInterval() {
        let policy = ReconnectPolicy(baseInterval: 2.0, maxInterval: 30.0, multiplier: 2.0)
        let interval = policy.interval(for: 0)
        XCTAssertGreaterThanOrEqual(interval, 2.0)
        XCTAssertLessThan(interval, 2.2)
    }

    func testReconnectPolicyInterval_increasesWithAttempt() {
        let policy = ReconnectPolicy(baseInterval: 1.0, maxInterval: 100.0, multiplier: 2.0)
        let i0 = policy.interval(for: 0)
        let i1 = policy.interval(for: 1)
        let i2 = policy.interval(for: 2)
        XCTAssertLessThan(i0, i1)
        XCTAssertLessThan(i1, i2)
    }

    func testReconnectPolicyInterval_cappedAtMaxInterval() {
        let policy = ReconnectPolicy(baseInterval: 1.0, maxInterval: 5.0, multiplier: 10.0)
        let interval = policy.interval(for: 50)
        XCTAssertLessThanOrEqual(interval, 5.5)
    }

    func testReconnectPolicyInterval_appliesJitter() {
        let policy = ReconnectPolicy(baseInterval: 10.0, maxInterval: 100.0, multiplier: 1.0)
        let intervals = (0..<20).map { policy.interval(for: $0) }
        let unique = Set(intervals.map { Int($0 * 100) })
        XCTAssertGreaterThan(unique.count, 1, "Jitter should produce varying values")
    }

    func testReconnectPolicyInterval_negativeAttemptTreatedAsZero() {
        let policy = ReconnectPolicy(baseInterval: 1.0, maxInterval: 30.0, multiplier: 2.0)
        let interval = policy.interval(for: -1)
        XCTAssertGreaterThan(interval, 0)
    }

    // MARK: - WebSocketConfiguration Defaults

    func testWebSocketConfigurationDefault_urlStored() {
        let config = WebSocketConfiguration(url: URL(string: "ws://localhost")!)
        XCTAssertEqual(config.url.absoluteString, "ws://localhost")
    }

    func testWebSocketConfigurationDefault_headersIsEmpty() {
        let config = WebSocketConfiguration(url: URL(string: "ws://localhost")!)
        XCTAssertTrue(config.headers.isEmpty)
    }

    func testWebSocketConfigurationDefault_heartbeatIntervalIs30() {
        let config = WebSocketConfiguration(url: URL(string: "ws://localhost")!)
        XCTAssertEqual(config.heartbeatInterval, 30.0)
    }

    func testWebSocketConfigurationDefault_messageQueueSizeIs100() {
        let config = WebSocketConfiguration(url: URL(string: "ws://localhost")!)
        XCTAssertEqual(config.messageQueueSize, 100)
    }

    func testWebSocketConfigurationDefault_reconnectPolicyIsDefault() {
        let config = WebSocketConfiguration(url: URL(string: "ws://localhost")!)
        XCTAssertEqual(config.reconnectPolicy, ReconnectPolicy.default)
    }

    // MARK: - WebSocketConfiguration Custom

    func testWebSocketConfigurationCustom_allFieldsSet() {
        let config = WebSocketConfiguration(
            url: URL(string: "wss://example.com/ws")!,
            headers: ["Authorization": "Bearer token123"],
            reconnectPolicy: ReconnectPolicy(maxRetries: 3),
            heartbeatInterval: 15.0,
            messageQueueSize: 200
        )
        XCTAssertEqual(config.url.absoluteString, "wss://example.com/ws")
        XCTAssertEqual(config.headers.count, 1)
        XCTAssertEqual(config.headers["Authorization"], "Bearer token123")
        XCTAssertEqual(config.reconnectPolicy.maxRetries, 3)
        XCTAssertEqual(config.heartbeatInterval, 15.0)
        XCTAssertEqual(config.messageQueueSize, 200)
    }

    func testWebSocketConfigurationCustom_multipleHeaders() {
        let config = WebSocketConfiguration(
            url: URL(string: "ws://x")!,
            headers: ["A": "1", "B": "2"]
        )
        XCTAssertEqual(config.headers.count, 2)
        XCTAssertEqual(config.headers["A"], "1")
        XCTAssertEqual(config.headers["B"], "2")
    }
}
