//
//  WebBrowserManagerTests+Extended.swift
//  CoreTests
//

import XCTest
@testable import WebBridgeKit

final class WebBrowserManagerExtendedTests: XCTestCase {

    private var manager: WebBrowserManager!

    override func setUp() {
        super.setUp()
        manager = WebBrowserManager()
    }

    override func tearDown() {
        manager = nil
        super.tearDown()
    }

    // MARK: - Navigation History State

    func testGetNavigationHistoryReturnsEmptyArray() {
        let history = manager.getNavigationHistory()
        XCTAssertTrue(history.isEmpty)
        XCTAssertEqual(history.count, 0)
    }

    func testCurrentIndexIsZeroByDefault() {
        XCTAssertEqual(manager.currentIndex, 0)
    }

    func testCurrentBrowserPropertyIsNil() {
        XCTAssertNil(manager.currentBrowser)
    }

    func testCurrentModalPropertyIsNil() {
        XCTAssertNil(manager.currentModal)
    }

    // MARK: - Close Browser Edge Cases

    func testCloseBrowserWithAllReasons() {
        let reasons: [WebBrowserParams.CloseReason] = [
            .userAction, .javascript, .systemGesture,
            .backgroundTap, .timeout, .error
        ]
        for reason in reasons {
            manager.closeBrowser(animated: false, reason: reason)
        }
    }

    func testCloseBrowserAnimatedTrue() {
        manager.closeBrowser(animated: true)
    }

    func testCloseBrowserAnimatedFalse() {
        manager.closeBrowser(animated: false)
    }

    // MARK: - getCurrentBrowser

    func testGetCurrentBrowserReturnsNilInitially() {
        XCTAssertNil(manager.getCurrentBrowser())
    }

    // MARK: - Thread Safety

    func testConcurrentGetCurrentBrowser() {
        let expectation = self.expectation(description: "concurrent")
        expectation.expectedFulfillmentCount = 20

        for _ in 0..<20 {
            DispatchQueue.global().async { [weak self] in
                let _ = self?.manager.getCurrentBrowser()
                let _ = self?.manager.currentIndex
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 5.0)
    }

    func testConcurrentGetNavigationHistory() {
        let expectation = self.expectation(description: "concurrent")
        expectation.expectedFulfillmentCount = 20

        for _ in 0..<20 {
            DispatchQueue.global().async { [weak self] in
                let _ = self?.manager.getNavigationHistory()
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 5.0)
    }

    // MARK: - NavigationItem

    func testNavigationItemTimestamp() {
        let url = URL(string: "https://example.com")!
        let vc = UIViewController()
        let before = Date()
        let item = WebBrowserManager.NavigationItem(
            url: url,
            title: "Test",
            timestamp: Date(),
            viewController: vc,
            displayMode: .modal
        )
        let after = Date()
        XCTAssertGreaterThanOrEqual(item.timestamp, before)
        XCTAssertLessThanOrEqual(item.timestamp, after)
        XCTAssertEqual(item.displayMode, .modal)
    }

    func testNavigationItemDifferentURLs() {
        let url1 = URL(string: "https://example.com/page1")!
        let url2 = URL(string: "https://example.com/page2")!
        let vc1 = UIViewController()
        let vc2 = UIViewController()
        let item1 = WebBrowserManager.NavigationItem(
            url: url1, title: "Page 1", timestamp: Date(),
            viewController: vc1, displayMode: .normal
        )
        let item2 = WebBrowserManager.NavigationItem(
            url: url2, title: "Page 2", timestamp: Date(),
            viewController: vc2, displayMode: .immersive
        )
        XCTAssertNotEqual(item1.url, item2.url)
        XCTAssertNotEqual(item1.title, item2.title)
        XCTAssertNotEqual(item1.displayMode, item2.displayMode)
    }

    func testNavigationItemNilTitle() {
        let url = URL(string: "https://example.com")!
        let vc = UIViewController()
        let item = WebBrowserManager.NavigationItem(
            url: url, title: nil, timestamp: Date(),
            viewController: vc, displayMode: .normal
        )
        XCTAssertNil(item.title)
    }

    func testNavigationItemPreservesURLComponents() {
        let url = URL(string: "https://example.com/path?query=value#fragment")!
        let vc = UIViewController()
        let item = WebBrowserManager.NavigationItem(
            url: url, title: "Test", timestamp: Date(),
            viewController: vc, displayMode: .normal
        )
        XCTAssertEqual(item.url.absoluteString, "https://example.com/path?query=value#fragment")
    }
}
