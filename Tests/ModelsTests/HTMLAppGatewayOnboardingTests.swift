//
//  HTMLAppGatewayOnboardingTests.swift
//  WebBridgeKitTests
//

import CryptoKit
import XCTest
@testable import WebBridgeKit

final class HTMLAppGatewayOnboardingTests: XCTestCase {
    private final class MemoryStorage: HTMLAppRuntimeStorage {
        var values: [String: Data] = [:]
        func data(forKey key: String) -> Data? { values[key] }
        func set(_ data: Data?, forKey key: String) { values[key] = data }
    }

    private final class Transport: HTMLAppGatewayTransport {
        var responses: [String: Result<(Data, Int), Error>] = [:]
        func get(_ url: URL, completion: @escaping (Result<(Data, Int), Error>) -> Void) {
            completion(responses[url.absoluteString] ?? .success((Data(), 404)))
        }
    }

    private func manifest(signature: HTMLAppManifestSignature? = nil) -> HTMLAppManifest {
        HTMLAppManifest(
            appID: "com.example.gateway-app",
            name: "Gateway App",
            startURL: "https://apps.example.com/index.html",
            allowedOrigins: ["https://apps.example.com"],
            capabilities: [.notification],
            routes: ["/", "/messages/:id"],
            cache: HTMLAppCachePolicy(strategy: .manifest, version: "1", persistent: true),
            signature: signature
        )
    }

    func testValidationDoesNotPersistUntilActivation() throws {
        let storage = MemoryStorage()
        let gatewayRegistry = HTMLAppGatewayRegistry(storage: storage, allowsDevelopmentHTTP: true)
        let trustRegistry = HTMLAppTrustRegistry(storage: storage)
        let transport = Transport()
        let gateway = HTMLAppGatewayConfiguration(
            id: "local",
            name: "Local",
            baseURL: "http://localhost:8080",
            manifestPath: "/manifest"
        )
        transport.responses["http://localhost:8080/health"] = .success((Data(), 200))
        transport.responses["http://localhost:8080/manifest"] = .success((try JSONEncoder().encode(manifest()), 200))
        let service = HTMLAppGatewayOnboardingService(
            gatewayRegistry: gatewayRegistry,
            trustRegistry: trustRegistry,
            permissionLedger: HTMLAppPermissionLedger(storage: storage),
            transport: transport,
            allowsDevelopmentMode: true
        )
        let expectation = expectation(description: "validated")
        var report: HTMLAppGatewayValidationReport?

        service.validate(gateway) { result in
            report = try? result.get()
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)

        XCTAssertNil(gatewayRegistry.activeGateway())
        XCTAssertNil(trustRegistry.manifest(for: manifest().appID))
        let validatedReport = try XCTUnwrap(report)
        try service.activate(validatedReport)
        XCTAssertEqual(gatewayRegistry.activeGateway(), gateway)
        XCTAssertEqual(trustRegistry.manifest(for: manifest().appID), manifest())
    }

