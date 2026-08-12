//
//  HTMLAppLaunchRuntimeTests.swift
//  WebBridgeKitTests
//

import CryptoKit
import XCTest
@testable import WebBridgeKit

final class HTMLAppLaunchRuntimeTests: XCTestCase {
    private final class MemoryStorage: HTMLAppRuntimeStorage {
        var values: [String: Data] = [:]
        func data(forKey key: String) -> Data? { values[key] }
        func set(_ data: Data?, forKey key: String) { values[key] = data }
    }

    private func manifest(
        appID: String = "com.example.chat",
        routes: [String] = ["/", "/conversations/:id", "/approvals/:id"],
        cache: HTMLAppCachePolicy? = nil
    ) -> HTMLAppManifest {
        HTMLAppManifest(
            appID: appID,
            name: "Chat",
            startURL: "https://chat.example.com/index.html",
            allowedOrigins: ["https://chat.example.com"],
            capabilities: [],
            routes: routes,
            cache: cache ?? HTMLAppCachePolicy(strategy: .manifest, version: "1", persistent: true)
        )
    }

    private func agentConsoleManifest() -> HTMLAppManifest {
        HTMLAppManifest(
            appID: "com.example.agent-console",
            name: "Agent Console",
            startURL: "https://console.example.com/index.html",
            allowedOrigins: ["https://console.example.com"],
            capabilities: [.notification],
            routes: ["/index.html", "/approvals/:id"],
            cache: HTMLAppCachePolicy(strategy: .manifest, version: "1", persistent: true)
        )
    }

    func testStandardPWAWithoutNativeCapabilitiesIsValid() {
        XCTAssertTrue(manifest().validate().isValid)
    }

    func testNotificationResolvesExactChatRouteAndParameters() throws {
        let storage = MemoryStorage()
        let registry = HTMLAppTrustRegistry(storage: storage)
        let app = manifest()
        try registry.register(app)
        let resolver = HTMLAppLaunchResolver(trustRegistry: registry)
        let envelope = HTMLAppPushEnvelope(
            appID: app.appID,
            route: "/conversations/user-42",
            parameters: ["messageId": "message-7"],
            notification: HTMLAppPushNotification(title: "New message", body: "Open chat")
        )

        let target = try resolver.resolve(envelope: envelope)

        XCTAssertEqual(target.pageURL.absoluteString, "https://chat.example.com/conversations/user-42")
        XCTAssertEqual(target.offlineMode, .partial)
        XCTAssertEqual(target.context.bridgePayload["webbridgekitRoute"], "/conversations/user-42")
        XCTAssertEqual(target.context.bridgePayload["messageId"], "message-7")
    }

    func testNotificationResolvesCompletedTaskInIndependentPWA() throws {
        let storage = MemoryStorage()
        let registry = HTMLAppTrustRegistry(storage: storage)
        let app = agentConsoleManifest()
        try registry.register(app)
        let resolver = HTMLAppLaunchResolver(trustRegistry: registry)

        let target = try resolver.resolve(
            envelope: HTMLAppPushEnvelope(
                appID: app.appID,
                route: "/index.html",
                parameters: ["taskId": "run-20260810", "status": "completed"],
                notification: HTMLAppPushNotification(title: "Task complete", body: "Open result")
            )
        )

        XCTAssertEqual(target.pageURL.absoluteString, "https://console.example.com/index.html")
        XCTAssertEqual(target.context.bridgePayload["taskId"], "run-20260810")
        XCTAssertEqual(target.context.bridgePayload["status"], "completed")
        XCTAssertEqual(target.context.bridgePayload["webbridgekitAppId"], app.appID)
    }

    func testApprovalNotificationOnlyResolvesRouteAndPreservesUserConsentBoundary() throws {
        let storage = MemoryStorage()
        let registry = HTMLAppTrustRegistry(storage: storage)
        let app = agentConsoleManifest()
        try registry.register(app)
        let resolver = HTMLAppLaunchResolver(trustRegistry: registry)

        let target = try resolver.resolve(
            envelope: HTMLAppPushEnvelope(
                appID: app.appID,
                route: "/approvals/approval-42",
                parameters: ["requestId": "approval-42", "source": "remote-task"],
                notification: HTMLAppPushNotification(title: "Approval required", body: "Review request")
            )
        )

        XCTAssertEqual(target.pageURL.path, "/approvals/approval-42")
        XCTAssertEqual(target.context.source, .notification)
        XCTAssertEqual(target.context.bridgePayload["requestId"], "approval-42")
        XCTAssertNil(target.context.bridgePayload["approved"])
        XCTAssertNil(target.context.bridgePayload["granted"])
    }

