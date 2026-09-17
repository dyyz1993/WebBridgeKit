import CryptoKit
import XCTest
@testable import WebBridgeKit

final class HTMLAppOfflinePackageInstallerTests: XCTestCase {
    private final class MemoryStorage: HTMLAppRuntimeStorage {
        var values: [String: Data] = [:]
        func data(forKey key: String) -> Data? { values[key] }
        func set(_ data: Data?, forKey key: String) { values[key] = data }
    }

    private actor MemoryTransport: HTMLAppPackageTransport {
        var responses: [URL: HTMLAppPackageTransportResponse]
        var errors: [URL: Error]

        init(responses: [URL: HTMLAppPackageTransportResponse], errors: [URL: Error] = [:]) {
            self.responses = responses
            self.errors = errors
        }

        func data(from url: URL, maximumBytes: Int) async throws -> HTMLAppPackageTransportResponse {
            if let error = errors[url] { throw error }
            guard let response = responses[url] else { throw URLError(.resourceUnavailable) }
            guard response.data.count <= maximumBytes else {
                throw HTMLAppOfflinePackageError.resourceManifestTooLarge
            }
            return response
        }

        func replace(url: URL, response: HTMLAppPackageTransportResponse) {
            responses[url] = response
        }

        func disconnect() {
            responses.removeAll()
        }
    }

    private var root: URL!
    private let origin = URL(string: "https://offline.example.com")!

