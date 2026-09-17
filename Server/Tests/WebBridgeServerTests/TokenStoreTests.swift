import Foundation
import Testing

@testable import WebBridgeServer

@Suite("Token Store")
struct TokenStoreTests {
    @Test("registration survives store recreation")
    func registrationSurvivesStoreRecreation() async throws {
        let fixture = try TemporaryTokenStoreFixture()
        let store = TokenStore(fileURL: fixture.fileURL)
        try await store.register(Self.registration(token: "token-a", key: "key-a"))

        let restored = TokenStore(fileURL: fixture.fileURL)
        let devices = await restored.getDevices(forKey: "key-a")

        #expect(devices.map(\.deviceToken) == ["token-a"])
    }

    @Test("legacy token-keyed persistence normalizes without duplicate delivery")
    func legacyPersistenceNormalizesRegistrationKey() async throws {
        let fixture = try TemporaryTokenStoreFixture()
        let legacy = [
            "token-a": Self.registration(token: "token-a", key: "legacy-key")
        ]
        try JSONEncoder().encode(legacy).write(to: fixture.fileURL)

        let store = TokenStore(fileURL: fixture.fileURL)
        try await store.register(Self.registration(token: "token-a", key: "legacy-key"))

        #expect(await store.deviceCount() == 1)
        #expect(await store.getDevices(forKey: "legacy-key").map(\.deviceToken) == ["token-a"])
    }

    @Test("registering a short successor preserves the legacy key for the same token")
    func sameTokenCanKeepLegacyAndShortKey() async throws {
        let fixture = try TemporaryTokenStoreFixture()
        let store = TokenStore(fileURL: fixture.fileURL)
        try await store.register(Self.registration(token: "token-a", key: "old-key"))
        try await store.register(Self.registration(token: "token-a", key: "new-key"))

        #expect(await store.deviceCount() == 2)
        #expect(await store.getDevices(forKey: "old-key").map(\.deviceToken) == ["token-a"])
        #expect(await store.getDevices(forKey: "new-key").map(\.deviceToken) == ["token-a"])
    }

    @Test("registering the same token and key updates in place")
    func sameTokenAndKeyUpdatesWithoutDuplicate() async throws {
        let fixture = try TemporaryTokenStoreFixture()
        let store = TokenStore(fileURL: fixture.fileURL)
        try await store.register(Self.registration(token: "token-a", key: "key-a"))
        try await store.register(Self.registration(token: "token-a", key: "key-a"))

        #expect(await store.deviceCount() == 1)
        #expect(await store.getDevices(forKey: "key-a").map(\.deviceToken) == ["token-a"])
    }

    @Test("unregister removes only the requested key and token pair")
    func unregisterRemovesOnlyMatchingRegistration() async throws {
        let fixture = try TemporaryTokenStoreFixture()
        let store = TokenStore(fileURL: fixture.fileURL)
        try await store.register(Self.registration(token: "token-a", key: "old-key"))
        try await store.register(Self.registration(token: "token-a", key: "new-key"))
        try await store.register(Self.registration(token: "token-b", key: "old-key"))

        let removed = try await store.unregister(token: "token-a", key: "old-key")

        #expect(removed)
        #expect(await store.getDevices(forKey: "old-key").map(\.deviceToken) == ["token-b"])
        #expect(await store.getDevices(forKey: "new-key").map(\.deviceToken) == ["token-a"])
    }

    @Test("unregister reports a missing pair without changing persistence")
    func unregisterMissingPairIsIdempotent() async throws {
        let fixture = try TemporaryTokenStoreFixture()
        let store = TokenStore(fileURL: fixture.fileURL)
        try await store.register(Self.registration(token: "token-a", key: "key-a"))

        let removed = try await store.unregister(token: "token-b", key: "key-a")

        #expect(!removed)
        #expect(await store.deviceCount() == 1)
    }

    @Test("corrupt registration file is quarantined instead of silently overwritten")
    func corruptFileIsQuarantined() async throws {
        let fixture = try TemporaryTokenStoreFixture()
        try Data("not-json".utf8).write(to: fixture.fileURL)

        let store = TokenStore(fileURL: fixture.fileURL)
        let issue = await store.recoveryIssue()
        let quarantinedFiles = try FileManager.default.contentsOfDirectory(
            at: fixture.directory,
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.hasPrefix("device-registrations.json.corrupt-") }

        #expect(issue != nil)
        #expect(!FileManager.default.fileExists(atPath: fixture.fileURL.path))
        #expect(quarantinedFiles.count == 1)
    }

    @Test("concurrent registrations leave decodable JSON")
    func concurrentRegistrationsLeaveDecodableJSON() async throws {
        let fixture = try TemporaryTokenStoreFixture()
        let store = TokenStore(fileURL: fixture.fileURL)

        await withTaskGroup(of: Void.self) { group in
            for index in 0..<40 {
                group.addTask {
                    try? await store.register(Self.registration(token: "token-\(index)", key: "key-\(index % 4)"))
                }
            }
        }

        let data = try Data(contentsOf: fixture.fileURL)
        let decoded = try JSONDecoder().decode([String: DeviceRegistration].self, from: data)
        #expect(decoded.count == 40)
        #expect(await store.deviceCount() == 40)
    }

    private static func registration(token: String, key: String) -> DeviceRegistration {
        DeviceRegistration(
            deviceToken: token,
            key: key,
            platform: "ios",
            appVersion: "1.0",
            createdAt: "2026-08-12T00:00:00Z"
        )
    }
}

private struct TemporaryTokenStoreFixture {
    let directory: URL
    let fileURL: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("webbridgekit-token-store-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("device-registrations.json")
    }
}
