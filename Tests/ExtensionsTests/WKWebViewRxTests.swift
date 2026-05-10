//
//  WKWebViewRxTests.swift
//  ExtensionsTests
//
//  Created for WebBridgeKit test coverage.
//

import XCTest
@testable import WebBridgeKit
import RxSwift
import RxCocoa
import WebKit

final class WKWebViewRxPropertyTests: XCTestCase {

    private var webView: WKWebView!
    private var disposeBag: DisposeBag!

    override func setUp() {
        super.setUp()
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        disposeBag = DisposeBag()
    }

    override func tearDown() {
        webView = nil
        disposeBag = nil
        super.tearDown()
    }

    // MARK: - estimatedProgress observable

    func testEstimatedProgress_shouldBeObservable() {
        let observable = webView.rx.estimatedProgress
        XCTAssertNotNil(observable, "estimatedProgress should return a non-nil Observable")
    }

    // MARK: - title observable

    func testTitle_shouldBeObservable() {
        let observable = webView.rx.title
        XCTAssertNotNil(observable, "title should return a non-nil Observable")
    }

    // MARK: - url observable

    func testUrl_shouldBeObservable() {
        let observable = webView.rx.url
        XCTAssertNotNil(observable, "url should return a non-nil Observable")
    }

    // MARK: - canGoBack observable

    func testCanGoBack_shouldBeObservable() {
        let observable = webView.rx.canGoBack
        XCTAssertNotNil(observable, "canGoBack should return a non-nil Observable")
    }

    // MARK: - canGoForward observable

    func testCanGoForward_shouldBeObservable() {
        let observable = webView.rx.canGoForward
        XCTAssertNotNil(observable, "canGoForward should return a non-nil Observable")
    }

    // MARK: - isLoading observable

    func testIsLoading_shouldBeObservable() {
        let observable = webView.rx.isLoading
        XCTAssertNotNil(observable, "isLoading should return a non-nil Observable")
    }

    // MARK: - uiDelegate proxy

    func testUIDelegate_shouldReturnDelegateProxy() {
        let proxy = webView.rx.uiDelegate
        XCTAssertNotNil(proxy, "uiDelegate should return a DelegateProxy")
    }

    // MARK: - navigationDelegate proxy

    func testNavigationDelegate_shouldBeObservable() {
        let observable = webView.rx.didStart
        XCTAssertNotNil(observable, "didStart should return a non-nil Observable")
    }

    func testDidFinish_shouldBeObservable() {
        let observable = webView.rx.didFinish
        XCTAssertNotNil(observable, "didFinish should return a non-nil Observable")
    }

    func testDidFail_shouldBeObservable() {
        let observable = webView.rx.didFail
        XCTAssertNotNil(observable, "didFail should return a non-nil Observable")
    }

    func testNavigationDelegate_shouldBeAccessible() {
        XCTAssertNotNil(webView.rx.navigationDelegate, "navigationDelegate proxy should be accessible")
    }

    // MARK: - UI delegate events

    func testAlert_shouldBeObservable() {
        let observable = webView.rx.alert
        XCTAssertNotNil(observable, "alert should return a non-nil Observable")
    }

    func testConfirm_shouldBeObservable() {
        let observable = webView.rx.confirm
        XCTAssertNotNil(observable, "confirm should return a non-nil Observable")
    }

    func testPrompt_shouldBeObservable() {
        let observable = webView.rx.prompt
        XCTAssertNotNil(observable, "prompt should return a non-nil Observable")
    }

    // MARK: - scriptMessage

    func testScriptMessage_shouldBeObservable() {
        let observable = webView.rx.scriptMessage
        XCTAssertNotNil(observable, "scriptMessage should return a non-nil Observable")
    }
}


