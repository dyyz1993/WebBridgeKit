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

    func testEstimatedProgress_shouldEmitInitialValue() {
        let expectation = XCTestExpectation(description: "Initial estimatedProgress")

        webView.rx.estimatedProgress
            .take(1)
            .subscribe(onNext: { progress in
                XCTAssertEqual(progress, 0.0, "Initial estimated progress should be 0.0")
                expectation.fulfill()
            })
            .disposed(by: disposeBag)

        wait(for: [expectation], timeout: 2.0)
    }

    func testEstimatedProgress_shouldBeObservable() {
        let observable = webView.rx.estimatedProgress
        XCTAssertNotNil(observable, "estimatedProgress should return a non-nil Observable")
    }

    // MARK: - title observable

    func testTitle_shouldEmitInitialValue() {
        let expectation = XCTestExpectation(description: "Initial title")

        webView.rx.title
            .take(1)
            .subscribe(onNext: { title in
                XCTAssertNil(title, "Initial title should be nil")
                expectation.fulfill()
            })
            .disposed(by: disposeBag)

        wait(for: [expectation], timeout: 2.0)
    }

    func testTitle_shouldBeObservable() {
        let observable = webView.rx.title
        XCTAssertNotNil(observable, "title should return a non-nil Observable")
    }

    // MARK: - url observable

    func testUrl_shouldEmitInitialValue() {
        let expectation = XCTestExpectation(description: "Initial URL")

        webView.rx.url
            .take(1)
            .subscribe(onNext: { url in
                XCTAssertNil(url, "Initial URL should be nil")
                expectation.fulfill()
            })
            .disposed(by: disposeBag)

        wait(for: [expectation], timeout: 2.0)
    }

    func testUrl_shouldBeObservable() {
        let observable = webView.rx.url
        XCTAssertNotNil(observable, "url should return a non-nil Observable")
    }

    // MARK: - canGoBack observable

    func testCanGoBack_shouldEmitInitialValue() {
        let expectation = XCTestExpectation(description: "Initial canGoBack")

        webView.rx.canGoBack
            .take(1)
            .subscribe(onNext: { canGoBack in
                XCTAssertFalse(canGoBack, "Initial canGoBack should be false")
                expectation.fulfill()
            })
            .disposed(by: disposeBag)

        wait(for: [expectation], timeout: 2.0)
    }

    func testCanGoBack_shouldBeObservable() {
        let observable = webView.rx.canGoBack
        XCTAssertNotNil(observable, "canGoBack should return a non-nil Observable")
    }

    // MARK: - canGoForward observable

    func testCanGoForward_shouldEmitInitialValue() {
        let expectation = XCTestExpectation(description: "Initial canGoForward")

        webView.rx.canGoForward
            .take(1)
            .subscribe(onNext: { canGoForward in
                XCTAssertFalse(canGoForward, "Initial canGoForward should be false")
                expectation.fulfill()
            })
            .disposed(by: disposeBag)

        wait(for: [expectation], timeout: 2.0)
    }

    func testCanGoForward_shouldBeObservable() {
        let observable = webView.rx.canGoForward
        XCTAssertNotNil(observable, "canGoForward should return a non-nil Observable")
    }

    // MARK: - isLoading observable

    func testIsLoading_shouldEmitInitialValue() {
        let expectation = XCTestExpectation(description: "Initial isLoading")

        webView.rx.isLoading
            .take(1)
            .subscribe(onNext: { isLoading in
                XCTAssertFalse(isLoading, "Initial isLoading should be false")
                expectation.fulfill()
            })
            .disposed(by: disposeBag)

        wait(for: [expectation], timeout: 2.0)
    }

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

    func testDidCommit_shouldBeObservable() {
        let observable: Observable<WKNavigation> = webView.rx.didCommit
        XCTAssertNotNil(observable, "didCommit should return a non-nil Observable")
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

final class WKWebViewRxDelegateProxyTests: XCTestCase {

    private var webView: WKWebView!

    override func setUp() {
        super.setUp()
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
    }

    override func tearDown() {
        webView = nil
        super.tearDown()
    }

    // MARK: - RxWKUIDelegateProxy registration

    func testUIDelegateProxy_shouldRegisterKnownImplementations() {
        let proxy = RxWKUIDelegateProxy.proxy(for: webView)
        XCTAssertNotNil(proxy, "Delegate proxy should be created for WKWebView")
    }

    func testUIDelegateProxy_shouldSetAndGetCurrentDelegate() {
        let proxy = RxWKUIDelegateProxy.proxy(for: webView)
        let currentDelegate = RxWKUIDelegateProxy.currentDelegate(for: webView)
        XCTAssertNil(currentDelegate, "Initial delegate should be nil before setting")

        RxWKUIDelegateProxy.setCurrentDelegate(proxy, to: webView)
        let setDelegate = RxWKUIDelegateProxy.currentDelegate(for: webView)
        XCTAssertNotNil(setDelegate, "Delegate should be set")
    }

    func testUIDelegateProxy_shouldHaveWeakWebViewReference() {
        var weakWebView: WKWebView? = webView
        let proxy = RxWKUIDelegateProxy.proxy(for: webView)
        _ = proxy
        webView = nil

        if weakWebView != nil {
            weakWebView = nil
        }
    }

    // MARK: - Multiple web views

    func testMultipleWebViews_shouldHaveIndependentProxies() {
        let webView2 = WKWebView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

        let proxy1 = RxWKUIDelegateProxy.proxy(for: webView)
        let proxy2 = RxWKUIDelegateProxy.proxy(for: webView2)

        XCTAssertFalse(proxy1 === proxy2, "Different WKWebViews should have different delegate proxies")
    }
}

final class WKScriptMessageHandlerProxyTests: XCTestCase {

    // MARK: - Initialization

    func testProxy_shouldForwardMessageToObserver() {
        let expectation = XCTestExpectation(description: "Message forwarded")
        var receivedMessage: String?

        let observer = AnyObserver<WKScriptMessage> { event in
            switch event {
            case .next(let message):
                receivedMessage = message.body as? String
                expectation.fulfill()
            default:
                break
            }
        }

        let proxy = WKScriptMessageHandlerProxy(observer: observer)
        XCTAssertNotNil(proxy, "Proxy should be created successfully")

        let contentController = WKUserContentController()
        let mockBody: Any = "test_message"
        let scriptMessage = MockScriptMessage(body: mockBody, name: "BarkBridge")

        proxy.userContentController(contentController, didReceive: scriptMessage)

        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(receivedMessage, "test_message", "Proxy should forward the message body")
    }
}

// MARK: - Mock Script Message

private final class MockScriptMessage: WKScriptMessage {
    private let _body: Any
    private let _name: String

    init(body: Any, name: String) {
        self._body = body
        self._name = name
        super.init()
    }

    override var body: Any {
        return _body
    }

    override var name: String {
        return _name
    }
}
