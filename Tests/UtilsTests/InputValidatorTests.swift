//
//  InputValidatorTests.swift
//  UtilsTests
//

import XCTest
import CryptoKit
@testable import WebBridgeKit

final class InputValidatorTests: XCTestCase {

    // MARK: - validateHTMLName

    func testValidateHTMLNameValid() throws {
        let result = try InputValidator.validateHTMLName("index")
        XCTAssertEqual(result, "index")
    }

    func testValidateHTMLNameEmptyThrows() {
        XCTAssertThrowsError(try InputValidator.validateHTMLName("")) { error in
            XCTAssertTrue(error is ValidationError)
        }
    }

    func testValidateHTMLNameExceedsMaxLengthThrows() {
        let longName = String(repeating: "a", count: 256)
        XCTAssertThrowsError(try InputValidator.validateHTMLName(longName)) { error in
            XCTAssertTrue(error is ValidationError)
        }
    }

    func testValidateHTMLNameAtMaxLengthSucceeds() throws {
        let name = String(repeating: "a", count: 255)
        let result = try InputValidator.validateHTMLName(name)
        XCTAssertEqual(result, name)
    }

    func testValidateHTMLNamePathTraversalThrows() {
        XCTAssertThrowsError(try InputValidator.validateHTMLName("..hidden"))
    }

    func testValidateHTMLNameBackslashThrows() {
        XCTAssertThrowsError(try InputValidator.validateHTMLName("dir\\file"))
    }

    func testValidateHTMLNameColonThrows() {
        XCTAssertThrowsError(try InputValidator.validateHTMLName("C:drive"))
    }

    func testValidateHTMLNameDotAloneAllowed() throws {
        let result = try InputValidator.validateHTMLName("start.")
        XCTAssertEqual(result, "start.")
    }

    // MARK: - validateURLScheme

    func testValidateURLSchemeHTTPSucceeds() throws {
        let url = URL(string: "https://example.com")!
        XCTAssertNoThrow(try InputValidator.validateURLScheme(url, allowedSchemes: ["http", "https"]))
    }

    func testValidateURLSchemeFTPFails() {
        let url = URL(string: "ftp://example.com")!
        XCTAssertThrowsError(try InputValidator.validateURLScheme(url, allowedSchemes: ["http", "https"]))
    }

    func testValidateURLSchemeCaseInsensitive() throws {
        let url = URL(string: "HTTPS://example.com")!
        XCTAssertNoThrow(try InputValidator.validateURLScheme(url, allowedSchemes: ["https"]))
    }

    func testValidateURLSchemeNoSchemeFails() {
        let url = URL(string: "example.com")!
        XCTAssertThrowsError(try InputValidator.validateURLScheme(url, allowedSchemes: ["https"]))
    }

    // MARK: - validateResourcePath

    func testValidateResourcePathValid() throws {
        XCTAssertNoThrow(try InputValidator.validateResourcePath("styles/main.css"))
    }

    func testValidateResourcePathEmptyThrows() {
        XCTAssertThrowsError(try InputValidator.validateResourcePath(""))
    }

    func testValidateResourcePathTraversalThrows() {
        XCTAssertThrowsError(try InputValidator.validateResourcePath("../etc/passwd"))
    }

    func testValidateResourcePathAbsoluteThrows() {
        XCTAssertThrowsError(try InputValidator.validateResourcePath("/absolute/path"))
    }

    func testValidateResourcePathNullBytesThrows() {
        XCTAssertThrowsError(try InputValidator.validateResourcePath("file\0name"))
    }

    func testValidateResourcePathTooLongThrows() {
        let longPath = String(repeating: "a", count: 256)
        XCTAssertThrowsError(try InputValidator.validateResourcePath(longPath))
    }

    func testValidateResourcePathMaxLengthSucceeds() throws {
        let path = String(repeating: "a", count: 255)
        XCTAssertNoThrow(try InputValidator.validateResourcePath(path))
    }

    // MARK: - validateManifestResources

    func testValidateManifestResourcesValid() throws {
        let resources = ["index.html": "https://example.com/index.html"]
        XCTAssertNoThrow(try InputValidator.validateManifestResources(resources))
    }

