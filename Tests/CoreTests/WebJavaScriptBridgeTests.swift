//
//  WebJavaScriptBridgeTests.swift
//  CoreTests
//

import XCTest
@testable import WebBridgeKit

final class WebJavaScriptBridgeTests: XCTestCase {

    private final class MemoryStorage: HTMLAppRuntimeStorage {
        private var values: [String: Data] = [:]
        func data(forKey key: String) -> Data? { values[key] }
        func set(_ data: Data?, forKey key: String) { values[key] = data }
    }

    private final class NativeAuthorizationProvider: HTMLAppNativeAuthorizationProviding {
        var status: HTMLAppCapabilityResult.Status = .granted
        func authorizationStatus(for capability: HTMLAppCapability) -> HTMLAppCapabilityResult.Status { status }
    }

    private final class ConsentPresenter: HTMLAppPermissionConsentPresenting {
        var selectedScope: HTMLAppPermissionScope?
        var requestCount = 0
        var requestedAppIDs: [String] = []
        var pending: [String: (HTMLAppPermissionScope?) -> Void] = [:]
        var completesImmediately = true
        func requestConsent(
            _ request: HTMLAppPermissionConsentRequest,
            completion: @escaping (HTMLAppPermissionScope?) -> Void
        ) {
            requestCount += 1
            requestedAppIDs.append(request.application.id)
            if completesImmediately {
                completion(selectedScope)
            } else {
                pending[request.requestID] = completion
            }
        }

        func cancelConsent(appID: String, requestID: String) {
            pending.removeValue(forKey: requestID)?(nil)
        }
    }

    private final class RevocationAwareHandler: WebNativeAPI, HTMLAppCapabilityRevocationHandling {
        let revoked: XCTestExpectation

        init(revoked: XCTestExpectation) {
            self.revoked = revoked
        }

        func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
            completion(["success": true])
        }

