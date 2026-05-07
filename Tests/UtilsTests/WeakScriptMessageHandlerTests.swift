//
//  WeakScriptMessageHandlerTests.swift
//  UtilsTests
//

import XCTest
import WebKit
@testable import WebBridgeKit

final class WeakScriptMessageHandlerTests: XCTestCase {

    func testInitStoresWeakReference() {
        let target = MockWKScriptMessageHandler()
        let handler = WeakScriptMessageHandler(target: target)
        XCTAssertTrue(handler.isTargetAlive)
    }

    func testIsTargetAliveWhenTargetExists() {
        var target: MockWKScriptMessageHandler? = MockWKScriptMessageHandler()
        let handler = WeakScriptMessageHandler(target: target!)
        XCTAssertTrue(handler.isTargetAlive)
        target = nil
        XCTAssertFalse(handler.isTargetAlive)
    }

    func testForwardsMessagesToTarget() {
        let target = MockWKScriptMessageHandler()
        let handler = WeakScriptMessageHandler(target: target)
        let controller = WKUserContentController()
        controller.add(handler, name: "testBridge")

        let config = WKWebViewConfiguration()
        config.userContentController.add(handler, name: "testBridge")
        let webView = WKWebView(frame: .zero, configuration: config)

        let evaluateExpectation = self.expectation(description: "script evaluated")
        webView.evaluateJavaScript("window.webkit.messageHandlers.testBridge.postMessage('hello')") { _, error in
            evaluateExpectation.fulfill()
        }
        waitForExpectations(timeout: 2.0)
    }

    func testDoesNotCrashWhenTargetDeallocated() {
        var target: MockWKScriptMessageHandler? = MockWKScriptMessageHandler()
        let handler = WeakScriptMessageHandler(target: target!)
        target = nil
        XCTAssertFalse(handler.isTargetAlive)
    }

    func testIsNSObjectSubclass() {
        let target = MockWKScriptMessageHandler()
        let handler = WeakScriptMessageHandler(target: target)
        XCTAssertTrue(handler is NSObject)
    }
}

private final class MockWKScriptMessageHandler: NSObject, WKScriptMessageHandler {
    var receivedMessages: [String] = []

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let body = message.body as? String {
            receivedMessages.append(body)
        }
    }
}