    func testFailedHealthCheckDoesNotPersistGateway() {
        let storage = MemoryStorage()
        let registry = HTMLAppGatewayRegistry(storage: storage, allowsDevelopmentHTTP: true)
        let transport = Transport()
        let gateway = HTMLAppGatewayConfiguration(name: "Local", baseURL: "http://localhost:8080")
        transport.responses["http://localhost:8080/health"] = .success((Data(), 503))
        let service = HTMLAppGatewayOnboardingService(
            gatewayRegistry: registry,
            transport: transport,
            allowsDevelopmentMode: true
        )
        let expectation = expectation(description: "rejected")

        service.validate(gateway) { result in
            if case .success = result {
                XCTFail("Unhealthy gateway must be rejected")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
        XCTAssertNil(registry.activeGateway())
    }

    func testProductionValidationVerifiesEd25519ManifestSignature() throws {
        let storage = MemoryStorage()
        let privateKey = Curve25519.Signing.PrivateKey()
        let unsigned = manifest()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let signature = try privateKey.signature(for: encoder.encode(unsigned))
        let signed = manifest(signature: HTMLAppManifestSignature(
            algorithm: "ed25519",
            keyID: "gateway-key",
            value: signature.base64URLEncodedString()
        ))
        let gateway = HTMLAppGatewayConfiguration(
            name: "Production",
            baseURL: "https://gateway.example.com",
            publicKeyID: "gateway-key",
            publicKey: privateKey.publicKey.rawRepresentation.base64URLEncodedString()
        )
        let transport = Transport()
        transport.responses["https://gateway.example.com/health"] = .success((Data(), 200))
        transport.responses["https://gateway.example.com/manifest"] = .success((try encoder.encode(signed), 200))
        let service = HTMLAppGatewayOnboardingService(
            gatewayRegistry: HTMLAppGatewayRegistry(storage: storage),
            trustRegistry: HTMLAppTrustRegistry(storage: storage),
            permissionLedger: HTMLAppPermissionLedger(storage: storage),
            transport: transport
        )
        let expectation = expectation(description: "signature verified")

        service.validate(gateway) { result in
            switch result {
            case .success(let report): XCTAssertEqual(report.manifests, [signed])
            case .failure(let error): XCTFail("Expected valid signature: \(error)")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func testActivationRevokesGrantsWhenGatewayChangesButKeepsTheSameID() throws {
        let storage = MemoryStorage()
        let gatewayRegistry = HTMLAppGatewayRegistry(storage: storage)
        let trustRegistry = HTMLAppTrustRegistry(storage: storage)
        let permissionLedger = HTMLAppPermissionLedger(storage: storage)
        let oldGateway = HTMLAppGatewayConfiguration(
            id: "shared-id",
            name: "Old",
            baseURL: "https://old.example.com"
        )
        try gatewayRegistry.save(oldGateway, activate: true)
        try trustRegistry.register(manifest())
        permissionLedger.grant(
            appID: manifest().appID,
            capability: .notification,
            scope: .always
        )
        let newGateway = HTMLAppGatewayConfiguration(
            id: "shared-id",
            name: "New",
            baseURL: "https://new.example.com"
        )
        let service = HTMLAppGatewayOnboardingService(
            gatewayRegistry: gatewayRegistry,
            trustRegistry: trustRegistry,
            permissionLedger: permissionLedger,
            allowsDevelopmentMode: true
        )

        try service.activate(HTMLAppGatewayValidationReport(
            gateway: newGateway,
            manifests: [manifest()],
            healthStatusCode: 200
        ))

        XCTAssertEqual(gatewayRegistry.activeGateway(), newGateway)
        XCTAssertNil(permissionLedger.grant(for: manifest().appID, capability: .notification))
    }

    func testRemovingActiveGatewayClearsItsTrustAndPermissionGrants() throws {
        let storage = MemoryStorage()
        let gatewayRegistry = HTMLAppGatewayRegistry(storage: storage)
        let trustRegistry = HTMLAppTrustRegistry(storage: storage)
        let permissionLedger = HTMLAppPermissionLedger(storage: storage)
        let gateway = HTMLAppGatewayConfiguration(
            id: "managed",
            name: "Managed",
            baseURL: "https://managed.example.com"
        )
        try gatewayRegistry.save(gateway, activate: true)
        try trustRegistry.register(manifest())
        permissionLedger.grant(
            appID: manifest().appID,
            capability: .notification,
            scope: .always
        )
        let service = HTMLAppGatewayOnboardingService(
            gatewayRegistry: gatewayRegistry,
            trustRegistry: trustRegistry,
            permissionLedger: permissionLedger,
            allowsDevelopmentMode: true
        )

        try service.removeGateway(id: gateway.id)

        XCTAssertNil(gatewayRegistry.activeGateway())
        XCTAssertTrue(gatewayRegistry.allGateways().isEmpty)
        XCTAssertNil(trustRegistry.manifest(for: manifest().appID))
        XCTAssertNil(permissionLedger.grant(for: manifest().appID, capability: .notification))
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
