//
//  HTMLAppRuntimeModelsTests.swift
//  WebBridgeKitTests
//

import XCTest
@testable import WebBridgeKit

final class HTMLAppRuntimeModelsTests: XCTestCase {

    private func makeManifest(
        allowedOrigins: [String] = ["https://inventory.example.com"],
        capabilities: [HTMLAppCapability] = [.bluetooth, .camera],
        routes: [String] = ["/", "/items/:id"]
    ) -> HTMLAppManifest {
        HTMLAppManifest(
            appID: "com.example.inventory",
            name: "Inventory",
            startURL: "https://inventory.example.com/index.html",
            allowedOrigins: allowedOrigins,
            capabilities: capabilities,
            routes: routes,
            cache: HTMLAppCachePolicy(strategy: .manifest, version: "1", persistent: true)
        )
    }

    func testManifestAcceptsExactDocumentOriginAndDeclaredCapabilities() {
        let manifest = makeManifest()

        XCTAssertTrue(manifest.validate().isValid)
        XCTAssertTrue(manifest.allows(documentURL: URL(string: "https://inventory.example.com/items/42")!))
        XCTAssertTrue(manifest.declares(.bluetooth))
        XCTAssertFalse(manifest.declares(.location))
    }

    func testCachePolicyDecodesBackwardCompatibleDefaults() throws {
        let data = Data(#"{"strategy":"manifest","version":"1","persistent":true}"#.utf8)

        let policy = try JSONDecoder().decode(HTMLAppCachePolicy.self, from: data)

        XCTAssertNil(policy.resourceManifestURL)
        XCTAssertNil(policy.resourceManifestSHA256)
        XCTAssertTrue(policy.restoresLastState)
        XCTAssertFalse(policy.isStrongOfflineEligible)
    }

    func testStrongOfflineEligibilityRequiresURLAndLowercaseSHA256() throws {
        let digest = String(repeating: "a", count: 64)
        let policy = HTMLAppCachePolicy(
            strategy: .manifest,
            version: "42",
            persistent: true,
            resourceManifestURL: "https://inventory.example.com/package.json",
            resourceManifestSHA256: digest
        )

        XCTAssertTrue(policy.isStrongOfflineEligible)
        XCTAssertEqual(try JSONDecoder().decode(HTMLAppCachePolicy.self, from: JSONEncoder().encode(policy)), policy)
        XCTAssertFalse(HTMLAppCachePolicy(
            strategy: .manifest,
            version: "42",
            persistent: true,
            resourceManifestURL: "https://inventory.example.com/package.json",
            resourceManifestSHA256: String(repeating: "A", count: 64)
        ).isStrongOfflineEligible)
    }

    func testDrelOfflineDeclarationDecodesAndSuppliesStrongOfflinePolicy() throws {
        let digest = String(repeating: "a", count: 64)
        let data = Data("""
        {
          "schemaVersion": "1",
          "appId": "com.example.inventory",
          "name": "Inventory",
          "startURL": "https://inventory.example.com/index.html",
          "allowedOrigins": ["https://inventory.example.com"],
          "capabilities": [],
          "routes": ["/"],
          "cache": { "strategy": "manifest", "version": "1", "persistent": true },
          "drel_offline": {
            "version": "42",
            "resource_manifest": "https://inventory.example.com/offline/package.json",
            "resource_manifest_sha256": "\(digest)"
          }
        }
        """.utf8)

        let manifest = try JSONDecoder().decode(HTMLAppManifest.self, from: data)

        XCTAssertEqual(manifest.drelOffline?.version, "42")
        XCTAssertEqual(manifest.effectiveOfflineCache.version, "42")
        XCTAssertEqual(manifest.effectiveOfflineCache.resourceManifestURL, "https://inventory.example.com/offline/package.json")
        XCTAssertTrue(manifest.effectiveOfflineCache.isStrongOfflineEligible)
        XCTAssertTrue(manifest.validate().isValid)

        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(manifest)) as? [String: Any]
        let offline = object?["drel_offline"] as? [String: Any]
        XCTAssertEqual(offline?["resource_manifest"] as? String, "https://inventory.example.com/offline/package.json")
        XCTAssertEqual(offline?["resource_manifest_sha256"] as? String, digest)
    }

