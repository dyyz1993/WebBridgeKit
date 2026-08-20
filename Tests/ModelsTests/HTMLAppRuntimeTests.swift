//
//  HTMLAppRuntimeTests.swift
//  WebBridgeKitTests
//

import XCTest
@testable import WebBridgeKit

final class HTMLAppRuntimeTests: XCTestCase {

    private final class MemoryStorage: HTMLAppRuntimeStorage {
        private var values: [String: Data] = [:]

        func data(forKey key: String) -> Data? {
            values[key]
        }

        func set(_ data: Data?, forKey key: String) {
            values[key] = data
        }
    }

    private final class NativeAuthorizationProvider: HTMLAppNativeAuthorizationProviding {
        var status: HTMLAppCapabilityResult.Status = .granted
        var promptResult: HTMLAppCapabilityResult.Status = .granted
        private(set) var promptedCapabilities: [HTMLAppCapability] = []

        func authorizationStatus(for capability: HTMLAppCapability) -> HTMLAppCapabilityResult.Status {
            status
        }

        func requestAuthorization(
            for capability: HTMLAppCapability,
            completion: @escaping (HTMLAppCapabilityResult.Status) -> Void
        ) {
            promptedCapabilities.append(capability)
            completion(promptResult)
        }
    }

    private let subject = HTMLAppPermissionSubject(
        gatewayIdentity: "gateway#key-1",
        appID: "com.example.inventory",
        origin: "https://inventory.example.com"
    )

    private func makeManifest(signature: HTMLAppManifestSignature? = nil) -> HTMLAppManifest {
        HTMLAppManifest(
            appID: "com.example.inventory",
            name: "Inventory",
            startURL: "https://inventory.example.com/index.html",
            allowedOrigins: ["https://inventory.example.com"],
            capabilities: [.camera],
            routes: ["/"],
            cache: HTMLAppCachePolicy(strategy: .manifest, version: "1", persistent: true),
            signature: signature
        )
    }

    private func makeRequest(scope: HTMLAppPermissionScope = .always) -> HTMLAppCapabilityRequest {
        HTMLAppCapabilityRequest(
            id: "camera-request-1",
            capability: .camera,
            reason: "Scan a barcode",
            scope: scope
        )
    }

    private func makeGateway(
        storage: HTMLAppRuntimeStorage = MemoryStorage(),
        nativeProvider: NativeAuthorizationProvider = NativeAuthorizationProvider()
    ) throws -> (HTMLAppCapabilityGateway, NativeAuthorizationProvider) {
        let registry = HTMLAppTrustRegistry(storage: MemoryStorage())
        try registry.register(makeManifest())
        let ledger = HTMLAppPermissionLedger(storage: storage)
        let gateway = HTMLAppCapabilityGateway(
            trustRegistry: registry,
            permissionLedger: ledger,
            nativeAuthorizationProvider: nativeProvider
        )
        return (gateway, nativeProvider)
    }

    func testTrustRegistryRequiresVerifiedSignatureForManagedApps() throws {
        let storage = MemoryStorage()
        let registry = HTMLAppTrustRegistry(storage: storage)
        let unsigned = makeManifest()
        let signed = makeManifest(signature: HTMLAppManifestSignature(
            algorithm: "ed25519",
            keyID: "inventory-key",
            value: "approved-signature"
        ))

        XCTAssertThrowsError(try registry.register(unsigned, trustPolicy: .managed { _ in true }))
        try registry.register(signed, trustPolicy: .managed { $0.signature?.value == "approved-signature" })

        XCTAssertEqual(registry.manifest(for: signed.appID), signed)
        XCTAssertEqual(HTMLAppTrustRegistry(storage: storage).manifest(for: signed.appID), signed)
    }

    func testPermissionLedgerPersistsAlwaysAndCanRevoke() {
        let storage = MemoryStorage()
        let ledger = HTMLAppPermissionLedger(storage: storage)

        ledger.grant(subject: subject, capability: .camera, scope: .always)
        XCTAssertEqual(
            HTMLAppPermissionLedger(storage: storage).grant(for: subject, capability: .camera)?.scope,
            .always
        )

        ledger.revoke(subject: subject, capability: .camera)
        XCTAssertNil(ledger.grant(for: subject, capability: .camera))
        XCTAssertNil(HTMLAppPermissionLedger(storage: storage).grant(for: subject, capability: .camera))
    }

