//
//  HTMLAppPermissionCoordinatorTests.swift
//  WebBridgeKitTests
//
//  Prompt serialization rules: one panel at a time, duplicate requests merge,
//  callbacks fire exactly once, cancellation resolves safely.
//

import XCTest
@testable import WebBridgeKit

final class HTMLAppPermissionCoordinatorTests: XCTestCase {

    private final class MemoryStorage: HTMLAppRuntimeStorage {
        private var values: [String: Data] = [:]
        func data(forKey key: String) -> Data? { values[key] }
        func set(_ data: Data?, forKey key: String) { values[key] = data }
    }

    private final class NativeProvider: HTMLAppNativeAuthorizationProviding {
        var status: HTMLAppCapabilityResult.Status = .granted
        var promptResult: HTMLAppCapabilityResult.Status = .granted
        func authorizationStatus(for capability: HTMLAppCapability) -> HTMLAppCapabilityResult.Status { status }
        func requestAuthorization(
            for capability: HTMLAppCapability,
            completion: @escaping (HTMLAppCapabilityResult.Status) -> Void
        ) {
            completion(promptResult)
        }
    }

    private final class SpyPresenter: HTMLAppPermissionPromptPresenting {
        var presentCallCount = 0
        var dismissCallCount = 0
        var failPresentation = false
        var contexts: [HTMLAppPermissionPromptContext] = []
        var activeCompletions: [(HTMLAppPermissionPromptOutcome) -> Void] = []

        @discardableResult
        func presentPrompt(
            for context: HTMLAppPermissionPromptContext,
            completion: @escaping (HTMLAppPermissionPromptOutcome) -> Void
        ) -> Bool {
            guard !failPresentation else {
                completion(.cancelled)
                return false
            }
            presentCallCount += 1
            contexts.append(context)
            activeCompletions.append(completion)
            return true
        }

        func dismissActivePrompt() {
            dismissCallCount += 1
            guard let completion = activeCompletions.first else { return }
            activeCompletions.removeFirst()
            completion(.cancelled)
        }

        /// Simulates the user tapping a scope option on the visible panel.
        func resolveActive(_ outcome: HTMLAppPermissionPromptOutcome) {
            guard let completion = activeCompletions.first else { return }
            activeCompletions.removeFirst()
            completion(outcome)
        }
    }

    private let subject = HTMLAppPermissionSubject(
        gatewayIdentity: "gateway#key-1",
        appID: "com.example.inventory",
        origin: "https://inventory.example.com"
    )

    private func makeManifest(capabilities: [HTMLAppCapability] = [.bluetooth, .camera]) -> HTMLAppManifest {
        HTMLAppManifest(
            appID: "com.example.inventory",
            name: "Inventory",
            startURL: "https://inventory.example.com/index.html",
            allowedOrigins: ["https://inventory.example.com"],
            capabilities: capabilities,
            routes: ["/"],
            cache: HTMLAppCachePolicy(strategy: .manifest, version: "1", persistent: true)
        )
    }

    private func makeCoordinator(
        presenter: SpyPresenter,
        native: NativeProvider = NativeProvider()
    ) throws -> (coordinator: HTMLAppPermissionCoordinator, gateway: HTMLAppCapabilityGateway) {
        let registry = HTMLAppTrustRegistry(storage: MemoryStorage())
        try registry.register(makeManifest())
        let gateway = HTMLAppCapabilityGateway(
            trustRegistry: registry,
            permissionLedger: HTMLAppPermissionLedger(storage: MemoryStorage()),
            nativeAuthorizationProvider: native
        )
        let coordinator = HTMLAppPermissionCoordinator(gateway: gateway, presenter: presenter)
        return (coordinator, gateway)
    }

    private func makeRequest(
        id: String = "req-1",
        capability: HTMLAppCapability = .bluetooth,
        scope: HTMLAppPermissionScope = .appSession
    ) -> HTMLAppCapabilityRequest {
        HTMLAppCapabilityRequest(id: id, capability: capability, reason: "Scan tags", scope: scope)
    }

