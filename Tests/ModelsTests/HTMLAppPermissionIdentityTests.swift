//
//  HTMLAppPermissionIdentityTests.swift
//  WebBridgeKitTests
//
//  Grant identity, invalidation, and session lifecycle rules from the PWA
//  permission UI design (2026-08-14).
//

import XCTest
@testable import WebBridgeKit

final class HTMLAppPermissionIdentityTests: XCTestCase {

    private final class MemoryStorage: HTMLAppRuntimeStorage {
        private var values: [String: Data] = [:]

        func data(forKey key: String) -> Data? { values[key] }
        func set(_ data: Data?, forKey key: String) { values[key] = data }
    }

    private let gatewayA = "gateway-a#key-1"
    private let gatewayB = "gateway-b#key-2"
    private let appID = "com.example.inventory"
    private let origin = "https://inventory.example.com"

    private func makeSubject(
        gateway: String? = nil,
        app: String? = nil,
        origin originOverride: String? = nil
    ) -> HTMLAppPermissionSubject {
        HTMLAppPermissionSubject(
            gatewayIdentity: gateway ?? gatewayA,
            appID: app ?? appID,
            origin: originOverride ?? origin
        )
    }

    func testGrantDoesNotCarryAcrossGatewayIdentityOrOrigin() {
        let ledger = HTMLAppPermissionLedger(storage: MemoryStorage())

        ledger.grant(subject: makeSubject(), capability: .bluetooth, scope: .always)

        XCTAssertNotNil(ledger.grant(for: makeSubject(), capability: .bluetooth))
        XCTAssertNil(ledger.grant(for: makeSubject(gateway: gatewayB), capability: .bluetooth))
        XCTAssertNil(ledger.grant(for: makeSubject(origin: "https://mirror.example.com"), capability: .bluetooth))
        XCTAssertNil(ledger.grant(for: makeSubject(app: "com.example.other"), capability: .bluetooth))
    }

    func testRemovingGatewayDropsItsGrantsAcrossApps() {
        let ledger = HTMLAppPermissionLedger(storage: MemoryStorage())

        ledger.grant(subject: makeSubject(), capability: .bluetooth, scope: .always)
        ledger.grant(
            subject: makeSubject(app: "com.example.second"),
            capability: .camera,
            scope: .always
        )
        ledger.grant(subject: makeSubject(gateway: gatewayB), capability: .camera, scope: .always)

        ledger.removeGrants(gatewayIdentity: gatewayA)

        XCTAssertNil(ledger.grant(for: makeSubject(), capability: .bluetooth))
        XCTAssertNil(ledger.grant(for: makeSubject(app: "com.example.second"), capability: .camera))
        XCTAssertNotNil(ledger.grant(for: makeSubject(gateway: gatewayB), capability: .camera))
    }

    func testEndSessionClearsWhileUsingGrantsButKeepsAlways() {
        let ledger = HTMLAppPermissionLedger(storage: MemoryStorage())
        let subject = makeSubject()

        ledger.grant(subject: subject, capability: .bluetooth, scope: .appSession)
        ledger.grant(subject: subject, capability: .camera, scope: .always)
        // Same app under another gateway must be untouched.
        ledger.grant(subject: makeSubject(gateway: gatewayB), capability: .scan, scope: .appSession)

        ledger.endSession(for: subject)

        XCTAssertNil(ledger.grant(for: subject, capability: .bluetooth))
        XCTAssertNotNil(ledger.grant(for: subject, capability: .camera))
        XCTAssertNotNil(ledger.grant(for: makeSubject(gateway: gatewayB), capability: .scan))
    }

    func testWhileUsingGrantsDoNotSurviveLedgerReload() {
        let storage = MemoryStorage()
        let ledger = HTMLAppPermissionLedger(storage: storage)
        ledger.grant(subject: makeSubject(), capability: .bluetooth, scope: .appSession)

        XCTAssertNil(HTMLAppPermissionLedger(storage: storage).grant(for: makeSubject(), capability: .bluetooth))
        XCTAssertNotNil(ledger.grant(for: makeSubject(), capability: .bluetooth))
    }

    func testAlwaysGrantsSurviveReloadButLegacyGrantsArePruned() throws {
        let storage = MemoryStorage()
        let ledger = HTMLAppPermissionLedger(storage: storage)
        ledger.grant(subject: makeSubject(), capability: .bluetooth, scope: .always)

        // Replace persisted state with a mix of a fully identified grant and a
        // legacy grant persisted before gateway/origin identity existed.
        let legacyJSON = """
        {
          "com.example.inventory|camera": {
            "appID": "com.example.inventory",
            "capability": "camera",
            "scope": "always",
            "grantedAt": 0
          },
          "gateway-a#key-1|com.example.inventory|https://inventory.example.com|bluetooth": {
            "subject": {
              "gatewayIdentity": "gateway-a#key-1",
              "appID": "com.example.inventory",
              "origin": "https://inventory.example.com"
            },
            "capability": "bluetooth",
            "scope": "always",
            "grantedAt": 0
          }
        }
        """
        storage.set(Data(legacyJSON.utf8), forKey: "com.webbridgekit.html-app-runtime.permission-grants")

        let reloaded = HTMLAppPermissionLedger(storage: storage)

        XCTAssertNotNil(reloaded.grant(for: makeSubject(), capability: .bluetooth))
        XCTAssertFalse(reloaded.allGrants().contains { $0.capability == .camera && $0.subject.gatewayIdentity.isEmpty })
    }

    func testSyncGrantsDropsCapabilitiesRemovedFromManifest() {
        let ledger = HTMLAppPermissionLedger(storage: MemoryStorage())
        let subject = makeSubject()
        ledger.grant(subject: subject, capability: .bluetooth, scope: .always)
        ledger.grant(subject: subject, capability: .camera, scope: .always)

        let reducedManifest = HTMLAppManifest(
            appID: appID,
            name: "Inventory",
            startURL: "\(origin)/index.html",
            allowedOrigins: [origin],
            capabilities: [.camera],
            routes: ["/"],
            cache: HTMLAppCachePolicy(strategy: .manifest, version: "2", persistent: true)
        )

        ledger.syncGrants(with: reducedManifest, gatewayIdentity: gatewayA, origin: origin)

        XCTAssertNil(ledger.grant(for: subject, capability: .bluetooth))
        XCTAssertNotNil(ledger.grant(for: subject, capability: .camera))
    }

    func testUninstallDropsAllGrantsForApp() {
        let ledger = HTMLAppPermissionLedger(storage: MemoryStorage())
        ledger.grant(subject: makeSubject(), capability: .bluetooth, scope: .always)
        ledger.grant(subject: makeSubject(gateway: gatewayB), capability: .camera, scope: .appSession)
        ledger.grant(subject: makeSubject(app: "com.example.other"), capability: .scan, scope: .always)

        ledger.revokeAll(appID: appID)

        XCTAssertTrue(ledger.grants(for: appID).isEmpty)
        XCTAssertNotNil(ledger.grant(for: makeSubject(app: "com.example.other"), capability: .scan))
    }
}
