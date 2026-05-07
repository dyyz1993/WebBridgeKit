//
//  WebBridgeNotificationsTests.swift
//  UtilsTests
//

import XCTest
@testable import WebBridgeKit

final class WebBridgeNotificationsTests: XCTestCase {

    func testAllNotificationNamesAreUnique() {
        let names: [Notification.Name] = [
            .manifestCacheDidUpdate, .manifestCacheDidClear,
            .browserDidOpen, .browserDidClose,
            .historyDidUpdate, .historyDidClear,
            .favoriteDidUpdate, .favoriteDidRemove,
            .cacheSizeDidChange,
            .qrScannerDidScanURL,
            .updateDebugLabel,
            .didReceivePushMessage,
            .manifestCacheHit,
            .clearAllCaches,
            .resourceDelivered,
            .resourceLogNotification,
            .automationTestOpenURL,
            .networkStatusDidChange
        ]

        let uniqueValues = Set(names.map { $0.rawValue })
        XCTAssertEqual(names.count, uniqueValues.count, "Duplicate notification names found")
    }

    func testManifestCacheNotifications() {
        XCTAssertEqual(Notification.Name.manifestCacheDidUpdate.rawValue, "ManifestCacheDidUpdate")
        XCTAssertEqual(Notification.Name.manifestCacheDidClear.rawValue, "ManifestCacheDidClear")
    }

    func testBrowserNotifications() {
        XCTAssertEqual(Notification.Name.browserDidOpen.rawValue, "WebBrowserDidOpen")
        XCTAssertEqual(Notification.Name.browserDidClose.rawValue, "WebBrowserDidClose")
    }

    func testHistoryNotifications() {
        XCTAssertEqual(Notification.Name.historyDidUpdate.rawValue, "WebPageHistoryDidUpdate")
        XCTAssertEqual(Notification.Name.historyDidClear.rawValue, "WebPageHistoryDidClear")
    }

    func testFavoriteNotifications() {
        XCTAssertEqual(Notification.Name.favoriteDidUpdate.rawValue, "URLFavoriteDidUpdate")
        XCTAssertEqual(Notification.Name.favoriteDidRemove.rawValue, "URLFavoriteDidRemove")
    }

    func testCacheSizeNotification() {
        XCTAssertEqual(Notification.Name.cacheSizeDidChange.rawValue, "WebCacheSizeDidChange")
    }

    func testQRScannerNotification() {
        XCTAssertEqual(Notification.Name.qrScannerDidScanURL.rawValue, "QRScannerDidScanURL")
    }

    func testMessageNotification() {
        XCTAssertEqual(Notification.Name.didReceivePushMessage.rawValue, "didReceivePushMessage")
    }

    func testNetworkStatusNotification() {
        XCTAssertEqual(Notification.Name.networkStatusDidChange.rawValue, "com.webbridgekit.network.statusDidChange")
    }

    func testUserInfoKeyPageKey() {
        XCTAssertEqual(Notification.Name.UserInfoKey.pageKey, "pageKey")
    }

    func testUserInfoKeyURL() {
        XCTAssertEqual(Notification.Name.UserInfoKey.url, "url")
    }

    func testUserInfoKeySize() {
        XCTAssertEqual(Notification.Name.UserInfoKey.size, "size")
    }

    func testUserInfoKeyTitle() {
        XCTAssertEqual(Notification.Name.UserInfoKey.title, "title")
    }

    func testUserInfoKeyError() {
        XCTAssertEqual(Notification.Name.UserInfoKey.error, "error")
    }

    func testUserInfoKeyTimestamp() {
        XCTAssertEqual(Notification.Name.UserInfoKey.timestamp, "timestamp")
    }

    func testUserInfoKeySuccess() {
        XCTAssertEqual(Notification.Name.UserInfoKey.success, "success")
    }

    func testNotificationCanBePosted() {
        let expectation = self.expectation(description: "notification received")
        let observer = NotificationCenter.default.addObserver(
            forName: .manifestCacheDidUpdate,
            object: nil,
            queue: .main
        ) { notification in
            XCTAssertEqual(notification.userInfo?["test"] as? String, "value")
            expectation.fulfill()
        }

        NotificationCenter.default.post(
            name: .manifestCacheDidUpdate,
            object: nil,
            userInfo: ["test": "value"]
        )

        waitForExpectations(timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }
}
