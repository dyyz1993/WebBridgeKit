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

        func authorizationStatus(for capability: HTMLAppCapability) -> HTMLAppCapabilityResult.Status {
            status
        }
    }

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
        let appID = "com.example.inventory"
        let origin = "https://inventory.example.com"

        ledger.grant(appID: appID, origin: origin, capability: .camera, scope: .always)
        XCTAssertEqual(
            HTMLAppPermissionLedger(storage: storage)
                .grant(for: appID, origin: origin, capability: .camera)?.scope,
            .always
        )

        ledger.revoke(appID: appID, origin: origin, capability: .camera)
        XCTAssertNil(ledger.grant(for: appID, origin: origin, capability: .camera))
        XCTAssertNil(HTMLAppPermissionLedger(storage: storage).grant(for: appID, origin: origin, capability: .camera))
    }

    func testPermissionLedgerPublishesRevocationForActiveCapability() throws {
        let ledger = HTMLAppPermissionLedger(storage: MemoryStorage())
        let appID = "com.example.inventory"
        let origin = "https://inventory.example.com"
        ledger.grant(appID: appID, origin: origin, capability: .bluetooth, scope: .appSession)
        let revoked = expectation(description: "permission revocation published")
        var received: HTMLAppPermissionRevocation?
        let observer = NotificationCenter.default.addObserver(
            forName: .htmlAppPermissionDidRevoke,
            object: ledger,
            queue: nil
        ) { notification in
            received = notification.userInfo?[HTMLAppPermissionRevocationNotification.payloadKey]
                as? HTMLAppPermissionRevocation
            revoked.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        ledger.revoke(appID: appID, origin: origin, capability: .bluetooth)

        wait(for: [revoked], timeout: 1)
        XCTAssertEqual(received, HTMLAppPermissionRevocation(
            appID: appID,
            origin: origin,
            capability: .bluetooth
        ))
    }

    func testPermissionLedgerDoesNotReuseGrantAcrossOrigins() {
        let ledger = HTMLAppPermissionLedger(storage: MemoryStorage())
        ledger.grant(
            appID: "com.example.inventory",
            origin: "https://inventory.example.com",
            capability: .camera,
            scope: .always
        )

        XCTAssertNil(ledger.grant(
            for: "com.example.inventory",
            origin: "https://admin.inventory.example.com",
            capability: .camera
        ))
    }

    func testPermissionLedgerKeepsSessionGrantOnlyInCurrentLedger() {
        let storage = MemoryStorage()
        let ledger = HTMLAppPermissionLedger(storage: storage)
        let appID = "com.example.inventory"
        let origin = "https://inventory.example.com"

        ledger.grant(
            appID: appID,
            origin: origin,
            capability: .camera,
            scope: .appSession
        )

        XCTAssertEqual(
            ledger.grant(for: appID, origin: origin, capability: .camera)?.scope,
            .appSession
        )
        XCTAssertNil(
            HTMLAppPermissionLedger(storage: storage)
                .grant(for: appID, origin: origin, capability: .camera)
        )
    }

    func testPermissionLedgerEndsOnlyMatchingAppSessionContext() {
        let ledger = HTMLAppPermissionLedger(storage: MemoryStorage())
        let appID = "com.example.inventory"
        let origin = "https://inventory.example.com"
        let otherOrigin = "https://admin.inventory.example.com"
        ledger.grant(appID: appID, origin: origin, capability: .camera, scope: .appSession)
        ledger.grant(appID: appID, origin: origin, capability: .microphone, scope: .always)
        ledger.grant(appID: appID, origin: otherOrigin, capability: .camera, scope: .appSession)
        ledger.grant(appID: "com.example.other", origin: origin, capability: .camera, scope: .appSession)

        ledger.revokeSessionGrants(appID: appID, origin: origin)

        XCTAssertNil(ledger.grant(for: appID, origin: origin, capability: .camera))
        XCTAssertEqual(ledger.grant(for: appID, origin: origin, capability: .microphone)?.scope, .always)
        XCTAssertEqual(ledger.grant(for: appID, origin: otherOrigin, capability: .camera)?.scope, .appSession)
        XCTAssertEqual(ledger.grant(
            for: "com.example.other",
            origin: origin,
            capability: .camera
        )?.scope, .appSession)
    }

    func testOnceConsentAuthorizesOnlyCurrentCapabilityRequest() throws {
        let registry = HTMLAppTrustRegistry(storage: MemoryStorage())
        let manifest = makeManifest()
        try registry.register(manifest)
        let ledger = HTMLAppPermissionLedger(storage: MemoryStorage())
        let gateway = HTMLAppCapabilityGateway(
            trustRegistry: registry,
            permissionLedger: ledger,
            nativeAuthorizationProvider: NativeAuthorizationProvider()
        )
        let request = makeRequest(scope: .once)
        let documentURL = URL(string: manifest.startURL)!

        XCTAssertEqual(
            gateway.requestAuthorization(appID: manifest.appID, documentURL: documentURL, request: request).status,
            .notDetermined
        )
        XCTAssertEqual(
            gateway.resolveUserConsent(
                appID: manifest.appID,
                documentURL: documentURL,
                request: request,
                granted: true
            ).status,
            .granted
        )
        XCTAssertNil(ledger.grant(
            for: manifest.appID,
            origin: "https://inventory.example.com",
            capability: .camera
        ))
        XCTAssertEqual(
            gateway.requestAuthorization(appID: manifest.appID, documentURL: documentURL, request: request).status,
            .notDetermined
        )
    }

    func testGatewayRequiresNativeThenHTMLAuthorizationAndPersistsUserChoice() throws {
        let storage = MemoryStorage()
        let registry = HTMLAppTrustRegistry(storage: storage)
        let manifest = makeManifest()
        try registry.register(manifest)
        let ledger = HTMLAppPermissionLedger(storage: storage)
        let nativeProvider = NativeAuthorizationProvider()
        let gateway = HTMLAppCapabilityGateway(
            trustRegistry: registry,
            permissionLedger: ledger,
            nativeAuthorizationProvider: nativeProvider
        )
        let request = makeRequest()
        let documentURL = URL(string: manifest.startURL)!

        XCTAssertEqual(
            gateway.requestAuthorization(appID: manifest.appID, documentURL: documentURL, request: request),
            HTMLAppCapabilityResult(
                id: request.id,
                capability: .camera,
                status: .notDetermined,
                authorizationLayer: .htmlApp
            )
        )

        XCTAssertEqual(
            gateway.resolveUserConsent(appID: manifest.appID, documentURL: documentURL, request: request, granted: true),
            HTMLAppCapabilityResult(id: request.id, capability: .camera, status: .granted, scope: .always)
        )
        XCTAssertEqual(
            gateway.requestAuthorization(appID: manifest.appID, documentURL: documentURL, request: request),
            HTMLAppCapabilityResult(id: request.id, capability: .camera, status: .granted, scope: .always)
        )
    }

    func testGatewayPresentsHTMLAppConsentBeforeSystemAuthorization() throws {
        let registry = HTMLAppTrustRegistry(storage: MemoryStorage())
        let manifest = makeManifest()
        try registry.register(manifest)
        let nativeProvider = NativeAuthorizationProvider()
        nativeProvider.status = .notDetermined
        let gateway = HTMLAppCapabilityGateway(
            trustRegistry: registry,
            permissionLedger: HTMLAppPermissionLedger(storage: MemoryStorage()),
            nativeAuthorizationProvider: nativeProvider
        )
        let request = makeRequest()

        XCTAssertEqual(
            gateway.requestAuthorization(
                appID: manifest.appID,
                documentURL: URL(string: manifest.startURL)!,
                request: request
            ),
            HTMLAppCapabilityResult(
                id: request.id,
                capability: .camera,
                status: .notDetermined,
                authorizationLayer: .htmlApp
            )
        )
    }

    func testGatewayRejectsUntrustedOriginAndRevocationRestoresPrompt() throws {
        let registry = HTMLAppTrustRegistry(storage: MemoryStorage())
        let manifest = makeManifest()
        try registry.register(manifest)
        let ledger = HTMLAppPermissionLedger(storage: MemoryStorage())
        let gateway = HTMLAppCapabilityGateway(
            trustRegistry: registry,
            permissionLedger: ledger,
            nativeAuthorizationProvider: NativeAuthorizationProvider()
        )
        let request = makeRequest()
        let trustedURL = URL(string: manifest.startURL)!

        XCTAssertEqual(
            gateway.requestAuthorization(
                appID: manifest.appID,
                documentURL: URL(string: "https://attacker.example.com/index.html")!,
                request: request
            ).status,
            .denied
        )

        _ = gateway.requestAuthorization(appID: manifest.appID, documentURL: trustedURL, request: request)
        _ = gateway.resolveUserConsent(appID: manifest.appID, documentURL: trustedURL, request: request, granted: true)
        gateway.revokeAuthorization(
            appID: manifest.appID,
            documentURL: trustedURL,
            capability: .camera
        )

        XCTAssertEqual(
            gateway.requestAuthorization(appID: manifest.appID, documentURL: trustedURL, request: request),
            HTMLAppCapabilityResult(
                id: request.id,
                capability: .camera,
                status: .notDetermined,
                authorizationLayer: .htmlApp
            )
        )
    }

    func testGatewayCancellationConsumesOnlyTheMatchingPendingRequest() throws {
        let registry = HTMLAppTrustRegistry(storage: MemoryStorage())
        let manifest = makeManifest()
        try registry.register(manifest)
        let gateway = HTMLAppCapabilityGateway(
            trustRegistry: registry,
            permissionLedger: HTMLAppPermissionLedger(storage: MemoryStorage()),
            nativeAuthorizationProvider: NativeAuthorizationProvider()
        )
        let request = makeRequest(scope: .always)
        let documentURL = try XCTUnwrap(URL(string: manifest.startURL))

        XCTAssertEqual(
            gateway.requestAuthorization(appID: manifest.appID, documentURL: documentURL, request: request).status,
            .notDetermined
        )
        XCTAssertTrue(gateway.cancelAuthorization(appID: manifest.appID, requestID: request.id))
        XCTAssertFalse(gateway.cancelAuthorization(appID: manifest.appID, requestID: request.id))
        XCTAssertEqual(
            gateway.resolveUserConsent(
                appID: manifest.appID,
                documentURL: documentURL,
                request: request,
                granted: true
            ).status,
            .denied
        )
    }

    func testBridgeCapabilityPolicyMapsProtectedActionsAndDynamicFileOperations() {
        XCTAssertEqual(HTMLAppBridgeCapabilityPolicy.capability(for: "camera", body: [:]), .camera)
        XCTAssertEqual(HTMLAppBridgeCapabilityPolicy.capability(for: "scan", body: [:]), .scan)
        XCTAssertEqual(HTMLAppBridgeCapabilityPolicy.capability(
            for: "file",
            body: [:]
        ), .fileImport)
        XCTAssertEqual(HTMLAppBridgeCapabilityPolicy.capability(
            for: "media",
            body: ["params": ["action": "saveFile"]]
        ), .fileExport)
        XCTAssertEqual(HTMLAppBridgeCapabilityPolicy.capability(
            for: "systemExtra",
            body: ["params": ["action": "authenticate"]]
        ), .biometrics)
        XCTAssertEqual(HTMLAppBridgeCapabilityPolicy.capability(for: "sensors", body: [:]), .motion)
        XCTAssertEqual(HTMLAppBridgeCapabilityPolicy.capability(for: "screen", body: [:]), .deviceControl)
        XCTAssertNil(HTMLAppBridgeCapabilityPolicy.capability(for: "getSystemInfo", body: [:]))
    }
}