    func testValidateManifestResourcesDataURLAllowed() throws {
        let resources = ["inline": "data:text/html,<h1>Hi</h1>"]
        XCTAssertNoThrow(try InputValidator.validateManifestResources(resources, allowDataScheme: true))
    }

    func testValidateManifestResourcesDataURLDisallowed() {
        let resources = ["inline": "data:text/html,<h1>Hi</h1>"]
        XCTAssertThrowsError(try InputValidator.validateManifestResources(resources, allowDataScheme: false))
    }

    func testValidateManifestResourcesMalformedURLThrows() {
        let resources = ["bad": "not a url with spaces"]
        XCTAssertThrowsError(try InputValidator.validateManifestResources(resources))
    }

    func testValidateManifestResourcesPathTraversalThrows() {
        let resources = ["../secret": "https://example.com/file"]
        XCTAssertThrowsError(try InputValidator.validateManifestResources(resources))
    }

    // MARK: - validateManifestVersion

    func testValidateManifestVersionValid() {
        XCTAssertTrue(InputValidator.validateManifestVersion("1.0.0"))
    }

    func testValidateManifestVersionEmpty() {
        XCTAssertFalse(InputValidator.validateManifestVersion(""))
    }

    func testValidateManifestVersionInvalidFormat() {
        XCTAssertFalse(InputValidator.validateManifestVersion("1.0"))
        XCTAssertFalse(InputValidator.validateManifestVersion("v1.0.0"))
        XCTAssertFalse(InputValidator.validateManifestVersion("abc"))
    }

    func testValidateManifestVersionOutOfRange() {
        XCTAssertFalse(InputValidator.validateManifestVersion("0.0.1"))
        XCTAssertFalse(InputValidator.validateManifestVersion("3.0.0"))
    }

    // MARK: - validateResourceIntegrity

    func testValidateResourceIntegrityCorrectSHA256() {
        let data = Data("Hello, World!".utf8)
        let checksum = data.sha256Hex()
        XCTAssertTrue(InputValidator.validateResourceIntegrity(data: data, expectedChecksum: checksum))
    }

    func testValidateResourceIntegrityIncorrectChecksum() {
        let data = Data("Hello, World!".utf8)
        XCTAssertFalse(InputValidator.validateResourceIntegrity(data: data, expectedChecksum: "wrong"))
    }

    func testValidateResourceIntegrityEmptyChecksumFails() {
        let data = Data("Hello, World!".utf8)
        XCTAssertFalse(InputValidator.validateResourceIntegrity(data: data, expectedChecksum: ""))
    }

    func testValidateResourceIntegrityCaseInsensitive() {
        let data = Data("test".utf8)
        let upper = data.sha256Hex().uppercased()
        XCTAssertTrue(InputValidator.validateResourceIntegrity(data: data, expectedChecksum: upper))
    }

    // MARK: - HashAlgorithm

    func testHashAlgorithmSHA256ProducesCorrectLength() {
        let data = Data("test".utf8)
        let hash = HashAlgorithm.sha256.hash(data: data)
        XCTAssertEqual(hash.count, 64)
    }

    func testHashAlgorithmSHA384ProducesCorrectLength() {
        let data = Data("test".utf8)
        let hash = HashAlgorithm.sha384.hash(data: data)
        XCTAssertEqual(hash.count, 96)
    }

    func testHashAlgorithmSHA512ProducesCorrectLength() {
        let data = Data("test".utf8)
        let hash = HashAlgorithm.sha512.hash(data: data)
        XCTAssertEqual(hash.count, 128)
    }

    func testHashAlgorithmMD5ProducesCorrectLength() {
        let data = Data("test".utf8)
        let hash = HashAlgorithm.md5.hash(data: data)
        XCTAssertEqual(hash.count, 32)
    }

    // MARK: - ValidationError

    func testValidationErrorDescription() {
        let error = ValidationError.invalidInput("test message")
        XCTAssertEqual(error.errorDescription, "test message")
    }
}

private extension Data {
    func sha256Hex() -> String {
        let digest = CryptoKit.SHA256.hash(data: self)
        return Data(digest).map { String(format: "%02x", $0) }.joined()
    }
}