    func testBrandedConsentComesFirstAndSystemPromptRunsOnlyAfterAcceptance() throws {
        let nativeProvider = NativeAuthorizationProvider()
        // First-time system state: iOS has not been asked yet.
        nativeProvider.status = .notDetermined
        let (gateway, _) = try makeGateway(nativeProvider: nativeProvider)
        let request = makeRequest()
        let documentURL = URL(string: "https://inventory.example.com/index.html")!

        let firstPass = gateway.requestAuthorization(subject: subject, documentURL: documentURL, request: request)
        XCTAssertEqual(firstPass.status, .notDetermined)
        XCTAssertEqual(firstPass.authorizationLayer, .htmlApp)
        XCTAssertTrue(nativeProvider.promptedCapabilities.isEmpty)

        let consentExpectation = expectation(description: "consent resolves")
        gateway.resolveUserConsent(
            subject: subject,
            documentURL: documentURL,
            request: request,
            approvedScope: .always,
            granted: true
        ) { result in
            defer { consentExpectation.fulfill() }
            XCTAssertEqual(result.status, .granted)
            XCTAssertEqual(result.scope, .always)
        }
        waitForExpectations(timeout: 1)

        // The system layer was only consulted after the panel was accepted.
        XCTAssertEqual(nativeProvider.promptedCapabilities, [.camera])

        let secondPass = gateway.requestAuthorization(subject: subject, documentURL: documentURL, request: request)
        XCTAssertEqual(secondPass.status, .granted)
        XCTAssertEqual(secondPass.scope, .always)
    }

    func testSystemDeniedSkipsBrandedPanelAndRequiresSettings() throws {
        let nativeProvider = NativeAuthorizationProvider()
        nativeProvider.status = .denied
        let (gateway, _) = try makeGateway(nativeProvider: nativeProvider)
        let request = makeRequest()

        let result = gateway.requestAuthorization(
            subject: subject,
            documentURL: URL(string: "https://inventory.example.com/index.html")!,
            request: request
        )

        XCTAssertEqual(result.status, .requiresSettings)
        XCTAssertEqual(result.failureReason, .systemDenied)
        XCTAssertEqual(result.authorizationLayer, .nativeSystem)
        XCTAssertTrue(nativeProvider.promptedCapabilities.isEmpty)
    }

    func testSystemRefusalAfterConsentDoesNotRecordGrant() throws {
        let nativeProvider = NativeAuthorizationProvider()
        nativeProvider.status = .notDetermined
        nativeProvider.promptResult = .denied
        let (gateway, _) = try makeGateway(nativeProvider: nativeProvider)
        let request = makeRequest()
        let documentURL = URL(string: "https://inventory.example.com/index.html")!

        _ = gateway.requestAuthorization(subject: subject, documentURL: documentURL, request: request)

        let refusalExpectation = expectation(description: "consent resolves with system refusal")
        gateway.resolveUserConsent(
            subject: subject,
            documentURL: documentURL,
            request: request,
            approvedScope: .always,
            granted: true
        ) { result in
            defer { refusalExpectation.fulfill() }
            XCTAssertEqual(result.status, .requiresSettings)
            XCTAssertEqual(result.failureReason, .systemDenied)
        }
        waitForExpectations(timeout: 1)

        XCTAssertNil(gateway.permissionLedger.grant(for: subject, capability: .camera))
    }

    func testGatewayRejectsUntrustedOriginAndRevocationRestoresPrompt() throws {
        let (gateway, _) = try makeGateway()
        let request = makeRequest()
        let trustedURL = URL(string: "https://inventory.example.com/index.html")!

        XCTAssertEqual(
            gateway.requestAuthorization(
                subject: subject,
                documentURL: URL(string: "https://attacker.example.com/index.html")!,
                request: request
            ).failureReason,
            .originMismatch
        )

        _ = gateway.requestAuthorization(subject: subject, documentURL: trustedURL, request: request)
        let consentExpectation = expectation(description: "consent granted")
        gateway.resolveUserConsent(
            subject: subject,
            documentURL: trustedURL,
            request: request,
            approvedScope: .always,
            granted: true
        ) { _ in consentExpectation.fulfill() }
        waitForExpectations(timeout: 1)

        gateway.revokeAuthorization(subject: subject, capability: .camera)

        let afterRevoke = gateway.requestAuthorization(subject: subject, documentURL: trustedURL, request: request)
        XCTAssertEqual(afterRevoke.status, .notDetermined)
        XCTAssertEqual(afterRevoke.authorizationLayer, .htmlApp)
    }

    func testUnregisteredAppAndUndeclaredCapabilityHaveStableReasons() throws {
        let (gateway, _) = try makeGateway()
        let unknownSubject = HTMLAppPermissionSubject(
            gatewayIdentity: subject.gatewayIdentity,
            appID: "com.example.missing",
            origin: subject.origin
        )

        let unregistered = gateway.requestAuthorization(
            subject: unknownSubject,
            documentURL: URL(string: "https://inventory.example.com/index.html")!,
            request: makeRequest()
        )
        XCTAssertEqual(unregistered.failureReason, .appNotRegistered)

        let undeclaredRequest = HTMLAppCapabilityRequest(
            id: "location-request",
            capability: .location,
            reason: "Where am I",
            scope: .once
        )
        let undeclared = gateway.requestAuthorization(
            subject: subject,
            documentURL: URL(string: "https://inventory.example.com/index.html")!,
            request: undeclaredRequest
        )
        XCTAssertEqual(undeclared.failureReason, .undeclaredCapability)
    }
}
