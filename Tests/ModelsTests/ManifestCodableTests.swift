//
//  ManifestCodableTests.swift
//  ModelsTests
//

import XCTest
@testable import WebBridgeKit

final class ManifestCodableTests: XCTestCase {

    // MARK: - Codable Round-Trip: All Fields

    func testCodableRoundTripWithAllFields() throws {
        let manifest = Manifest(
            resources: ["index.html": "https://example.com/index.html", "app.js": "https://example.com/app.js"],
            version: "1.5.0",
            persistent: true,
            lastUpdated: Date(),
            appid: "com.example.app",
            name: "TestApp",
            icon: "https://example.com/icon.png",
            isPinned: true,
            isFavorite: true,
            lastAccessed: Date(),
            accessCount: 42
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(manifest)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Manifest.self, from: data)

        XCTAssertEqual(decoded.resources.count, 2)
        XCTAssertEqual(decoded.resources["index.html"], "https://example.com/index.html")
        XCTAssertEqual(decoded.version, "1.5.0")
        XCTAssertEqual(decoded.persistent, true)
        XCTAssertEqual(decoded.appid, "com.example.app")
        XCTAssertEqual(decoded.name, "TestApp")
        XCTAssertEqual(decoded.icon, "https://example.com/icon.png")
        XCTAssertEqual(decoded.isPinned, true)
        XCTAssertEqual(decoded.isFavorite, true)
        XCTAssertEqual(decoded.accessCount, 42)
    }

    // MARK: - Codable Round-Trip: Minimal Fields

    func testCodableRoundTripWithEmptyResources() throws {
        let manifest = Manifest()

        let data = try JSONEncoder().encode(manifest)
        let decoded = try JSONDecoder().decode(Manifest.self, from: data)

        XCTAssertTrue(decoded.resources.isEmpty)
        XCTAssertNil(decoded.version)
        XCTAssertNil(decoded.persistent)
        XCTAssertNil(decoded.lastUpdated)
        XCTAssertNil(decoded.appid)
        XCTAssertNil(decoded.name)
        XCTAssertNil(decoded.icon)
        XCTAssertNil(decoded.isPinned)
        XCTAssertNil(decoded.isFavorite)
        XCTAssertNil(decoded.lastAccessed)
        XCTAssertNil(decoded.accessCount)
    }

    // MARK: - Codable Round-Trip: Partial Optional Fields

    func testCodableRoundTripWithPartialFields() throws {
        let manifest = Manifest(
            resources: ["page.html": "https://example.com/page.html"],
            version: "2.0.0",
            name: "MyApp"
        )

        let data = try JSONEncoder().encode(manifest)
        let decoded = try JSONDecoder().decode(Manifest.self, from: data)

        XCTAssertEqual(decoded.resources.count, 1)
        XCTAssertEqual(decoded.version, "2.0.0")
        XCTAssertEqual(decoded.name, "MyApp")
        XCTAssertNil(decoded.persistent)
        XCTAssertNil(decoded.appid)
        XCTAssertNil(decoded.icon)
    }

    // MARK: - Codable Preserves Specific Values

    func testCodablePreservesVersionAndAppID() throws {
        let manifest = Manifest(
            resources: ["f": "u"],
            version: "1.0.0",
            appid: "com.test"
        )

        let data = try JSONEncoder().encode(manifest)
        let decoded = try JSONDecoder().decode(Manifest.self, from: data)

        XCTAssertEqual(decoded.version, "1.0.0")
        XCTAssertEqual(decoded.appid, "com.test")
    }

    func testCodablePreservesBoolFlags() throws {
        let manifest = Manifest(
            resources: ["f": "u"],
            isPinned: true,
            isFavorite: false,
            persistent: true
        )

        let data = try JSONEncoder().encode(manifest)
        let decoded = try JSONDecoder().decode(Manifest.self, from: data)

        XCTAssertEqual(decoded.isPinned, true)
        XCTAssertEqual(decoded.isFavorite, false)
        XCTAssertEqual(decoded.persistent, true)
    }

    func testCodablePreservesAccessCount() throws {
        let manifest = Manifest(
            resources: ["f": "u"],
            accessCount: 99
        )

        let data = try JSONEncoder().encode(manifest)
        let decoded = try JSONDecoder().decode(Manifest.self, from: data)

        XCTAssertEqual(decoded.accessCount, 99)
    }

    // MARK: - Init with All Parameters

    func testInitWithAllParameters() {
        let now = Date()
        let manifest = Manifest(
            resources: ["a.html": "https://a.com/a"],
            version: "1.2.3",
            persistent: true,
            lastUpdated: now,
            appid: "com.a",
            name: "A",
            icon: "https://a.com/icon.png",
            isPinned: true,
            isFavorite: true,
            lastAccessed: now,
            accessCount: 10
        )

        XCTAssertEqual(manifest.resources.count, 1)
        XCTAssertEqual(manifest.version, "1.2.3")
        XCTAssertTrue(manifest.persistent ?? false)
        XCTAssertEqual(manifest.appid, "com.a")
        XCTAssertEqual(manifest.name, "A")
        XCTAssertEqual(manifest.icon, "https://a.com/icon.png")
        XCTAssertEqual(manifest.isPinned, true)
        XCTAssertEqual(manifest.isFavorite, true)
        XCTAssertEqual(manifest.accessCount, 10)
    }

    // MARK: - Resolved Version

    func testResolvedVersionReturnsVersionWhenSet() {
        let manifest = Manifest(version: "1.5.0")
        XCTAssertEqual(manifest.resolvedVersion, "1.5.0")
    }

    func testResolvedVersionReturnsDefaultWhenNil() {
        let manifest = Manifest()
        XCTAssertEqual(manifest.resolvedVersion, "0.0.1")
    }

    // MARK: - ResourceData Init

    func testResourceDataInit() {
        let data = ResourceData(
            relativePath: "scripts/app.js",
            data: Data("console.log('hi')".utf8),
            mimeType: "application/javascript"
        )
        XCTAssertEqual(data.relativePath, "scripts/app.js")
        XCTAssertEqual(data.data.count, 17)
        XCTAssertEqual(data.mimeType, "application/javascript")
    }
}
