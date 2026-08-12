//
//  HTMLAppGatewayConfigurationTests.swift
//  WebBridgeKitTests
//

import XCTest
@testable import WebBridgeKit

final class HTMLAppGatewayConfigurationTests: XCTestCase {

    private final class MemoryStorage: HTMLAppRuntimeStorage {
        private var values: [String: Data] = [:]

        func data(forKey key: String) -> Data? {
            values[key]
        }

        func set(_ data: Data?, forKey key: String) {
            values[key] = data
        }
    }

    func testImportsGatewayFromJSONPayload() throws {
        let payload = """
        {
          "id": "inventory",
          "name": "Inventory Gateway",
          "baseURL": "https://gateway.example.com",
          "manifestPath": "/api/v1/manifest",
          "publicKeyID": "gateway-key-1",
          "publicKey": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
        }
        """

        let gateway = try HTMLAppGatewayConfiguration.importPayload(payload)

        XCTAssertEqual(gateway.id, "inventory")
        XCTAssertEqual(gateway.manifestURL?.absoluteString, "https://gateway.example.com/api/v1/manifest")
        XCTAssertEqual(gateway.publicKeyID, "gateway-key-1")
    }

    func testImportsGatewayFromScannedURLAndRejectsDuplicateParameters() throws {
        let payload = "webbridgekit://gateway?name=Inventory%20Gateway&url=https%3A%2F%2Fgateway.example.com&manifestPath=%2Fmanifest"
        let gateway = try HTMLAppGatewayConfiguration.importPayload(payload)

        XCTAssertEqual(gateway.name, "Inventory Gateway")
        XCTAssertEqual(gateway.baseURL, "https://gateway.example.com")
        XCTAssertThrowsError(try HTMLAppGatewayConfiguration.importPayload(
            "webbridgekit://gateway?name=One&name=Two&url=https%3A%2F%2Fgateway.example.com"
        ))
    }

    func testOfficialGatewayIsProductionValidAndContainsNoSecret() {
        let gateway = HTMLAppGatewayDefaults.official

        XCTAssertTrue(gateway.validate().isValid)
        XCTAssertEqual(gateway.baseURL, "https://cloak.xbrowser.dev:5801")
        XCTAssertEqual(gateway.healthPath, "/health")
        XCTAssertEqual(gateway.manifestPath, "/api/v1/html-apps")
        XCTAssertNotNil(gateway.publicKeyID)
        XCTAssertNotNil(gateway.publicKey)
    }

    func testRejectsInsecureAndAllowsOnlyExplicitDevelopmentLocalhost() {
        let insecure = HTMLAppGatewayConfiguration(
            name: "Insecure",
            baseURL: "http://gateway.example.com"
        )
        let localhost = HTMLAppGatewayConfiguration(
            name: "Local",
            baseURL: "http://localhost:8080"
        )

        XCTAssertEqual(insecure.validate(), .invalid(.insecureBaseURL))
        XCTAssertEqual(localhost.validate(), .invalid(.insecureBaseURL))
        XCTAssertTrue(localhost.validate(allowsDevelopmentHTTP: true).isValid)
    }

    func testRejectsEndpointPathsThatCanEscapeTheConfiguredOrigin() {
        let invalidPaths = [
            "//attacker.example.com/manifest",
            "/../manifest",
            "/%2E%2E/manifest",
            "/manifest?redirect=https://attacker.example.com",
            "/manifest#untrusted",
            "/\\attacker.example.com/manifest"
        ]

        for path in invalidPaths {
            let gateway = HTMLAppGatewayConfiguration(
                name: "Unsafe path",
                baseURL: "https://gateway.example.com",
                manifestPath: path
            )
            XCTAssertEqual(gateway.validate(), .invalid(.invalidManifestPath), path)
        }
    }

    func testRegistryActivatesPersistsAndRemovesGateway() throws {
        let storage = MemoryStorage()
        let registry = HTMLAppGatewayRegistry(storage: storage)
        let first = HTMLAppGatewayConfiguration(id: "first", name: "First", baseURL: "https://first.example.com")
        let second = HTMLAppGatewayConfiguration(id: "second", name: "Second", baseURL: "https://second.example.com")

        try registry.save(first, activate: true)
        try registry.save(second)
        XCTAssertEqual(registry.activeGateway(), first)

        try registry.activate(id: second.id)
        XCTAssertEqual(HTMLAppGatewayRegistry(storage: storage).activeGateway(), second)

        try registry.remove(id: second.id)
        XCTAssertNil(registry.activeGateway())
        XCTAssertEqual(registry.allGateways(), [first])
    }
}