    func testDrelOfflineDeclarationRejectsConflictWithLegacyStrongPolicy() {
        let digest = String(repeating: "a", count: 64)
        let manifest = HTMLAppManifest(
            appID: "com.example.inventory",
            name: "Inventory",
            startURL: "https://inventory.example.com/index.html",
            allowedOrigins: ["https://inventory.example.com"],
            capabilities: [],
            routes: ["/"],
            cache: HTMLAppCachePolicy(
                strategy: .manifest,
                version: "41",
                persistent: true,
                resourceManifestURL: "https://inventory.example.com/offline/old.json",
                resourceManifestSHA256: digest
            ),
            drelOffline: DrelOfflinePackageDeclaration(
                version: "42",
                resourceManifestURL: "https://inventory.example.com/offline/package.json",
                resourceManifestSHA256: digest
            )
        )

        XCTAssertEqual(manifest.validate(), .invalid([.inconsistentDrelOfflineDeclaration]))
    }

    func testWebManifestBindingUsesStableKeysAndRequiresPinnedAllowedHTTPSURL() throws {
        let digest = String(repeating: "b", count: 64)
        let manifest = HTMLAppManifest(
            appID: "com.example.inventory",
            name: "Inventory",
            startURL: "https://inventory.example.com/index.html",
            allowedOrigins: ["https://inventory.example.com"],
            capabilities: [],
            routes: ["/"],
            cache: HTMLAppCachePolicy(strategy: .networkOnly, version: "1", persistent: false),
            webManifest: HTMLAppWebManifestBinding(
                url: "https://inventory.example.com/manifest.webmanifest",
                sha256: digest
            )
        )

        XCTAssertTrue(manifest.validate().isValid)
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(manifest)) as? [String: Any]
        let binding = object?["webManifest"] as? [String: Any]
        XCTAssertEqual(binding?["sha256"] as? String, digest)