    func testEligiblePackageIsPartialUntilVerifiedVersionIsInstalled() throws {
        let storage = MemoryStorage()
        let registry = HTMLAppTrustRegistry(storage: storage)
        let cache = HTMLAppCachePolicy(
            strategy: .manifest,
            version: "7",
            persistent: true,
            resourceManifestURL: "https://chat.example.com/offline/manifest.json",
            resourceManifestSHA256: String(repeating: "a", count: 64)
        )
        let app = manifest(cache: cache)
        try registry.register(app)
        let resolver = HTMLAppLaunchResolver(trustRegistry: registry)

        let target = try resolver.resolve(
            appID: app.appID,
            route: "/approvals/request-9",
            parameters: ["source": "notification"],
            source: .notification
        )

        XCTAssertEqual(target.offlineMode, .partial)
        XCTAssertEqual(target.loaderURL.absoluteString, "https://chat.example.com/offline/manifest.json")
        XCTAssertEqual(target.pageURL.path, "/approvals/request-9")
    }

    func testResolverPrefersInstalledStrongOfflineEntrypoint() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("HTMLAppLaunchPackageTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let digest = String(repeating: "a", count: 64)
        let cache = HTMLAppCachePolicy(
            strategy: .manifest,
            version: "7",
            persistent: true,
            resourceManifestURL: "https://chat.example.com/offline/manifest.json",
            resourceManifestSHA256: digest
        )
        let app = manifest(cache: cache)
        let directoryName = "installed-v7"
        let metadata = InstalledHTMLAppPackage(
            appID: app.appID,
            version: "7",
            entrypoint: "index.html",
            directoryName: directoryName,
            resourceManifestSHA256: digest,
            installedAt: Date(timeIntervalSince1970: 1)
        )
        let appDirectory = root.appendingPathComponent(sha256(app.appID))
        let packageDirectory = appDirectory.appendingPathComponent("versions/\(directoryName)")
        try FileManager.default.createDirectory(at: packageDirectory, withIntermediateDirectories: true)
        try Data("<html></html>".utf8).write(to: packageDirectory.appendingPathComponent("index.html"))
        try JSONEncoder().encode(metadata).write(to: packageDirectory.appendingPathComponent("package.json"))
        try JSONEncoder().encode(metadata).write(to: appDirectory.appendingPathComponent("current.json"))

        let storage = MemoryStorage()
        let registry = HTMLAppTrustRegistry(storage: storage)
        try registry.register(app)
        let resolver = HTMLAppLaunchResolver(
            trustRegistry: registry,
            packageLocator: HTMLAppOfflinePackageLocator(packagesRoot: root)
        )

        let target = try resolver.resolve(appID: app.appID, route: "/approvals/request-9")

        XCTAssertEqual(target.offlineMode, .strong)
        XCTAssertEqual(target.loaderURL, packageDirectory.appendingPathComponent("index.html"))
    }

    func testLegacyPersistentManifestWithoutDigestRemainsPartial() throws {
        let storage = MemoryStorage()
        let registry = HTMLAppTrustRegistry(storage: storage)
        let app = manifest(cache: HTMLAppCachePolicy(
            strategy: .manifest,
            version: "7",
            persistent: true,
            resourceManifestURL: "https://chat.example.com/offline/manifest.json"
        ))
        try registry.register(app)

        let target = try HTMLAppLaunchResolver(trustRegistry: registry).resolve(appID: app.appID, route: "/")

        XCTAssertEqual(target.offlineMode, .partial)
    }

    func testResolverRejectsUnknownOrDisallowedTargets() throws {
        let storage = MemoryStorage()
        let registry = HTMLAppTrustRegistry(storage: storage)
        try registry.register(manifest())
        let resolver = HTMLAppLaunchResolver(trustRegistry: registry)

        XCTAssertThrowsError(try resolver.resolve(appID: "com.example.unknown", route: "/")) {
            XCTAssertEqual($0 as? HTMLAppLaunchError, .appNotRegistered("com.example.unknown"))
        }
        XCTAssertThrowsError(try resolver.resolve(appID: "com.example.chat", route: "/admin")) {
            XCTAssertEqual($0 as? HTMLAppLaunchError, .invalidEnvelope)
        }
    }

    func testSnapshotPersistsAcrossStoreInstancesAndClearsByAppID() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("HTMLAppStateSnapshotTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let payload = try JSONSerialization.data(withJSONObject: [
            "conversationId": "user-42",
            "draft": "offline reply"
        ])
        let first = HTMLAppStateSnapshotStore(rootDirectory: root)

        _ = try first.save(
            appID: "com.example.chat",
            route: "/conversations/user-42",
            jsonData: payload
        )
        let restored = HTMLAppStateSnapshotStore(rootDirectory: root).snapshot(for: "com.example.chat")

        XCTAssertEqual(restored?.route, "/conversations/user-42")
        XCTAssertEqual(restored?.payload, payload)
        try first.clear(appID: "com.example.chat")
        XCTAssertNil(first.snapshot(for: "com.example.chat"))
    }

    func testSnapshotRejectsInvalidJSON() {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("HTMLAppStateSnapshotTests-\(UUID().uuidString)")
        let store = HTMLAppStateSnapshotStore(rootDirectory: root)

        XCTAssertThrowsError(try store.save(
            appID: "com.example.chat",
            route: "/",
            jsonData: Data("not-json".utf8)
        )) {
            XCTAssertEqual($0 as? HTMLAppStateSnapshotError, .invalidJSON)
        }
    }

    private func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
