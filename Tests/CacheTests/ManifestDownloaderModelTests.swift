import XCTest
@testable import WebBridgeKit

final class ManifestDownloaderModelTests: XCTestCase {

    func testResourceTypeAllCases() {
        XCTAssertEqual(ResourceType.image.rawValue, "image")
        XCTAssertEqual(ResourceType.stylesheet.rawValue, "stylesheet")
        XCTAssertEqual(ResourceType.script.rawValue, "script")
        XCTAssertEqual(ResourceType.font.rawValue, "font")
        XCTAssertEqual(ResourceType.document.rawValue, "document")
        XCTAssertEqual(ResourceType.audio.rawValue, "audio")
        XCTAssertEqual(ResourceType.video.rawValue, "video")
        XCTAssertEqual(ResourceType.data.rawValue, "data")
        XCTAssertEqual(ResourceType.other.rawValue, "other")
    }

    func testResourceTypeCodableRoundTrip() throws {
        let types: [ResourceType] = [.image, .script, .font, .other]
        for type in types {
            let data = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(ResourceType.self, from: data)
            XCTAssertEqual(decoded, type)
        }
    }

    func testResourceInfoInit() {
        let info = ResourceInfo(
            url: URL(string: "https://example.com/app.js")!,
            type: .script,
            mimeType: "application/javascript",
            size: 1024,
            integrity: "sha256-abc",
            required: true
        )
        XCTAssertEqual(info.url.absoluteString, "https://example.com/app.js")
        XCTAssertEqual(info.type, .script)
        XCTAssertEqual(info.mimeType, "application/javascript")
        XCTAssertEqual(info.size, 1024)
        XCTAssertEqual(info.integrity, "sha256-abc")
        XCTAssertTrue(info.required)
    }

    func testResourceInfoDefaultValues() {
        let info = ResourceInfo(
            url: URL(string: "https://example.com/img.png")!,
            type: .image
        )
        XCTAssertNil(info.mimeType)
        XCTAssertNil(info.size)
        XCTAssertNil(info.integrity)
        XCTAssertFalse(info.required)
    }

    func testResourceInfoCodable() throws {
        let info = ResourceInfo(
            url: URL(string: "https://example.com/app.js")!,
            type: .script,
            mimeType: "application/javascript",
            size: 2048
        )
        let data = try JSONEncoder().encode(info)
        let decoded = try JSONDecoder().decode(ResourceInfo.self, from: data)
        XCTAssertEqual(decoded.url, info.url)
        XCTAssertEqual(decoded.type, .script)
        XCTAssertEqual(decoded.mimeType, "application/javascript")
        XCTAssertEqual(decoded.size, 2048)
    }

    func testResourceInfoDecodingWithStringURL() throws {
        let json = """
        {
            "url": "https://example.com/style.css",
            "type": "stylesheet",
            "mimeType": "text/css",
            "size": 512,
            "integrity": "sha256-xyz",
            "required": false
        }
        """
        let data = json.data(using: .utf8)!
        let info = try JSONDecoder().decode(ResourceInfo.self, from: data)
        XCTAssertEqual(info.url.absoluteString, "https://example.com/style.css")
        XCTAssertEqual(info.type, .stylesheet)
        XCTAssertEqual(info.mimeType, "text/css")
        XCTAssertEqual(info.size, 512)
        XCTAssertEqual(info.integrity, "sha256-xyz")
        XCTAssertFalse(info.required)
    }

    func testResourceInfoDecodingWithStringType() throws {
        let json = """
        {
            "url": "https://example.com/font.woff2",
            "type": "font"
        }
        """
        let data = json.data(using: .utf8)!
        let info = try JSONDecoder().decode(ResourceInfo.self, from: data)
        XCTAssertEqual(info.type, .font)
    }

    func testResourceInfoDecodingUnknownType() throws {
        let json = """
        {
            "url": "https://example.com/data.bin",
            "type": "unknown_type"
        }
        """
        let data = json.data(using: .utf8)!
        let info = try JSONDecoder().decode(ResourceInfo.self, from: data)
        XCTAssertEqual(info.type, .other)
    }

    func testManifestDocumentInit() {
        let manifest = ManifestDocument(
            version: "1.0.0",
            updatedAt: Date(),
            description: "Test manifest",
            resources: [
                "app.js": ResourceInfo(url: URL(string: "https://example.com/app.js")!, type: .script)
            ],
            startURL: "/index.html",
            display: "standalone",
            themeColor: "#ffffff"
        )
        XCTAssertEqual(manifest.version, "1.0.0")
        XCTAssertEqual(manifest.description, "Test manifest")
        XCTAssertEqual(manifest.startURL, "/index.html")
        XCTAssertEqual(manifest.display, "standalone")
        XCTAssertEqual(manifest.themeColor, "#ffffff")
        XCTAssertFalse(manifest.persistent)
        XCTAssertEqual(manifest.resources.count, 1)
    }

    func testManifestDocumentPersistent() {
        let manifest = ManifestDocument(
            version: "2.0.0",
            updatedAt: Date(),
            description: "Persistent",
            persistent: true,
            resources: [:]
        )
        XCTAssertTrue(manifest.persistent)
    }

    func testManifestDocumentCodable() throws {
        let manifest = ManifestDocument(
            version: "1.0.0",
            updatedAt: Date(),
            description: "Test",
            resources: [
                "app.js": ResourceInfo(url: URL(string: "https://example.com/app.js")!, type: .script)
            ]
        )
        let data = try JSONEncoder().encode(manifest)
        let decoded = try JSONDecoder().decode(ManifestDocument.self, from: data)
        XCTAssertEqual(decoded.version, "1.0.0")
        XCTAssertEqual(decoded.description, "Test")
        XCTAssertEqual(decoded.resources.count, 1)
    }

    func testManifestDocumentDecodingWithTimestampDate() throws {
        let timestamp = Date().timeIntervalSince1970
        let json = """
        {
            "version": "1.0.0",
            "updatedAt": \(timestamp),
            "description": "Test",
            "resources": {}
        }
        """
        let data = json.data(using: .utf8)!
        let manifest = try JSONDecoder().decode(ManifestDocument.self, from: data)
        XCTAssertEqual(manifest.version, "1.0.0")
    }

    func testManifestDownloaderErrorDescriptions() {
        let errors: [ManifestDownloaderError] = [
            .invalidURL("https://bad.url"),
            .networkError(NSError(domain: "test", code: -1)),
            .invalidJSON(NSError(domain: "test", code: -2)),
            .missingRequiredField("version"),
            .emptyResponse,
            .invalidResourceURL("bad"),
            .validationFailed(["error1", "error2"])
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
        }
    }
}
