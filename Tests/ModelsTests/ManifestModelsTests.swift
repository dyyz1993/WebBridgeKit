//
//  ManifestModelsTests.swift
//  ModelsTests
//

import XCTest
@testable import WebBridgeKit

final class ManifestModelsTests: XCTestCase {

    // MARK: - Manifest Initialization

    func testManifestDefaultInit() {
        let manifest = Manifest()
        XCTAssertTrue(manifest.resources.isEmpty)
        XCTAssertNil(manifest.version)
        XCTAssertEqual(manifest.resolvedVersion, "0.0.1")
    }

    func testManifestCustomInit() {
        let manifest = Manifest(
            resources: ["index.html": "https://example.com/index.html"],
            version: "1.0.0",
            persistent: true,
            appid: "com.test.app",
            name: "TestApp"
        )
        XCTAssertEqual(manifest.resources.count, 1)
        XCTAssertEqual(manifest.version, "1.0.0")
        XCTAssertEqual(manifest.resolvedVersion, "1.0.0")
        XCTAssertEqual(manifest.appid, "com.test.app")
        XCTAssertEqual(manifest.name, "TestApp")
    }

    // MARK: - Manifest Validation

    func testValidateEmptyResourcesReturnsInvalid() {
        let manifest = Manifest()
        let result = manifest.validate()
        XCTAssertFalse(result.isValid)
        XCTAssertFalse(result.errors.isEmpty)
    }

    func testValidateValidManifest() {
        let manifest = Manifest(
            resources: ["index.html": "https://example.com/index.html"],
            version: "1.0.0"
        )
        let result = manifest.validate()
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testValidateDetectsPathTraversal() {
        let manifest = Manifest(
            resources: ["../secret/file": "https://example.com/file"]
        )
        let result = manifest.validate()
        XCTAssertFalse(result.isValid)
    }

    func testValidateDetectsAbsolutePath() {
        let manifest = Manifest(
            resources: ["/absolute/path": "https://example.com/file"]
        )
        let result = manifest.validate()
        XCTAssertFalse(result.isValid)
    }

    func testValidateDetectsNullBytes() {
        let manifest = Manifest(
            resources: ["bad\0path": "https://example.com/file"]
        )
        let result = manifest.validate()
        XCTAssertFalse(result.isValid)
    }

    func testValidateDetectsInvalidURL() {
        let manifest = Manifest(
            resources: ["file": "ftp://unsupported.com/file"]
        )
        let result = manifest.validate()
        XCTAssertFalse(result.isValid)
    }

    func testValidateWarnsOnEmptyName() {
        let manifest = Manifest(
            resources: ["index.html": "https://example.com"],
            name: ""
        )
        let result = manifest.validate()
        XCTAssertTrue(result.warnings.contains(where: { $0.contains("empty") }))
    }

    func testValidateWarnsOnMissingVersion() {
        let manifest = Manifest(
            resources: ["index.html": "https://example.com"]
        )
        let result = manifest.validate()
        XCTAssertTrue(result.warnings.contains(where: { $0.contains("version") }))
    }

    func testValidateDetectsInvalidAppID() {
        let manifest = Manifest(
            resources: ["index.html": "https://example.com"],
            appid: "invalid app!@#"
        )
        let result = manifest.validate()
        XCTAssertFalse(result.isValid)
    }

    func testValidateDetectsUnsupportedVersion() {
        let manifest = Manifest(
            resources: ["index.html": "https://example.com"],
            version: "0.0.1"
        )
        let result = manifest.validate()
        XCTAssertFalse(result.isValid)
    }

    // MARK: - isExpired

    func testIsExpiredReturnsTrueWhenNoLastUpdated() {
        let manifest = Manifest()
        XCTAssertTrue(manifest.isExpired())
    }

    func testIsExpiredReturnsFalseForRecentUpdate() {
        let manifest = Manifest(lastUpdated: Date())
        XCTAssertFalse(manifest.isExpired())
    }

    func testIsExpiredReturnsTrueForOldUpdate() {
        let oldDate = Date().addingTimeInterval(-31 * 24 * 60 * 60)
        let manifest = Manifest(lastUpdated: oldDate)
        XCTAssertTrue(manifest.isExpired())
    }

    func testIsExpiredCustomDays() {
        let recentButOld = Date().addingTimeInterval(-2 * 24 * 60 * 60)
        let manifest = Manifest(lastUpdated: recentButOld)
        XCTAssertTrue(manifest.isExpired(expirationDays: 1))
        XCTAssertFalse(manifest.isExpired(expirationDays: 3))
    }

    // MARK: - AppIDResolver

    func testResolveAppIDFromConfiguredAppID() {
        let url = URL(string: "https://example.com")!
        let result = AppIDResolver.resolveAppID(from: "com.test.app", url: url)
        XCTAssertTrue(result.contains("com"))
    }

    func testResolveAppIDFromURLHost() {
        let url = URL(string: "https://www.example.com")!
        let result = AppIDResolver.resolveAppID(from: nil, url: url)
        XCTAssertTrue(result.contains("example"))
    }

    func testExtractAppIDFromURL() {
        let url = URL(string: "https://example.com")!
        let result = AppIDResolver.extractAppID(from: url)
        XCTAssertEqual(result, "example_com")
    }

    func testExtractAppIDFromURLWithoutHost() {
        let url = URL(string: "data:text/html,hello")!
        let result = AppIDResolver.extractAppID(from: url)
        XCTAssertEqual(result, "unknown")
    }

    func testValidateAndSanitizeAppIDRemovesSpecialChars() {
        let result = AppIDResolver.validateAndSanitizeAppID("my app!@#123")
        XCTAssertEqual(result, "myapp123")
    }

    func testValidateAndSanitizeAppIDEmptyReturnsInvalid() {
        let result = AppIDResolver.validateAndSanitizeAppID("!@#$")
        XCTAssertEqual(result, "invalid")
    }

    func testResolveAppIDFromURLAndManifest() {
        let url = URL(string: "https://example.com/page")!
        let manifest = Manifest(appid: "my.app")
        let result = AppIDResolver.resolveAppID(from: url, manifest: manifest)
        XCTAssertTrue(result.contains("my"))
    }

    func testResolveAppIDFallbackToURL() {
        let url = URL(string: "https://example.com/page")!
        let result = AppIDResolver.resolveAppID(from: url, manifest: nil)
        XCTAssertTrue(result.contains("example"))
    }

    // MARK: - extractTitle

    func testExtractTitleFromHTML() {
        let html = "<html><head><title>My Page</title></head><body></body></html>"
        let title = AppIDResolver.extractTitle(from: html)
        XCTAssertEqual(title, "My Page")
    }

    func testExtractTitleFromHTMLWithWhitespace() {
        let html = "<html><head><title>  Spaced Title  </title></head></html>"
        let title = AppIDResolver.extractTitle(from: html)
        XCTAssertEqual(title, "Spaced Title")
    }

    func testExtractTitleReturnsNilForMissingTitle() {
        let html = "<html><head></head><body></body></html>"
        let title = AppIDResolver.extractTitle(from: html)
        XCTAssertNil(title)
    }

    func testExtractTitleDecodesHTMLEntities() {
        let html = "<html><head><title>A &amp; B &lt; C</title></head></html>"
        let title = AppIDResolver.extractTitle(from: html)
        XCTAssertEqual(title, "A & B < C")
    }

    // MARK: - ManifestVersion

    func testManifestVersionSupported() {
        XCTAssertTrue(ManifestVersion.isSupported("1.0.0"))
        XCTAssertTrue(ManifestVersion.isSupported("2.0.0"))
        XCTAssertTrue(ManifestVersion.isSupported("1.5.0"))
    }

    func testManifestVersionUnsupported() {
        XCTAssertFalse(ManifestVersion.isSupported("0.0.9"))
        XCTAssertFalse(ManifestVersion.isSupported("3.0.0"))
    }

    // MARK: - ManifestValidationResult

    func testValidationResultValid() {
        let result = ManifestValidationResult.valid()
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertTrue(result.warnings.isEmpty)
    }

    func testValidationResultInvalid() {
        let result = ManifestValidationResult.invalid([.corruptedData])
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errors.count, 1)
    }

