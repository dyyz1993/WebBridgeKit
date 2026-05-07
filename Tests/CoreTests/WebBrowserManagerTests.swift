//
//  WebBrowserManagerTests.swift
//  CoreTests
//

import XCTest
@testable import WebBridgeKit

final class WebBrowserManagerTests: XCTestCase {

    private var manager: WebBrowserManager!

    override func setUp() {
        super.setUp()
        manager = WebBrowserManager()
    }

    override func tearDown() {
        manager = nil
        super.tearDown()
    }

    // MARK: - Initialization

    func testInitDoesNotCrash() {
        let mgr = WebBrowserManager()
        XCTAssertNotNil(mgr)
    }

    func testSharedSingletonIsSameInstance() {
        let a = WebBrowserManager.shared
        let b = WebBridgeKit.WebBrowserManager.shared
        XCTAssertTrue(a === b)
    }

    func testCurrentIndexStartsAtZero() {
        XCTAssertEqual(manager.currentIndex, 0)
    }

    // MARK: - Navigation History

    func testGetNavigationHistoryStartsEmpty() {
        let history = manager.getNavigationHistory()
        XCTAssertTrue(history.isEmpty)
    }

    func testGetCurrentBrowserStartsNil() {
        XCTAssertNil(manager.getCurrentBrowser())
    }

    func testCurrentBrowserStartsNil() {
        XCTAssertNil(manager.currentBrowser)
    }

    func testCurrentModalStartsNil() {
        XCTAssertNil(manager.currentModal)
    }

    // MARK: - Open Browser (No Navigation Controller)

    func testOpenBrowserWithoutNavigationControllerCompletes() {
        let url = URL(string: "https://example.com")!
        let expectation = self.expectation(description: "completion")

        manager.openBrowser(url: url) { result in
            if case .failure = result {
                // Expected: no nav controller available
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
    }

    func testOpenBrowserWithNormalModeCallsCompletion() {
        let url = URL(string: "https://example.com")!
        let params = WebBrowserParams(displayMode: .normal)
        let expectation = self.expectation(description: "completion")

        manager.openBrowser(url: url, params: params) { result in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
    }

    func testOpenBrowserWithImmersiveModeCallsCompletion() {
        let url = URL(string: "https://example.com")!
        let params = WebBrowserParams(displayMode: .immersive)
        let expectation = self.expectation(description: "completion")

        manager.openBrowser(url: url, params: params) { result in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
    }

    func testOpenBrowserWithModalModeCallsCompletion() {
        let url = URL(string: "https://example.com")!
        let params = WebBrowserParams(displayMode: .modal)
        let expectation = self.expectation(description: "completion")

        manager.openBrowser(url: url, params: params) { result in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
    }

    func testOpenBrowserWithDefaultParams() {
        let url = URL(string: "https://example.com")!
        let expectation = self.expectation(description: "completion")

        manager.openBrowser(url: url, params: nil) { result in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
    }

    func testOpenBrowserWithForceRefresh() {
        let url = URL(string: "https://example.com")!
        let expectation = self.expectation(description: "completion")

        manager.openBrowser(url: url, forceRefresh: true) { result in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
    }

    // MARK: - Close Browser

    func testCloseBrowserWithoutNavControllerDoesNotCrash() {
        manager.closeBrowser(animated: false, reason: .userAction)
    }

    func testCloseBrowserWithDifferentReasons() {
        let reasons: [WebBrowserParams.CloseReason] = [
            .userAction, .javascript, .systemGesture,
            .backgroundTap, .timeout, .error
        ]
        for reason in reasons {
            manager.closeBrowser(animated: false, reason: reason)
        }
    }

    // MARK: - GoBack / GoForward

    func testGoBackWithEmptyStackReturnsFalse() {
        let result = manager.goBack(steps: 1)
        XCTAssertFalse(result)
    }

    func testGoForwardWithEmptyStackReturnsFalse() {
        let result = manager.goForward(steps: 1)
        XCTAssertFalse(result)
    }

    func testGoBackWithZeroStepsReturnsFalse() {
        let result = manager.goBack(steps: 0)
        XCTAssertFalse(result)
    }

    func testGoForwardWithZeroSteps() {
        let result = manager.goForward(steps: 0)
        XCTAssertFalse(result)
    }

    // MARK: - Display Mode

    func testDisplayModeNormalFromString() {
        let mode = WebBrowserParams.DisplayMode.from(string: "normal")
        XCTAssertEqual(mode, .normal)
    }

    func testDisplayModeImmersiveFromString() {
        let mode = WebBrowserParams.DisplayMode.from(string: "immersive")
        XCTAssertEqual(mode, .immersive)
    }

    func testDisplayModeModalFromString() {
        let mode = WebBrowserParams.DisplayMode.from(string: "modal")
        XCTAssertEqual(mode, .modal)
    }

    func testDisplayModeDefaultIsNormal() {
        let mode = WebBrowserParams.DisplayMode.from(string: "unknown")
        XCTAssertEqual(mode, .normal)
    }

    func testDisplayModeCaseInsensitive() {
        XCTAssertEqual(WebBrowserParams.DisplayMode.from(string: "MODAL"), .modal)
        XCTAssertEqual(WebBrowserParams.DisplayMode.from(string: "Immersive"), .immersive)
        XCTAssertEqual(WebBrowserParams.DisplayMode.from(string: "NORMAL"), .normal)
    }

    // MARK: - Close Reason

    func testCloseReasonFromString() {
        XCTAssertEqual(WebBrowserParams.CloseReason.from(string: "javascript"), .javascript)
        XCTAssertEqual(WebBrowserParams.CloseReason.from(string: "system_gesture"), .systemGesture)
        XCTAssertEqual(WebBrowserParams.CloseReason.from(string: "background_tap"), .backgroundTap)
        XCTAssertEqual(WebBrowserParams.CloseReason.from(string: "timeout"), .timeout)
        XCTAssertEqual(WebBrowserParams.CloseReason.from(string: "error"), .error)
    }

    func testCloseReasonDefaultIsUserAction() {
        XCTAssertEqual(WebBrowserParams.CloseReason.from(string: "unknown"), .userAction)
    }

    // MARK: - Navigation Item

    func testNavigationItemCreation() {
        let url = URL(string: "https://example.com")!
        let vc = UIViewController()
        let item = WebBrowserManager.NavigationItem(
            url: url,
            title: "Test",
            timestamp: Date(),
            viewController: vc,
            displayMode: .normal
        )
        XCTAssertEqual(item.url, url)
        XCTAssertEqual(item.title, "Test")
        XCTAssertEqual(item.displayMode, .normal)
    }

    // MARK: - Thread Safety

    func testConcurrentAccessDoesNotCrash() {
        let url = URL(string: "https://example.com")!
        let group = DispatchGroup()

        for i in 0..<10 {
            group.enter()
            DispatchQueue.global().async { [weak self] in
                _ = self?.manager.getNavigationHistory()
                _ = self?.manager.getCurrentBrowser()
                _ = self?.manager.currentIndex
                self?.manager.openBrowser(url: url) { _ in
                    group.leave()
                }
            }
        }

        let result = waitForExpectations(timeout: 5.0)
        group.wait()
    }
}
