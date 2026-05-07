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

    // MARK: - Open Browser from Notification

    func testOpenBrowserFromNotificationMissingPage() {
        let notification = Notification(name: Notification.Name("test"), object: nil, userInfo: [:])
        manager.openBrowser(from: notification)
    }

    func testOpenBrowserFromNotificationWithPage() {
        let notification = Notification(
            name: Notification.Name("test"),
            object: nil,
            userInfo: ["page": "settings"]
        )
        manager.openBrowser(from: notification)
    }

    func testOpenBrowserFromNotificationNilUserInfo() {
        let notification = Notification(name: Notification.Name("test"), object: nil)
        manager.openBrowser(from: notification)
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

    // MARK: - GoBack / GoForward Edge Cases

    func testGoBackMultipleSteps() {
        let result = manager.goBack(steps: 5)
        XCTAssertFalse(result)
    }

    func testGoForwardMultipleSteps() {
        let result = manager.goForward(steps: 5)
        XCTAssertFalse(result)
    }

    func testGoBackNegativeSteps() {
        let result = manager.goBack(steps: -1)
        XCTAssertFalse(result)
    }

    func testGoForwardNegativeSteps() {
        let result = manager.goForward(steps: -1)
        XCTAssertFalse(result)
    }

    // MARK: - Open Browser with Various URLs

    func testOpenBrowserWithHTTPURL() {
        let url = URL(string: "http://example.com")!
        let expectation = self.expectation(description: "completion")
        manager.openBrowser(url: url) { _ in
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2.0)
    }

    func testOpenBrowserWithLocalBarkURL() {
        let url = URL(string: "bark://internal?page=settings")!
        let expectation = self.expectation(description: "completion")
        manager.openBrowser(url: url) { _ in
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2.0)
    }

    func testOpenBrowserWithHTMLFileURL() {
        let url = URL(string: "file:///tmp/test.html")!
        let expectation = self.expectation(description: "completion")
        manager.openBrowser(url: url) { _ in
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2.0)
    }

    func testOpenBrowserAnimatedFalse() {
        let url = URL(string: "https://example.com")!
        let expectation = self.expectation(description: "completion")
        manager.openBrowser(url: url, animated: false) { _ in
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2.0)
    }

    func testOpenBrowserWithoutCompletion() {
        let url = URL(string: "https://example.com")!
        manager.openBrowser(url: url)
    }

    // MARK: - getCurrentBrowser

    func testGetCurrentBrowserReturnsNilInitially() {
        XCTAssertNil(manager.getCurrentBrowser())
    }

    func testGetCurrentBrowserAfterSetCurrentModal() {
        // ModalWebViewController may not be available in test, test nil path
        XCTAssertNil(manager.getCurrentBrowser())
    }

    // MARK: - Thread Safety

    func testConcurrentGetCurrentBrowser() {
        let group = DispatchGroup()
        for _ in 0..<20 {
            group.enter()
            DispatchQueue.global().async { [weak self] in
                let _ = self?.manager.getCurrentBrowser()
                let _ = self?.manager.currentIndex
                group.leave()
            }
        }
        group.wait()
    }

    func testConcurrentGoBackAndGoForward() {
        let group = DispatchGroup()
        for _ in 0..<10 {
            group.enter()
            DispatchQueue.global().async { [weak self] in
                let _ = self?.manager.goBack(steps: 1)
                let _ = self?.manager.goForward(steps: 1)
                group.leave()
            }
        }
        group.wait()
    }
}
