import CryptoKit
import XCTest
@testable import WebBridgeKit

final class HTMLAppOfflinePackageInstallerTests: XCTestCase {
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
