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

    @Test("registering the same token updates instead of duplicating")
    func sameTokenUpdatesWithoutDuplicate() async throws {
        let fixture = try TemporaryTokenStoreFixture()
        let store = TokenStore(fileURL: fixture.fileURL)
        try await store.register(Self.registration(token: "token-a", key: "old-key"))
        try await store.register(Self.registration(token: "token-a", key: "new-key"))

        #expect(await store.deviceCount() == 1)
        #expect(await store.getDevices(forKey: "old-key").isEmpty)
        #expect(await store.getDevices(forKey: "new-key").map(\.deviceToken) == ["token-a"])
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