    override func setUp() {
        super.setUp()
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("HTMLAppOfflinePackageTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
        root = nil
        super.tearDown()
    }

    func testTrustedStandardWebManifestResolvesRelativeFieldsWithoutReplacingParentIdentity() async throws {
        let webManifestURL = origin.appendingPathComponent("app/manifest.webmanifest")
        let webManifestData = Data("""
        {
          "id": "attacker-controlled-id",
          "name": "Offline Console",
          "short_name": "Console",
          "start_url": "./index.html",
          "scope": "./",
          "display": "standalone",
          "theme_color": "#5B5CE2",
          "icons": [{"src":"./icon.png","sizes":"192x192","type":"image/png"}],
          "drel_offline": {
            "version": "7",
            "resource_manifest": "./package.json",
            "resource_manifest_sha256": "\(String(repeating: "a", count: 64))"
          }
        }
        """.utf8)
        let offline = DrelOfflinePackageDeclaration(
            version: "7",
            resourceManifestURL: origin.appendingPathComponent("app/package.json").absoluteString,
            resourceManifestSHA256: String(repeating: "a", count: 64)
        )
        let parent = trustedParent(webManifestURL: webManifestURL, data: webManifestData, drelOffline: offline)
        let adapter = HTMLAppWebManifestAdapter(transport: MemoryTransport(responses: [
            webManifestURL: .init(data: webManifestData, finalURL: webManifestURL)
        ]))

        let resolved = try await adapter.load(forTrustedParent: parent)

        XCTAssertEqual(resolved.appID, parent.appID)
        XCTAssertEqual(resolved.name, "Offline Console")
        XCTAssertEqual(resolved.startURL, origin.appendingPathComponent("app/index.html"))
        XCTAssertEqual(resolved.scopeURL, origin.appendingPathComponent("app/"))
        XCTAssertEqual(resolved.iconURLs, [origin.appendingPathComponent("app/icon.png")])
        XCTAssertEqual(resolved.drelOffline, offline)
    }

    func testTrustedStandardWebManifestRejectsDigestRedirectAndOfflineMismatch() async throws {
        let webManifestURL = origin.appendingPathComponent("manifest.webmanifest")
        let data = Data(#"{"name":"Console","start_url":"/","scope":"/"}"#.utf8)
        let wrongDigestParent = HTMLAppManifest(
            appID: "com.example.offline",
            name: "Parent",
            startURL: origin.appendingPathComponent("index.html").absoluteString,
            allowedOrigins: [origin.absoluteString],
            capabilities: [],
            routes: ["/"],
            cache: HTMLAppCachePolicy(strategy: .networkOnly, version: "1", persistent: false),
            webManifest: HTMLAppWebManifestBinding(url: webManifestURL.absoluteString, sha256: String(repeating: "0", count: 64)),
            signature: HTMLAppManifestSignature(algorithm: "ed25519", keyID: "test", value: "test")
        )
        let digestAdapter = HTMLAppWebManifestAdapter(transport: MemoryTransport(responses: [
            webManifestURL: .init(data: data, finalURL: webManifestURL)
        ]))
        do {
            _ = try await digestAdapter.load(forTrustedParent: wrongDigestParent)
            XCTFail("Digest mismatch must fail closed")
        } catch {
            XCTAssertEqual(error as? HTMLAppWebManifestAdapterError, .digestMismatch)
        }

        let redirectParent = trustedParent(webManifestURL: webManifestURL, data: data)
        let redirectAdapter = HTMLAppWebManifestAdapter(transport: MemoryTransport(responses: [
            webManifestURL: .init(data: data, finalURL: origin.appendingPathComponent("other.webmanifest"))
        ]))
        do {
            _ = try await redirectAdapter.load(forTrustedParent: redirectParent)
            XCTFail("Redirect away from the signed URL must fail closed")
        } catch {
            XCTAssertEqual(error as? HTMLAppWebManifestAdapterError, .redirectMismatch)
        }

        let declaredData = Data("""
        {"name":"Console","start_url":"/","scope":"/","drel_offline":{
          "version":"2","resource_manifest":"/package.json",
          "resource_manifest_sha256":"\(String(repeating: "c", count: 64))"}}
        """.utf8)
        let mismatchParent = trustedParent(webManifestURL: webManifestURL, data: declaredData)
        let mismatchAdapter = HTMLAppWebManifestAdapter(transport: MemoryTransport(responses: [
            webManifestURL: .init(data: declaredData, finalURL: webManifestURL)
        ]))
        do {
            _ = try await mismatchAdapter.load(forTrustedParent: mismatchParent)
            XCTFail("Unsigned offline installation authority must not be accepted")
        } catch {
            XCTAssertEqual(error as? HTMLAppWebManifestAdapterError, .offlineDeclarationMismatch)
        }
    }

    func testInstallsValidPackageAndReturnsCompleteEntrypoint() async throws {
        let fixture = try makeFixture(version: "1")
        let transport = MemoryTransport(responses: fixture.responses)
        let installer = HTMLAppOfflinePackageInstaller(transport: transport, packagesRoot: root)

        let installed = try await installer.install(appManifest: fixture.parent)
        let entrypoint = try await installer.entrypointURL(for: installed)

        XCTAssertEqual(installed.version, "1")
        XCTAssertEqual(try String(contentsOf: entrypoint), "<html>v1</html>")
        XCTAssertTrue(entrypoint.path.contains("Application Support") == false)
        let restored = try await installer.installedPackage(appID: fixture.parent.appID)
        XCTAssertEqual(restored, installed)
        let locator = HTMLAppOfflinePackageLocator(packagesRoot: root)
        let packageSize = try locator.packageSize(for: installed)
        XCTAssertGreaterThan(packageSize, Int64("<html>v1</html>".utf8.count))
        XCTAssertEqual(try locator.packageSize(for: installed), packageSize)
    }

    func testInstalledPackageLaunchAndResourcesRemainAvailableAfterNetworkDisconnects() async throws {
        let fixture = try makeFixture(version: "1")
        let transport = MemoryTransport(responses: fixture.responses)
        let installer = HTMLAppOfflinePackageInstaller(transport: transport, packagesRoot: root)
        _ = try await installer.install(appManifest: fixture.parent)
        await transport.disconnect()

        let registry = HTMLAppTrustRegistry(storage: MemoryStorage())
        try registry.register(fixture.parent)
        let resolver = HTMLAppLaunchResolver(
            trustRegistry: registry,
            packageLocator: HTMLAppOfflinePackageLocator(packagesRoot: root)
        )
        let target = try resolver.resolve(appID: fixture.parent.appID, route: "/")

        XCTAssertEqual(target.offlineMode, .strong)
        XCTAssertTrue(target.loaderURL.isFileURL)
        XCTAssertEqual(try String(contentsOf: target.loaderURL), "<html>v1</html>")
        let localStyle = target.loaderURL
            .deletingLastPathComponent()
            .appendingPathComponent("assets/style.css")
        XCTAssertEqual(try String(contentsOf: localStyle), "body{}")
    }

    private func trustedParent(
        webManifestURL: URL,
        data: Data,
        drelOffline: DrelOfflinePackageDeclaration? = nil
    ) -> HTMLAppManifest {
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return HTMLAppManifest(
            appID: "com.example.offline",
            name: "Signed Parent",
            startURL: origin.appendingPathComponent("app/index.html").absoluteString,
            allowedOrigins: [origin.absoluteString],
            capabilities: [],
            routes: ["/"],
            cache: HTMLAppCachePolicy(strategy: .networkOnly, version: "1", persistent: false),
            webManifest: HTMLAppWebManifestBinding(url: webManifestURL.absoluteString, sha256: digest),
            drelOffline: drelOffline,
            signature: HTMLAppManifestSignature(algorithm: "ed25519", keyID: "test", value: "test")
        )
    }

    func testInstallsPackageDeclaredThroughDrelOfflineExtension() async throws {
        var fixture = try makeFixture(version: "1")
        let digest = try XCTUnwrap(fixture.parent.cache.resourceManifestSHA256)
        let resourceManifestURL = try XCTUnwrap(fixture.parent.cache.resourceManifestURL)
        fixture.parent = HTMLAppManifest(
            appID: fixture.parent.appID,
            name: fixture.parent.name,
            startURL: fixture.parent.startURL,
            allowedOrigins: fixture.parent.allowedOrigins,
            capabilities: fixture.parent.capabilities,
            routes: fixture.parent.routes,
            cache: HTMLAppCachePolicy(strategy: .manifest, version: "legacy", persistent: true),
            drelOffline: DrelOfflinePackageDeclaration(
                version: fixture.package.version,
                resourceManifestURL: resourceManifestURL,
                resourceManifestSHA256: digest
            ),
            signature: fixture.parent.signature
        )
        let installer = HTMLAppOfflinePackageInstaller(
            transport: MemoryTransport(responses: fixture.responses),
            packagesRoot: root
        )

        let installed = try await installer.install(appManifest: fixture.parent)

        XCTAssertEqual(installed.version, "1")
        let entrypoint = try await installer.entrypointURL(for: installed)
        XCTAssertTrue(FileManager.default.fileExists(atPath: entrypoint.path))
    }

    func testExplicitRemovalClearsTheEntireInstalledPackage() async throws {
        let fixture = try makeFixture(version: "1")
        let installer = HTMLAppOfflinePackageInstaller(
            transport: MemoryTransport(responses: fixture.responses),
            packagesRoot: root
        )

        _ = try await installer.install(appManifest: fixture.parent)
        let initiallyInstalled = try await installer.installedPackage(appID: fixture.parent.appID)
        XCTAssertNotNil(initiallyInstalled)

        let didRemove = try await installer.removeInstalledPackage(appID: fixture.parent.appID)
        XCTAssertTrue(didRemove)
        let removedPackage = try await installer.installedPackage(appID: fixture.parent.appID)
        XCTAssertNil(removedPackage)
        let didRemoveAgain = try await installer.removeInstalledPackage(appID: fixture.parent.appID)
        XCTAssertFalse(didRemoveAgain)
    }

    func testResourceManifestDigestMismatchActivatesNothing() async throws {
        var fixture = try makeFixture(version: "1")
        fixture.parent = parent(version: "1", manifestDigest: String(repeating: "0", count: 64))
        let installer = HTMLAppOfflinePackageInstaller(
            transport: MemoryTransport(responses: fixture.responses),
            packagesRoot: root
        )

        await XCTAssertThrowsErrorAsync(try await installer.install(appManifest: fixture.parent)) {
            XCTAssertEqual($0 as? HTMLAppOfflinePackageError, .resourceManifestDigestMismatch)
        }
        let installed = try await installer.installedPackage(appID: fixture.parent.appID)
        XCTAssertNil(installed)
    }

    func testFileHashFailurePreservesPreviouslyInstalledVersion() async throws {
        let first = try makeFixture(version: "1")
        let transport = MemoryTransport(responses: first.responses)
        let installer = HTMLAppOfflinePackageInstaller(transport: transport, packagesRoot: root)
        _ = try await installer.install(appManifest: first.parent)

        var second = try makeFixture(version: "2")
        let indexURL = origin.appendingPathComponent("v2/index.html")
        second.responses[indexURL] = HTMLAppPackageTransportResponse(data: Data("corrupt".utf8), finalURL: indexURL)
        let secondTransport = MemoryTransport(responses: second.responses)
        let updateInstaller = HTMLAppOfflinePackageInstaller(transport: secondTransport, packagesRoot: root)

        await XCTAssertThrowsErrorAsync(try await updateInstaller.install(appManifest: second.parent)) {
            XCTAssertEqual($0 as? HTMLAppOfflinePackageError, .fileSizeMismatch("index.html"))
        }
        let restored = try await updateInstaller.installedPackage(appID: second.parent.appID)
        XCTAssertEqual(restored?.version, "1")
    }

    func testRejectsTraversalDuplicateCrossOriginAndPackageLimit() async throws {
        let cases: [(HTMLAppOfflinePackageFile, HTMLAppOfflinePackageError)] = [
            (file(path: "../escape", url: origin.appendingPathComponent("escape"), data: Data()), .invalidPath("../escape")),
            (file(path: "/absolute", url: origin.appendingPathComponent("absolute"), data: Data()), .invalidPath("/absolute")),
            (file(path: "foreign.js", url: URL(string: "https://evil.example/foreign.js")!, data: Data()), .disallowedOrigin("https://evil.example/foreign.js")),
            (HTMLAppOfflinePackageFile(path: "huge.bin", url: origin.appendingPathComponent("huge.bin").absoluteString, sha256: digest(Data()), size: 101, mimeType: "application/octet-stream"), .fileTooLarge("huge.bin"))
        ]

        for (badFile, expectedError) in cases {
            let package = HTMLAppOfflinePackageManifest(
                appID: "com.example.offline",
                version: "1",
                entrypoint: badFile.path,
                files: [badFile]
            )
            let data = try JSONEncoder().encode(package)
            let manifestURL = origin.appendingPathComponent("v1/package.json")
            let parent = parent(version: "1", manifestDigest: digest(data))
            let installer = HTMLAppOfflinePackageInstaller(
                transport: MemoryTransport(responses: [manifestURL: .init(data: data, finalURL: manifestURL)]),
                packagesRoot: root,
                limits: HTMLAppOfflinePackageLimits(maximumFileBytes: 100)
            )
            await XCTAssertThrowsErrorAsync(try await installer.install(appManifest: parent)) {
                XCTAssertEqual($0 as? HTMLAppOfflinePackageError, expectedError)
            }
        }

        let duplicate = file(path: "index.html", url: origin.appendingPathComponent("v1/index.html"), data: Data())
        let package = HTMLAppOfflinePackageManifest(
            appID: "com.example.offline", version: "1", entrypoint: "index.html", files: [duplicate, duplicate]
        )
        let data = try JSONEncoder().encode(package)
        let manifestURL = origin.appendingPathComponent("v1/package.json")
        let installer = HTMLAppOfflinePackageInstaller(
            transport: MemoryTransport(responses: [manifestURL: .init(data: data, finalURL: manifestURL)]),
            packagesRoot: root
        )
        await XCTAssertThrowsErrorAsync(try await installer.install(appManifest: parent(version: "1", manifestDigest: digest(data)))) {
            XCTAssertEqual($0 as? HTMLAppOfflinePackageError, .duplicatePath("index.html"))
        }
    }

    func testRejectsRedirectToDifferentOrigin() async throws {
        let fixture = try makeFixture(version: "1")
        var responses = fixture.responses
        let manifestURL = origin.appendingPathComponent("v1/package.json")
        responses[manifestURL] = HTMLAppPackageTransportResponse(
            data: responses[manifestURL]!.data,
            finalURL: URL(string: "https://evil.example/package.json")!
        )
        let installer = HTMLAppOfflinePackageInstaller(transport: MemoryTransport(responses: responses), packagesRoot: root)

        await XCTAssertThrowsErrorAsync(try await installer.install(appManifest: fixture.parent)) {
            XCTAssertEqual($0 as? HTMLAppOfflinePackageError, .disallowedOrigin("https://evil.example/package.json"))
        }
    }

    func testRejectsParentPackageIdentityMismatch() async throws {
        var fixture = try makeFixture(version: "1")
        let bad = HTMLAppOfflinePackageManifest(
            appID: "com.example.other",
            version: "1",
            entrypoint: fixture.package.entrypoint,
            files: fixture.package.files
        )
        let data = try JSONEncoder().encode(bad)
        let url = origin.appendingPathComponent("v1/package.json")
        fixture.responses[url] = .init(data: data, finalURL: url)
        fixture.parent = parent(version: "1", manifestDigest: digest(data))
        let installer = HTMLAppOfflinePackageInstaller(transport: MemoryTransport(responses: fixture.responses), packagesRoot: root)

        await XCTAssertThrowsErrorAsync(try await installer.install(appManifest: fixture.parent)) {
            XCTAssertEqual($0 as? HTMLAppOfflinePackageError, .identityMismatch)
        }
    }

    func testTransportInterruptionPreservesPreviousVersion() async throws {
        let first = try makeFixture(version: "1")
        let firstInstaller = HTMLAppOfflinePackageInstaller(
            transport: MemoryTransport(responses: first.responses),
            packagesRoot: root
        )
        _ = try await firstInstaller.install(appManifest: first.parent)

        let second = try makeFixture(version: "2")
        let styleURL = origin.appendingPathComponent("v2/assets/style.css")
        let interrupted = MemoryTransport(
            responses: second.responses,
            errors: [styleURL: URLError(.networkConnectionLost)]
        )
        let installer = HTMLAppOfflinePackageInstaller(transport: interrupted, packagesRoot: root)

        await XCTAssertThrowsErrorAsync(try await installer.install(appManifest: second.parent)) {
            XCTAssertEqual(($0 as? URLError)?.code, .networkConnectionLost)
        }
        let restored = try await installer.installedPackage(appID: second.parent.appID)
        XCTAssertEqual(restored?.version, "1")
    }

    func testUnwritablePackageRootFailsWithoutActivatingAnything() async throws {
        let fixture = try makeFixture(version: "1")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fileRoot = root.appendingPathComponent("not-a-directory")
        try Data("occupied".utf8).write(to: fileRoot)
        let installer = HTMLAppOfflinePackageInstaller(
            transport: MemoryTransport(responses: fixture.responses),
            packagesRoot: fileRoot
        )

        await XCTAssertThrowsErrorAsync(try await installer.install(appManifest: fixture.parent)) {
            XCTAssertEqual($0 as? HTMLAppOfflinePackageError, .persistenceFailed)
        }
    }

    func testConcurrentInstallsNeverLeavePointerToIncompleteDirectory() async throws {
        let first = try makeFixture(version: "1")
        let second = try makeFixture(version: "2")
        let firstInstaller = HTMLAppOfflinePackageInstaller(
            transport: MemoryTransport(responses: first.responses),
            packagesRoot: root
        )
        let secondInstaller = HTMLAppOfflinePackageInstaller(
            transport: MemoryTransport(responses: second.responses),
            packagesRoot: root
        )

        async let installed1 = firstInstaller.install(appManifest: first.parent)
        async let installed2 = secondInstaller.install(appManifest: second.parent)
        _ = try await (installed1, installed2)

        let locator = HTMLAppOfflinePackageLocator(packagesRoot: root)
        let current = try XCTUnwrap(locator.installedPackage(appID: first.parent.appID))
        XCTAssertTrue(["1", "2"].contains(current.version))
        XCTAssertTrue(FileManager.default.fileExists(atPath: try locator.entrypointURL(for: current).path))
    }

    private struct Fixture {
        var parent: HTMLAppManifest
        var package: HTMLAppOfflinePackageManifest
        var responses: [URL: HTMLAppPackageTransportResponse]
    }

    private func makeFixture(version: String) throws -> Fixture {
        let indexData = Data("<html>v\(version)</html>".utf8)
        let styleData = Data("body{}".utf8)
        let indexURL = origin.appendingPathComponent("v\(version)/index.html")
        let styleURL = origin.appendingPathComponent("v\(version)/assets/style.css")
        let package = HTMLAppOfflinePackageManifest(
            appID: "com.example.offline",
            version: version,
            entrypoint: "index.html",
            files: [
                file(path: "index.html", url: indexURL, data: indexData, mimeType: "text/html"),
                file(path: "assets/style.css", url: styleURL, data: styleData, mimeType: "text/css")
            ]
        )
        let manifestData = try JSONEncoder().encode(package)
        let manifestURL = origin.appendingPathComponent("v\(version)/package.json")
        return Fixture(
            parent: parent(version: version, manifestDigest: digest(manifestData)),
            package: package,
            responses: [
                manifestURL: .init(data: manifestData, finalURL: manifestURL),
                indexURL: .init(data: indexData, finalURL: indexURL),
                styleURL: .init(data: styleData, finalURL: styleURL)
            ]
        )
    }

    private func parent(version: String, manifestDigest: String) -> HTMLAppManifest {
        HTMLAppManifest(
            appID: "com.example.offline",
            name: "Offline Fixture",
            startURL: "https://offline.example.com/index.html",
            allowedOrigins: ["https://offline.example.com"],
            capabilities: [],
            routes: ["/", "/index.html"],
            cache: HTMLAppCachePolicy(
                strategy: .manifest,
                version: version,
                persistent: true,
                resourceManifestURL: "https://offline.example.com/v\(version)/package.json",
                resourceManifestSHA256: manifestDigest
            ),
            signature: HTMLAppManifestSignature(algorithm: "ed25519", keyID: "offline-key", value: "verified-upstream")
        )
    }

    private func file(path: String, url: URL, data: Data, mimeType: String = "application/octet-stream") -> HTMLAppOfflinePackageFile {
        HTMLAppOfflinePackageFile(path: path, url: url.absoluteString, sha256: digest(data), size: Int64(data.count), mimeType: mimeType)
    }

    private func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ errorHandler: (Error) -> Void = { _ in },
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected expression to throw", file: file, line: line)
    } catch {
        errorHandler(error)
    }
}