    func testValidationResultValidWithWarnings() {
        let result = ManifestValidationResult.validWithWarnings(["warning1"])
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.warnings.count, 1)
    }

    // MARK: - ManifestError

    func testManifestErrorDescriptions() {
        XCTAssertFalse(ManifestError.invalidFormat("test").description.isEmpty)
        XCTAssertFalse(ManifestError.missingRequiredField("field").description.isEmpty)
        XCTAssertFalse(ManifestError.unsupportedVersion("0.0.1").description.isEmpty)
        XCTAssertFalse(ManifestError.corruptedData.description.isEmpty)
    }

    func testManifestErrorRecoverySuggestions() {
        XCTAssertNotNil(ManifestError.invalidFormat("x").recoverySuggestion)
        XCTAssertNotNil(ManifestError.corruptedData.recoverySuggestion)
    }

    func testManifestErrorFactoryMethods() {
        let pathError = ManifestError.pathTraversalDetected(in: "../secret")
        XCTAssertTrue(pathError.description.contains("../secret"))

        let missingError = ManifestError.missingResource(at: "index.html")
        XCTAssertTrue(missingError.description.contains("index.html"))

        let versionError = ManifestError.versionIncompatibility(current: "1.0.0", required: "2.0.0")
        XCTAssertTrue(versionError.description.contains("1.0.0"))
    }

    // MARK: - ResourceData

    func testResourceDataInit() {
        let data = ResourceData(relativePath: "style.css", data: Data("body{}".utf8), mimeType: "text/css")
        XCTAssertEqual(data.relativePath, "style.css")
        XCTAssertEqual(data.mimeType, "text/css")
        XCTAssertEqual(data.data.count, 6)
    }

    // MARK: - ManifestCacheError

    func testManifestCacheErrorDescriptions() {
        XCTAssertFalse(ManifestCacheError.managerDeallocated.errorDescription?.isEmpty ?? true)
        XCTAssertFalse(ManifestCacheError.resourceNotFound("file").errorDescription?.isEmpty ?? true)
        XCTAssertFalse(ManifestCacheError.emptyData.errorDescription?.isEmpty ?? true)
        XCTAssertFalse(ManifestCacheError.invalidURL.errorDescription?.isEmpty ?? true)
    }
}
