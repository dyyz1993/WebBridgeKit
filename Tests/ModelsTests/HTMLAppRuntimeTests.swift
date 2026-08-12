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

        ledger.grant(appID: appID, capability: .camera, scope: .always)
        XCTAssertEqual(HTMLAppPermissionLedger(storage: storage).grant(for: appID, capability: .camera)?.scope, .always)

        ledger.revoke(appID: appID, capability: .camera)
        XCTAssertNil(ledger.grant(for: appID, capability: .camera))
        XCTAssertNil(HTMLAppPermissionLedger(storage: storage).grant(for: appID, capability: .camera))
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

    func testGatewayStopsAtNativeAuthorizationBeforePresentingHTMLConsent() throws {
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
                authorizationLayer: .nativeSystem
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
        gateway.revokeAuthorization(appID: manifest.appID, capability: .camera)

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
}