    /// Runs previously enqueued main-queue blocks so presentation counts are
    /// deterministic in tests.
    private func drainMainQueue() {
        let drained = expectation(description: "main queue drained")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 1)
    }

    func testExistingAlwaysGrantResolvesWithoutPanel() throws {
        let presenter = SpyPresenter()
        let (coordinator, gateway) = try makeCoordinator(presenter: presenter)
        gateway.permissionLedger.grant(subject: subject, capability: .camera, scope: .always)
        let granted = expectation(description: "granted without panel")
        let documentURL = URL(string: "https://inventory.example.com/index.html")!

        coordinator.authorize(
            subject: subject,
            documentURL: documentURL,
            request: makeRequest(capability: .camera),
            appName: "Inventory"
        ) { result in
            XCTAssertEqual(result.status, .granted)
            XCTAssertEqual(result.scope, .always)
            granted.fulfill()
        }
        wait(for: [granted], timeout: 1)

        XCTAssertEqual(presenter.presentCallCount, 0)
    }

    func testDuplicateRequestsMergeIntoSinglePanel() throws {
        let presenter = SpyPresenter()
        let (coordinator, _) = try makeCoordinator(presenter: presenter)
        let documentURL = URL(string: "https://inventory.example.com/index.html")!
        let first = expectation(description: "first completion")
        let second = expectation(description: "second completion")

        coordinator.authorize(
            subject: subject,
            documentURL: documentURL,
            request: makeRequest(id: "req-a"),
            appName: "Inventory"
        ) { result in
            XCTAssertEqual(result.status, .granted)
            XCTAssertEqual(result.scope, .always)
            first.fulfill()
        }
        coordinator.authorize(
            subject: subject,
            documentURL: documentURL,
            request: makeRequest(id: "req-b"),
            appName: "Inventory"
        ) { result in
            XCTAssertEqual(result.status, .granted)
            second.fulfill()
        }
        drainMainQueue()

        XCTAssertEqual(presenter.presentCallCount, 1)
        XCTAssertEqual(presenter.contexts.first?.appName, "Inventory")
        XCTAssertEqual(presenter.contexts.first?.origin, subject.origin)
        XCTAssertEqual(presenter.contexts.first?.capability, .bluetooth)

        presenter.resolveActive(.authorized(scope: .always))
        wait(for: [first, second], timeout: 1)
    }

    func testSecondCapabilityQueuesUntilFirstPanelResolves() throws {
        let presenter = SpyPresenter()
        let (coordinator, _) = try makeCoordinator(presenter: presenter)
        let documentURL = URL(string: "https://inventory.example.com/index.html")!
        let bluetoothDone = expectation(description: "bluetooth resolves")
        let cameraDone = expectation(description: "camera resolves")

        coordinator.authorize(
            subject: subject,
            documentURL: documentURL,
            request: makeRequest(id: "bt", capability: .bluetooth),
            appName: "Inventory"
        ) { _ in bluetoothDone.fulfill() }
        coordinator.authorize(
            subject: subject,
            documentURL: documentURL,
            request: makeRequest(id: "cam", capability: .camera),
            appName: "Inventory"
        ) { _ in cameraDone.fulfill() }
        drainMainQueue()

        XCTAssertEqual(presenter.presentCallCount, 1)

        presenter.resolveActive(.authorized(scope: .once))
        wait(for: [bluetoothDone], timeout: 1)
        drainMainQueue()

        // The queued camera panel appears only after the bluetooth one closed.
        XCTAssertEqual(presenter.presentCallCount, 2)
        presenter.resolveActive(.authorized(scope: .appSession))
        wait(for: [cameraDone], timeout: 1)
    }

    func testCancellingSubjectDismissesActivePanelAndCompletesDenied() throws {
        let presenter = SpyPresenter()
        let (coordinator, _) = try makeCoordinator(presenter: presenter)
        let documentURL = URL(string: "https://inventory.example.com/index.html")!
        let denied = expectation(description: "cancelled completion")

        coordinator.authorize(
            subject: subject,
            documentURL: documentURL,
            request: makeRequest(),
            appName: "Inventory"
        ) { result in
            XCTAssertEqual(result.status, .denied)
            XCTAssertEqual(result.failureReason, .userCancelled)
            denied.fulfill()
        }
        drainMainQueue()
        XCTAssertEqual(presenter.presentCallCount, 1)

        coordinator.cancelPendingRequests(subject: subject)

        XCTAssertEqual(presenter.dismissCallCount, 1)
        wait(for: [denied], timeout: 1)
    }

    func testCancellingBeforePresentationStillResolvesOnce() throws {
        let presenter = SpyPresenter()
        let (coordinator, _) = try makeCoordinator(presenter: presenter)
        let documentURL = URL(string: "https://inventory.example.com/index.html")!
        let denied = expectation(description: "cancelled before presentation")

        coordinator.authorize(
            subject: subject,
            documentURL: documentURL,
            request: makeRequest(),
            appName: "Inventory"
        ) { result in
            XCTAssertEqual(result.failureReason, .userCancelled)
            denied.fulfill()
        }

        // Cancel before the queued main-queue presentation ran.
        coordinator.cancelPendingRequests(subject: subject)
        wait(for: [denied], timeout: 1)
        drainMainQueue()

        XCTAssertEqual(presenter.presentCallCount, 0)
    }

    func testCancellingSubjectResolvesQueuedGroupsToo() throws {
        let presenter = SpyPresenter()
        let (coordinator, _) = try makeCoordinator(presenter: presenter)
        let documentURL = URL(string: "https://inventory.example.com/index.html")!
        let bluetoothDenied = expectation(description: "bluetooth cancelled")
        let cameraDenied = expectation(description: "camera cancelled")

        coordinator.authorize(
            subject: subject,
            documentURL: documentURL,
            request: makeRequest(id: "bt", capability: .bluetooth),
            appName: "Inventory"
        ) { result in
            XCTAssertEqual(result.failureReason, .userCancelled)
            bluetoothDenied.fulfill()
        }
        coordinator.authorize(
            subject: subject,
            documentURL: documentURL,
            request: makeRequest(id: "cam", capability: .camera),
            appName: "Inventory"
        ) { result in
            XCTAssertEqual(result.failureReason, .userCancelled)
            cameraDenied.fulfill()
        }
        drainMainQueue()

        coordinator.cancelPendingRequests(subject: subject)

        wait(for: [bluetoothDenied, cameraDenied], timeout: 1)
        XCTAssertEqual(presenter.dismissCallCount, 1)
        // The queued camera panel is never presented.
        XCTAssertEqual(presenter.presentCallCount, 1)
    }

    func testDuplicateOutcomeDeliveryCompletesOnlyOnce() throws {
        let presenter = SpyPresenter()
        let (coordinator, _) = try makeCoordinator(presenter: presenter)
        let documentURL = URL(string: "https://inventory.example.com/index.html")!
        var resultCount = 0
        let first = expectation(description: "first completion")

        coordinator.authorize(
            subject: subject,
            documentURL: documentURL,
            request: makeRequest(),
            appName: "Inventory"
        ) { _ in
            resultCount += 1
            if resultCount == 1 { first.fulfill() }
        }
        drainMainQueue()

        // Deliver the panel outcome twice, as a buggy presenter might.
        let outcomeDelivery = presenter.activeCompletions[0]
        outcomeDelivery(.authorized(scope: .once))
        wait(for: [first], timeout: 1)
        outcomeDelivery(.authorized(scope: .always))

        XCTAssertEqual(resultCount, 1)
    }

    func testPresenterFailureResolvesAsCancelled() throws {
        let presenter = SpyPresenter()
        presenter.failPresentation = true
        let (coordinator, _) = try makeCoordinator(presenter: presenter)
        let documentURL = URL(string: "https://inventory.example.com/index.html")!
        let cancelled = expectation(description: "cancelled")

        coordinator.authorize(
            subject: subject,
            documentURL: documentURL,
            request: makeRequest(),
            appName: "Inventory"
        ) { result in
            XCTAssertEqual(result.status, .denied)
            XCTAssertEqual(result.failureReason, .userCancelled)
            cancelled.fulfill()
        }
        drainMainQueue()

        wait(for: [cancelled], timeout: 1)
    }
}