        func htmlAppCapabilityDidRevoke() {
            revoked.fulfill()
        }
    }

    private var bridge: WebJavaScriptBridge!

    override func setUp() {
        super.setUp()
        bridge = WebJavaScriptBridge()
    }

    override func tearDown() {
        bridge = nil
        super.tearDown()
    }

    // MARK: - Initialization

    func testInitializationRegistersHandlerFactories() {
        XCTAssertTrue(bridge.nativeHandlers.isEmpty, "Handlers should be lazy-loaded and empty after initialization")
        XCTAssertNotNil(bridge.getHandler(for: "share"), "Factory should create handler for known action")
    }

    func testGetHandlerReturnsHandlerForRegisteredAction() {
        let handler = bridge.getHandler(for: "share")
        XCTAssertNotNil(handler)
    }

    func testGetHandlerReturnsNilForUnknownAction() {
        let handler = bridge.getHandler(for: "nonexistent_action_xyz")
        XCTAssertNil(handler)
    }

    func testGetHandlerCreatesSameInstanceOnSecondCall() {
        let first = bridge.getHandler(for: "share")
        let second = bridge.getHandler(for: "share")
        XCTAssertTrue((first as AnyObject) === (second as AnyObject), "Lazy loading should return the same instance")
    }

    func testGetHandlerForMultipleActions() {
        XCTAssertNotNil(bridge.getHandler(for: "getLocation"))
        XCTAssertNotNil(bridge.getHandler(for: "getSystemInfo"))
        XCTAssertNotNil(bridge.getHandler(for: "haptic"))
        XCTAssertNotNil(bridge.getHandler(for: "clipboard"))
    }

    func testManagedPWARevocationStopsActiveCapabilityHandler() {
        let ledger = HTMLAppPermissionLedger(storage: MemoryStorage())
        let managedBridge = WebJavaScriptBridge(
            trustRegistry: HTMLAppTrustRegistry(storage: MemoryStorage()),
            permissionLedger: ledger,
            nativeAuthorizationProvider: NativeAuthorizationProvider()
        )
        let appID = "com.example.bridge"
        let origin = "https://bridge.example.com"
        managedBridge.configureManagedHTMLApp(
            appID: appID,
            documentURL: URL(string: "\(origin)/index.html")
        )
        let stopped = expectation(description: "active capability stopped")
        managedBridge.nativeHandlers["bluetooth"] = RevocationAwareHandler(revoked: stopped)
        ledger.grant(appID: appID, origin: origin, capability: .bluetooth, scope: .appSession)

        ledger.revoke(appID: appID, origin: origin, capability: .bluetooth)

        wait(for: [stopped], timeout: 1)
    }

    // MARK: - Send Error to JS

    func testSendErrorToJSDoesNotCrashWithoutWebView() {
        bridge.sendErrorToJS("test error", callbackId: "cb-1")
    }

    func testSendResultToJSWithDictionary() {
        let result: [String: Any] = ["success": true, "data": "test"]
        bridge.sendResultToJS(result, callbackId: "cb-2")
    }

    func testSendResultToJSWithNilCallbackId() {
        let result: [String: Any] = ["success": true]
        bridge.sendResultToJS(result, callbackId: nil)
    }

    // MARK: - Send Event to JS

    func testSendEventToJSDoesNotCrashWithoutWebView() {
        bridge.sendEventToJS(event: "testEvent", data: "testData")
    }

    func testSendEventToJSWithDictionaryData() {
        bridge.sendEventToJS(event: "pageLoaded", data: ["url": "https://example.com"])
    }

    // MARK: - setWebView

    func testSetWebViewDoesNotCrash() {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        bridge.setWebView(webView)
    }

    // MARK: - Callback ID

    func testCurrentCallbackIdInitiallyNil() {
        XCTAssertNil(bridge.currentCallbackId)
    }

    func testProtectedActionIsDeniedForUnmanagedPage() {
        let completed = expectation(description: "bridge completion")
        bridge.handle(body: [
            "action": "clipboard",
            "callbackId": "unmanaged-1",
            "params": ["action": "read"]
        ]) { result, _ in
            let response = result as? [String: Any]
            XCTAssertEqual(response?["success"] as? Bool, false)
            XCTAssertEqual(response?["code"] as? String, "PWA_CAPABILITY_DENIED")
            completed.fulfill()
        }
        wait(for: [completed], timeout: 1)
    }

    func testManagedPWAConsentCanBeCancelledBeforeHandlerRuns() throws {
        let storage = MemoryStorage()
        let registry = HTMLAppTrustRegistry(storage: storage)
        let ledger = HTMLAppPermissionLedger(storage: storage)
        let manifest = HTMLAppManifest(
            appID: "com.example.bridge",
            name: "Bridge Demo",
            startURL: "https://bridge.example.com/index.html",
            allowedOrigins: ["https://bridge.example.com"],
            capabilities: [.clipboard],
            routes: ["/index.html"],
            cache: HTMLAppCachePolicy(strategy: .networkOnly, version: "1", persistent: false)
        )
        try registry.register(manifest)
        let managedBridge = WebJavaScriptBridge(
            trustRegistry: registry,
            permissionLedger: ledger,
            nativeAuthorizationProvider: NativeAuthorizationProvider()
        )
        let presenter = ConsentPresenter()
        managedBridge.permissionConsentPresenter = presenter
        managedBridge.configureManagedHTMLApp(
            appID: manifest.appID,
            documentURL: URL(string: manifest.startURL)
        )

        let completed = expectation(description: "bridge completion")
        managedBridge.handle(body: [
            "action": "clipboard",
            "callbackId": "managed-cancel-1",
            "params": ["action": "read", "reason": "Paste a reference number"]
        ]) { result, _ in
            let response = result as? [String: Any]
            XCTAssertEqual(response?["status"] as? String, "denied")
            XCTAssertEqual(presenter.requestCount, 1)
            XCTAssertTrue(ledger.grants(for: manifest.appID).isEmpty)
            completed.fulfill()
        }
        wait(for: [completed], timeout: 1)
    }

    func testManagedPWAAlwaysGrantPersistsAndSkipsRepeatedConsent() throws {
        let storage = MemoryStorage()
        let registry = HTMLAppTrustRegistry(storage: storage)
        let ledger = HTMLAppPermissionLedger(storage: storage)
        let manifest = HTMLAppManifest(
            appID: "com.example.bridge",
            name: "Bridge Demo",
            startURL: "https://bridge.example.com/index.html",
            allowedOrigins: ["https://bridge.example.com"],
            capabilities: [.clipboard],
            routes: ["/index.html"],
            cache: HTMLAppCachePolicy(strategy: .networkOnly, version: "1", persistent: false)
        )
        try registry.register(manifest)
        let managedBridge = WebJavaScriptBridge(
            trustRegistry: registry,
            permissionLedger: ledger,
            nativeAuthorizationProvider: NativeAuthorizationProvider()
        )
        let presenter = ConsentPresenter()
        presenter.selectedScope = .always
        managedBridge.permissionConsentPresenter = presenter
        managedBridge.configureManagedHTMLApp(
            appID: manifest.appID,
            documentURL: URL(string: manifest.startURL)
        )

        let first = expectation(description: "first bridge completion")
        managedBridge.handle(body: [
            "action": "clipboard",
            "callbackId": "managed-allow-1",
            "params": ["action": "read", "reason": "Paste a reference number"]
        ]) { result, _ in
            XCTAssertEqual((result as? [String: Any])?["success"] as? Bool, true)
            first.fulfill()
        }
        wait(for: [first], timeout: 1)

        let documentURL = try XCTUnwrap(URL(string: manifest.startURL))
        let origin = try XCTUnwrap(HTMLAppOrigin.canonicalOrigin(forDocumentURL: documentURL))
        XCTAssertEqual(ledger.grant(for: manifest.appID, origin: origin, capability: .clipboard)?.scope, .always)

        let second = expectation(description: "second bridge completion")
        managedBridge.handle(body: [
            "action": "clipboard",
            "callbackId": "managed-allow-2",
            "params": ["action": "read"]
        ]) { result, _ in
            XCTAssertEqual((result as? [String: Any])?["success"] as? Bool, true)
            second.fulfill()
        }
        wait(for: [second], timeout: 1)
        XCTAssertEqual(presenter.requestCount, 1)
        XCTAssertEqual(presenter.requestedAppIDs, [manifest.appID])
    }

    func testManagedPWACancelledConsentDoesNotLeaveGatewayRequestReusable() throws {
        let storage = MemoryStorage()
        let registry = HTMLAppTrustRegistry(storage: storage)
        let manifest = try registerClipboardManifest(in: registry)
        let managedBridge = WebJavaScriptBridge(
            trustRegistry: registry,
            permissionLedger: HTMLAppPermissionLedger(storage: storage),
            nativeAuthorizationProvider: NativeAuthorizationProvider()
        )
        let presenter = ConsentPresenter()
        managedBridge.permissionConsentPresenter = presenter
        managedBridge.configureManagedHTMLApp(
            appID: manifest.appID,
            documentURL: URL(string: manifest.startURL)
        )

        let cancelled = expectation(description: "cancelled request")
        managedBridge.handle(body: [
            "action": "clipboard",
            "callbackId": "same-js-callback",
            "params": ["action": "read"]
        ]) { result, _ in
            XCTAssertEqual((result as? [String: Any])?["status"] as? String, "denied")
            cancelled.fulfill()
        }
        wait(for: [cancelled], timeout: 1)

        presenter.selectedScope = .always
        let allowed = expectation(description: "new request allowed")
        managedBridge.handle(body: [
            "action": "clipboard",
            "callbackId": "same-js-callback",
            "params": ["action": "read"]
        ]) { result, _ in
            XCTAssertEqual((result as? [String: Any])?["success"] as? Bool, true)
            allowed.fulfill()
        }
        wait(for: [allowed], timeout: 1)
        XCTAssertEqual(presenter.requestCount, 2)
    }

    func testEndingManagedPWASessionCancelsPendingAuthorizationExactlyOnce() throws {
        let storage = MemoryStorage()
        let registry = HTMLAppTrustRegistry(storage: storage)
        let manifest = try registerClipboardManifest(in: registry)
        let managedBridge = WebJavaScriptBridge(
            trustRegistry: registry,
            permissionLedger: HTMLAppPermissionLedger(storage: storage),
            nativeAuthorizationProvider: NativeAuthorizationProvider()
        )
        let presenter = ConsentPresenter()
        presenter.completesImmediately = false
        managedBridge.permissionConsentPresenter = presenter
        managedBridge.configureManagedHTMLApp(
            appID: manifest.appID,
            documentURL: URL(string: manifest.startURL)
        )

        let completed = expectation(description: "pending request cancelled")
        completed.expectedFulfillmentCount = 1
        var completionCount = 0
        managedBridge.handle(body: [
            "action": "clipboard",
            "callbackId": "pending-1",
            "params": ["action": "read"]
        ]) { result, _ in
            completionCount += 1
            XCTAssertEqual((result as? [String: Any])?["status"] as? String, "denied")
            completed.fulfill()
        }

        XCTAssertEqual(presenter.pending.count, 1)
        let lateCompletion = presenter.pending.values.first
        managedBridge.endManagedHTMLAppSession()
        lateCompletion?(.always)

        wait(for: [completed], timeout: 1)
        XCTAssertEqual(completionCount, 1)
        XCTAssertTrue(presenter.pending.isEmpty)
    }

    func testEndingManagedPWASessionClearsOnlySessionGrantForCurrentOrigin() throws {
        let storage = MemoryStorage()
        let registry = HTMLAppTrustRegistry(storage: storage)
        let manifest = try registerClipboardManifest(in: registry)
        let ledger = HTMLAppPermissionLedger(storage: storage)
        let origin = "https://bridge.example.com"
        ledger.grant(appID: manifest.appID, origin: origin, capability: .clipboard, scope: .appSession)
        ledger.grant(appID: manifest.appID, origin: origin, capability: .camera, scope: .always)
        let managedBridge = WebJavaScriptBridge(
            trustRegistry: registry,
            permissionLedger: ledger,
            nativeAuthorizationProvider: NativeAuthorizationProvider()
        )
        managedBridge.configureManagedHTMLApp(
            appID: manifest.appID,
            documentURL: URL(string: manifest.startURL)
        )

        managedBridge.endManagedHTMLAppSession()

        XCTAssertNil(ledger.grant(
            for: manifest.appID,
            origin: origin,
            capability: .clipboard
        ))
        XCTAssertEqual(ledger.grant(
            for: manifest.appID,
            origin: origin,
            capability: .camera
        )?.scope, .always)
    }

    private func registerClipboardManifest(in registry: HTMLAppTrustRegistry) throws -> HTMLAppManifest {
        let manifest = HTMLAppManifest(
            appID: "com.example.bridge",
            name: "Bridge Demo",
            startURL: "https://bridge.example.com/index.html",
            allowedOrigins: ["https://bridge.example.com"],
            capabilities: [.clipboard, .camera],
            routes: ["/index.html"],
            cache: HTMLAppCachePolicy(strategy: .networkOnly, version: "1", persistent: false)
        )
        try registry.register(manifest)
        return manifest
    }
}

import WebKit
