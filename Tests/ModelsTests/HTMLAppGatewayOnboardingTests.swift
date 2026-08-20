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
        var responses: [String: Result<HTMLAppGatewayTransportResponse, Error>] = [:]
        func get(_ url: URL, completion: @escaping (Result<HTMLAppGatewayTransportResponse, Error>) -> Void) {
            completion(responses[url.absoluteString] ?? .success(.init(data: Data(), statusCode: 404, finalURL: url)))
        }
    }

    private final class FailingStorage: HTMLAppRuntimeStorage, HTMLAppThrowingRuntimeStorage {
        var values: [String: Data] = [:]
        var failNextWriteMatching: String?
        func data(forKey key: String) -> Data? { values[key] }
        func set(_ data: Data?, forKey key: String) { values[key] = data }
        func setThrowing(_ data: Data?, forKey key: String) throws {
            if let match = failNextWriteMatching, key.contains(match) {
                failNextWriteMatching = nil
                throw TestError.persistence
            }
            values[key] = data
        }
    }

    private enum TestError: Error { case persistence }

    private func response(_ data: Data, _ statusCode: Int = 200, finalURL: String) -> HTMLAppGatewayTransportResponse {
        HTMLAppGatewayTransportResponse(data: data, statusCode: statusCode, finalURL: URL(string: finalURL)!)
    }

    private var validHealth: Data { Data(#"{"status":"ok","schemaVersion":"1"}"#.utf8) }

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
        transport.responses["http://localhost:8080/health"] = .success(response(validHealth, finalURL: "http://localhost:8080/health"))
        transport.responses["http://localhost:8080/manifest"] = .success(response(try JSONEncoder().encode(manifest()), finalURL: "http://localhost:8080/manifest"))
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
        XCTAssertEqual(validatedReport.displayName, "Local")
        XCTAssertEqual(validatedReport.host, "localhost")
        XCTAssertEqual(validatedReport.publicKeyID, nil)
        XCTAssertEqual(validatedReport.applicationCount, 1)
        XCTAssertEqual(validatedReport.checks.count, 2)
        try service.activate(validatedReport)
        XCTAssertEqual(gatewayRegistry.activeGateway(), gateway)
        XCTAssertEqual(trustRegistry.manifest(for: manifest().appID), manifest())
    }

    func testFailedHealthCheckDoesNotPersistGateway() {
        let storage = MemoryStorage()
        let registry = HTMLAppGatewayRegistry(storage: storage, allowsDevelopmentHTTP: true)
        let transport = Transport()
        let gateway = HTMLAppGatewayConfiguration(name: "Local", baseURL: "http://localhost:8080")
        transport.responses["http://localhost:8080/health"] = .success(response(Data(), 503, finalURL: "http://localhost:8080/health"))
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
        transport.responses["https://gateway.example.com/health"] = .success(response(validHealth, finalURL: "https://gateway.example.com/health"))
        transport.responses["https://gateway.example.com/manifest"] = .success(response(try encoder.encode(signed), finalURL: "https://gateway.example.com/manifest"))
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

    func testMalformedHealthAndCrossOriginRedirectAreRejectedWithoutSideEffects() {
        let storage = MemoryStorage()
        let registry = HTMLAppGatewayRegistry(storage: storage)
        let transport = Transport()
        let gateway = HTMLAppGatewayConfiguration(
            name: "Production",
            baseURL: "https://gateway.example.com",
            publicKeyID: "gateway-key",
            publicKey: Data(repeating: 1, count: 32).base64EncodedString()
        )
        let service = HTMLAppGatewayOnboardingService(gatewayRegistry: registry, transport: transport)

        transport.responses["https://gateway.example.com/health"] = .success(response(Data("not-json".utf8), finalURL: "https://gateway.example.com/health"))
        let malformed = expectation(description: "malformed")
        service.validate(gateway) { result in
            guard case .failure(let error) = result else {
                XCTFail("Malformed health response must fail")
                malformed.fulfill()
                return
            }
            XCTAssertEqual(error as? HTMLAppGatewayOnboardingError, .malformedHealthResponse)
            malformed.fulfill()
        }
        wait(for: [malformed], timeout: 1)

        transport.responses["https://gateway.example.com/health"] = .success(response(validHealth, finalURL: "https://attacker.example.com/health"))
        let redirected = expectation(description: "redirected")
        service.validate(gateway) { result in
            guard case .failure(let error) = result else {
                XCTFail("Cross-origin redirect must fail")
                redirected.fulfill()
                return
            }
            XCTAssertEqual(error as? HTMLAppGatewayOnboardingError, .crossOriginRedirect)
            redirected.fulfill()
        }
        wait(for: [redirected], timeout: 1)
        XCTAssertNil(registry.activeGateway())
    }

    func testActivationRollsBackGatewayManifestsAndPermissionsWhenPersistenceFails() throws {
        let storage = FailingStorage()
        let gatewayRegistry = HTMLAppGatewayRegistry(storage: storage)
        let trustRegistry = HTMLAppTrustRegistry(storage: storage)
        let permissionLedger = HTMLAppPermissionLedger(storage: storage)
        let oldGateway = HTMLAppGatewayConfiguration(id: "old", name: "Old", baseURL: "https://old.example.com")
        try gatewayRegistry.save(oldGateway, activate: true)
        try trustRegistry.register(manifest())
        permissionLedger.grant(appID: manifest().appID, origin: manifest().allowedOrigins[0], capability: .notification, scope: .always)
        let oldManifests = trustRegistry.registeredManifests()
        storage.failNextWriteMatching = "gateways"
        let newGateway = HTMLAppGatewayConfiguration(id: "new", name: "New", baseURL: "https://new.example.com")
        let service = HTMLAppGatewayOnboardingService(
            gatewayRegistry: gatewayRegistry,
            trustRegistry: trustRegistry,
            permissionLedger: permissionLedger,
            allowsDevelopmentMode: true
        )

        XCTAssertThrowsError(try service.activate(.init(gateway: newGateway, manifests: [manifest()], healthStatusCode: 200)))
        XCTAssertEqual(gatewayRegistry.activeGateway(), oldGateway)
        XCTAssertEqual(trustRegistry.registeredManifests(), oldManifests)
        XCTAssertNotNil(permissionLedger.grant(for: manifest().appID, origin: manifest().allowedOrigins[0], capability: .notification))
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
            origin: manifest().allowedOrigins[0],
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
        XCTAssertNil(permissionLedger.grant(for: manifest().appID, origin: manifest().allowedOrigins[0], capability: .notification))
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
            origin: manifest().allowedOrigins[0],
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
        XCTAssertNil(permissionLedger.grant(for: manifest().appID, origin: manifest().allowedOrigins[0], capability: .notification))
    }

    func testRemovingActiveGatewayRollsBackWhenGatewayPersistenceFails() throws {
        let storage = FailingStorage()
        let gatewayRegistry = HTMLAppGatewayRegistry(storage: storage)
        let trustRegistry = HTMLAppTrustRegistry(storage: storage)
        let permissionLedger = HTMLAppPermissionLedger(storage: storage)
        let gateway = HTMLAppGatewayConfiguration(id: "managed", name: "Managed", baseURL: "https://managed.example.com")
        try gatewayRegistry.save(gateway, activate: true)
        try trustRegistry.register(manifest())
        permissionLedger.grant(appID: manifest().appID, origin: manifest().allowedOrigins[0], capability: .notification, scope: .always)
        storage.failNextWriteMatching = "gateways"
        let service = HTMLAppGatewayOnboardingService(
            gatewayRegistry: gatewayRegistry,
            trustRegistry: trustRegistry,
            permissionLedger: permissionLedger,
            allowsDevelopmentMode: true
        )

        XCTAssertThrowsError(try service.removeGateway(id: gateway.id))
        XCTAssertEqual(gatewayRegistry.activeGateway(), gateway)
        XCTAssertEqual(trustRegistry.registeredManifests(), [manifest()])
        XCTAssertNotNil(permissionLedger.grant(for: manifest().appID, origin: manifest().allowedOrigins[0], capability: .notification))
    }

    func testActivationRemovesGrantWhenManifestNoLongerDeclaresCapability() throws {
        let storage = MemoryStorage()
        let gatewayRegistry = HTMLAppGatewayRegistry(storage: storage)
        let trustRegistry = HTMLAppTrustRegistry(storage: storage)
        let permissionLedger = HTMLAppPermissionLedger(storage: storage)
        let gateway = HTMLAppGatewayConfiguration(id: "managed", name: "Managed", baseURL: "https://managed.example.com")
        try gatewayRegistry.save(gateway, activate: true)
        try trustRegistry.register(manifest())
        permissionLedger.grant(
            appID: manifest().appID,
            origin: manifest().allowedOrigins[0],
            capability: .notification,
            scope: .always
        )
        let updatedManifest = HTMLAppManifest(
            appID: manifest().appID,
            name: manifest().name,
            startURL: manifest().startURL,
            allowedOrigins: manifest().allowedOrigins,
            capabilities: [],
            routes: manifest().routes,
            cache: manifest().cache
        )
        let service = HTMLAppGatewayOnboardingService(
            gatewayRegistry: gatewayRegistry,
            trustRegistry: trustRegistry,
            permissionLedger: permissionLedger,
            allowsDevelopmentMode: true
        )

        try service.activate(.init(gateway: gateway, manifests: [updatedManifest], healthStatusCode: 200))

        XCTAssertNil(permissionLedger.grant(
            for: manifest().appID,
            origin: manifest().allowedOrigins[0],
            capability: .notification
        ))
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