        let disallowed = HTMLAppManifest(
            appID: manifest.appID,
            name: manifest.name,
            startURL: manifest.startURL,
            allowedOrigins: manifest.allowedOrigins,
            capabilities: manifest.capabilities,
            routes: manifest.routes,
            cache: manifest.cache,
            webManifest: HTMLAppWebManifestBinding(
                url: "https://attacker.example/manifest.webmanifest",
                sha256: digest
            )
        )
        XCTAssertEqual(
            disallowed.validate(),
            .invalid([.invalidWebManifestURL("https://attacker.example/manifest.webmanifest")])
        )
    }

    func testManifestRejectsMalformedResourceManifestDigest() {
        let manifest = HTMLAppManifest(
            appID: "com.example.inventory",
            name: "Inventory",
            startURL: "https://inventory.example.com/index.html",
            allowedOrigins: ["https://inventory.example.com"],
            capabilities: [],
            routes: ["/"],
            cache: HTMLAppCachePolicy(
                strategy: .manifest,
                version: "42",
                persistent: true,
                resourceManifestURL: "https://inventory.example.com/package.json",
                resourceManifestSHA256: "not-a-digest"
            )
        )

        XCTAssertEqual(manifest.validate(), .invalid([.invalidResourceManifestDigest]))
    }

    func testResourceManifestDigestChangesCanonicalParentBytes() throws {
        let withoutDigest = HTMLAppCachePolicy(
            strategy: .manifest,
            version: "42",
            persistent: true,
            resourceManifestURL: "https://inventory.example.com/package.json"
        )
        let withDigest = HTMLAppCachePolicy(
            strategy: .manifest,
            version: "42",
            persistent: true,
            resourceManifestURL: "https://inventory.example.com/package.json",
            resourceManifestSHA256: String(repeating: "a", count: 64)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        XCTAssertNotEqual(try encoder.encode(withoutDigest), try encoder.encode(withDigest))
        let object = try JSONSerialization.jsonObject(with: encoder.encode(withDigest)) as? [String: Any]
        XCTAssertEqual(object?["resourceManifestSHA256"] as? String, String(repeating: "a", count: 64))
    }

    func testManifestRejectsWildcardAndPathBasedOrigins() {
        let wildcard = makeManifest(allowedOrigins: ["https://*.example.com"])
        let path = makeManifest(allowedOrigins: ["https://inventory.example.com/app"])

        XCTAssertFalse(wildcard.validate().isValid)
        XCTAssertFalse(path.validate().isValid)
    }

    func testManifestRejectsRouteGlobThatCannotMatchAtLaunch() {
        let manifest = makeManifest(routes: ["/items/*"])

        XCTAssertFalse(manifest.validate().isValid)
        XCTAssertFalse(manifest.allows(route: "/items/42"))
    }

    func testManifestRejectsStartURLOutsideDeclaredOrigins() {
        let manifest = HTMLAppManifest(
            appID: "com.example.inventory",
            name: "Inventory",
            startURL: "https://other.example.com/index.html",
            allowedOrigins: ["https://inventory.example.com"],
            capabilities: [.camera],
            routes: ["/"],
            cache: HTMLAppCachePolicy(strategy: .manifest, version: "1", persistent: true)
        )

        XCTAssertEqual(manifest.validate(), .invalid([.startURLNotAllowed("https://other.example.com")]))
    }

    func testManifestUsesStableJSONContractKeys() throws {
        let manifest = HTMLAppManifest(
            appID: "com.example.inventory",
            name: "Inventory",
            startURL: "https://inventory.example.com/index.html",
            allowedOrigins: ["https://inventory.example.com"],
            capabilities: [.camera],
            routes: ["/"],
            cache: HTMLAppCachePolicy(strategy: .manifest, version: "1", persistent: true),
            signature: HTMLAppManifestSignature(
                algorithm: "ed25519",
                keyID: "inventory-prod-1",
                value: "signature"
            )
        )

        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(manifest)) as? [String: Any]
        let signature = object?["signature"] as? [String: Any]

        XCTAssertEqual(object?["appId"] as? String, manifest.appID)
        XCTAssertNil(object?["appID"])
        XCTAssertEqual(signature?["keyId"] as? String, "inventory-prod-1")
    }

    func testCapabilityRequestRequiresDeclaredCapabilityAndReason() {
        let manifest = makeManifest(capabilities: [.camera])
        let undeclared = HTMLAppCapabilityRequest(id: "request-1", capability: .bluetooth, reason: "Connect device", scope: .once)
        let missingReason = HTMLAppCapabilityRequest(id: "request-2", capability: .camera, reason: " ", scope: .once)
        let accepted = HTMLAppCapabilityRequest(id: "request-3", capability: .camera, reason: "Scan a barcode", scope: .once)

        XCTAssertEqual(undeclared.validate(against: manifest), .rejected(.undeclaredCapability(.bluetooth)))
        XCTAssertEqual(missingReason.validate(against: manifest), .rejected(.missingReason))
        XCTAssertEqual(accepted.validate(against: manifest), .accepted)
    }

    func testRouteMatchingAllowsDeclaredParametersOnly() {
        let manifest = makeManifest()

        XCTAssertTrue(manifest.allows(route: "/"))
        XCTAssertTrue(manifest.allows(route: "/items/42"))
        XCTAssertFalse(manifest.allows(route: "/items"))
        XCTAssertFalse(manifest.allows(route: "/items/42?preview=true"))
        XCTAssertFalse(manifest.allows(route: "/items/../private"))
    }

    func testPushEnvelopeRequiresMatchingAppRouteAndFutureExpiry() {
        let manifest = makeManifest()
        let valid = HTMLAppPushEnvelope(
            appID: manifest.appID,
            route: "/items/42",
            notification: HTMLAppPushNotification(
                title: "Inventory update",
                body: "An item needs attention"
            ),
            expiresAt: "2030-01-01T00:00:00Z"
        )
        let invalidRoute = HTMLAppPushEnvelope(
            appID: manifest.appID,
            route: "/admin",
            notification: HTMLAppPushNotification(
                title: "Inventory update",
                body: "An item needs attention"
            )
        )

        XCTAssertTrue(valid.isValid(for: manifest, now: Date(timeIntervalSince1970: 0)))
        XCTAssertFalse(invalidRoute.isValid(for: manifest))
    }

    func testPushEnvelopeUsesNestedNotificationAndParamsKeys() throws {
        let envelope = HTMLAppPushEnvelope(
            appID: "com.example.inventory",
            route: "/items/42",
            parameters: ["source": "notification"],
            notification: HTMLAppPushNotification(title: "Inventory update", body: "Open details")
        )

        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(envelope)) as? [String: Any]
        let notification = object?["notification"] as? [String: Any]

        XCTAssertEqual(object?["appId"] as? String, envelope.appID)
        XCTAssertEqual(object?["params"] as? [String: String], envelope.parameters)
        XCTAssertEqual(notification?["title"] as? String, envelope.notification.title)
    }
}
