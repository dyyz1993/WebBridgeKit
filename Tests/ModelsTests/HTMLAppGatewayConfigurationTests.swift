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

    func testCanonicalJSONAndURLProduceEquivalentConfigurations() throws {
        let key = Data(repeating: 7, count: 32).base64EncodedString()
        let json = """
        {
          "schemaVersion": "1",
          "id": "inventory",
          "displayName": "Inventory Gateway",
          "baseURL": "https://gateway.example.com",
          "healthEndpoint": "/health",
          "manifestEndpoint": "/api/v1/manifest",
          "publicKeyId": "gateway-key-1",
          "publicKey": "\(key)"
        }
        """
        let url = "webbridgekit://gateway?schemaVersion=1&id=inventory&displayName=Inventory%20Gateway&baseURL=https%3A%2F%2Fgateway.example.com&healthEndpoint=%2Fhealth&manifestEndpoint=%2Fapi%2Fv1%2Fmanifest&publicKeyId=gateway-key-1&publicKey=\(key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)"

        XCTAssertEqual(
            try HTMLAppGatewayConfiguration.importPayload(json),
            try HTMLAppGatewayConfiguration.importPayload(url)
        )
    }

    func testRejectsSecretBearingJSONAndURLPayloads() {
        let secretFields = ["privateKey", "apiSecret", "token", "password", "adminToken"]
        for field in secretFields {
            let json = """
            {"name":"Unsafe","baseURL":"https://gateway.example.com","\(field)":"secret"}
            """
            XCTAssertThrowsError(try HTMLAppGatewayConfiguration.importPayload(json)) { error in
                XCTAssertEqual(error as? HTMLAppGatewayConfigurationImportError, .forbiddenSecretField(field))
            }
            let url = "webbridgekit://gateway?name=Unsafe&url=https%3A%2F%2Fgateway.example.com&\(field)=secret"
            XCTAssertThrowsError(try HTMLAppGatewayConfiguration.importPayload(url))
        }
        XCTAssertThrowsError(try HTMLAppGatewayConfiguration.importPayload(
            #"{"name":"Unsafe","baseURL":"https://gateway.example.com","metadata":{"password":"secret"}}"#
        ))
    }

    func testRejectsMissingCanonicalFieldsAndUnknownSchema() {
        XCTAssertThrowsError(try HTMLAppGatewayConfiguration.importPayload(
            #"{"schemaVersion":"2","displayName":"Future","baseURL":"https://gateway.example.com"}"#
        )) { error in
            XCTAssertEqual(error as? HTMLAppGatewayConfigurationImportError, .unsupportedSchemaVersion("2"))
        }
        XCTAssertThrowsError(try HTMLAppGatewayConfiguration.importPayload(
            #"{"schemaVersion":"1","baseURL":"https://gateway.example.com"}"#
        )) { error in
            XCTAssertEqual(error as? HTMLAppGatewayConfigurationImportError, .missingRequiredField("displayName"))
        }
    }

    func testRejectsMalformedEd25519PublicKey() {
        let gateway = HTMLAppGatewayConfiguration(
            name: "Bad key",
            baseURL: "https://gateway.example.com",
            publicKeyID: "prod-1",
            publicKey: Data(repeating: 1, count: 31).base64EncodedString()
        )
        XCTAssertEqual(gateway.validate(), .invalid(.invalidPublicKey))
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
            "/\\attacker.example.com/manifest",
            "/%5Cattacker.example.com/manifest"
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
