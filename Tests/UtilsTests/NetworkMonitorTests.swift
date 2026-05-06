//
//  NetworkMonitorTests.swift
//  UtilsTests
//

import XCTest
@testable import WebBridgeKit

final class NetworkMonitorTests: XCTestCase {

    private var monitor: NetworkMonitor!

    override func setUp() {
        super.setUp()
        monitor = NetworkMonitor.shared
    }

    override func tearDown() {
        monitor.removeAllCallbacks()
        super.tearDown()
    }

    // MARK: - Singleton

    func testSharedInstanceIsSingleton() {
        XCTAssertIdentical(NetworkMonitor.shared, NetworkMonitor.shared)
    }

    // MARK: - Initial State

    func testInitialConnectionTypeIsSet() {
        let type = monitor.connectionType
        XCTAssertNotNil(type)
    }

    // MARK: - Status Description

    func testGetStatusDescriptionReturnsNonEmpty() {
        let desc = monitor.getStatusDescription()
        XCTAssertFalse(desc.isEmpty)
    }

    func testGetStatusDescriptionOfflineWhenDisconnected() {
        let desc = monitor.getStatusDescription()
        if !monitor.isConnected {
            XCTAssertEqual(desc, "Offline")
        }
    }

    func testGetStatusDescriptionWiFiWhenConnected() {
        if monitor.isConnected && monitor.connectionType == .wifi {
            XCTAssertEqual(monitor.getStatusDescription(), "WiFi")
        }
    }

    func testGetStatusDescriptionCellular() {
        if monitor.isConnected && monitor.connectionType == .cellular {
            XCTAssertEqual(monitor.getStatusDescription(), "Cellular")
        }
    }

    // MARK: - Connection Type Check

    func testIsCellular() {
        let result = monitor.isCellular()
        XCTAssertEqual(result, monitor.connectionType == .cellular)
    }

    func testIsWiFi() {
        let result = monitor.isWiFi()
        XCTAssertEqual(result, monitor.connectionType == .wifi)
    }

    // MARK: - Callbacks

    func testAddStatusChangeCallback() {
        let expectation = XCTestExpectation(description: "callback registered")
        monitor.addStatusChangeCallback { _, _ in
            expectation.fulfill()
        }
        XCTAssertTrue(true, "Callback added without error")
        monitor.removeAllCallbacks()
    }

    func testRemoveAllCallbacks() {
        monitor.addStatusChangeCallback { _, _ in }
        monitor.addStatusChangeCallback { _, _ in }
        monitor.removeAllCallbacks()
    }

    // MARK: - ensureNetworkAvailable

    func testEnsureNetworkAvailableThrowsWhenOffline() {
        if !monitor.isConnected {
            XCTAssertThrowsError(try monitor.ensureNetworkAvailable())
        }
    }

    func testEnsureNetworkAvailableSucceedsWhenOnline() {
        if monitor.isConnected {
            XCTAssertNoThrow(try monitor.ensureNetworkAvailable())
        }
    }

    // MARK: - warnIfCellular

    func testWarnIfCellularReturnsMatchingValue() {
        let result = monitor.warnIfCellular()
        XCTAssertEqual(result, monitor.isCellular())
    }

    // MARK: - ConnectionType Enum

    func testConnectionTypeCases() {
        let types: [ConnectionType] = [.wifi, .cellular, .ethernet, .none]
        XCTAssertEqual(types.count, 4)
    }

    // MARK: - Notification Name

    func testNetworkStatusDidChangeNotification() {
        XCTAssertEqual(Notification.Name.networkStatusDidChange.rawValue, "com.webbridgekit.network.statusDidChange")
    }
}
