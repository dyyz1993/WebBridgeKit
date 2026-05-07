//
//  ManifestErrorExtraTests.swift
//  ModelsTests
//

import XCTest
@testable import WebBridgeKit

final class ManifestErrorExtraTests: XCTestCase {

    // MARK: - ManifestError invalidResourceType

    func testInvalidResourceTypeDescription() {
        let error = ManifestError.invalidResourceType("weird")
        XCTAssertTrue(error.description.contains("weird"))
    }

    // MARK: - ManifestError failureReason

    func testFailureReasonInvalidFormat() {
        let error = ManifestError.invalidFormat("bad JSON")
        XCTAssertNotNil(error.failureReason)
        XCTAssertTrue(error.failureReason?.contains("structure") ?? false)
    }

    func testFailureReasonMissingRequiredField() {
        let error = ManifestError.missingRequiredField("resources")
        XCTAssertNotNil(error.failureReason)
        XCTAssertTrue(error.failureReason?.contains("missing") ?? false)
    }

    func testFailureReasonUnsupportedVersion() {
        let error = ManifestError.unsupportedVersion("3.0.0")
        XCTAssertNotNil(error.failureReason)
        XCTAssertTrue(error.failureReason?.contains("not supported") ?? false)
    }

    func testFailureReasonInvalidResourcePath() {
        let error = ManifestError.invalidResourcePath("/etc/passwd")
        XCTAssertNotNil(error.failureReason)
        XCTAssertTrue(error.failureReason?.contains("unsafe") ?? false)
    }

    func testFailureReasonInvalidResourceType() {
        let error = ManifestError.invalidResourceType("exe")
        XCTAssertNotNil(error.failureReason)
        XCTAssertTrue(error.failureReason?.contains("not recognized") ?? false)
    }

    func testFailureReasonCorruptedData() {
        let error = ManifestError.corruptedData
        XCTAssertNotNil(error.failureReason)
        XCTAssertTrue(error.failureReason?.contains("corruption") ?? false)
    }

    // MARK: - ManifestError recoverySuggestion

    func testRecoverySuggestionInvalidFormat() {
        let error = ManifestError.invalidFormat("test")
        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testRecoverySuggestionMissingRequiredField() {
        let error = ManifestError.missingRequiredField("name")
        let suggestion = error.recoverySuggestion
        XCTAssertTrue(suggestion?.contains("name") ?? false)
    }

    func testRecoverySuggestionUnsupportedVersion() {
        let error = ManifestError.unsupportedVersion("5.0")
        let suggestion = error.recoverySuggestion
        XCTAssertTrue(suggestion?.contains("5.0") ?? false)
    }

    func testRecoverySuggestionInvalidResourcePath() {
        let error = ManifestError.invalidResourcePath("../secret/file")
        let suggestion = error.recoverySuggestion
        XCTAssertTrue(suggestion?.contains("../secret/file") ?? false)
    }

    func testRecoverySuggestionInvalidResourceType() {
        let error = ManifestError.invalidResourceType("exe")
        let suggestion = error.recoverySuggestion
        XCTAssertTrue(suggestion?.contains("exe") ?? false)
    }

    func testRecoverySuggestionCorruptedData() {
        let error = ManifestError.corruptedData
        XCTAssertNotNil(error.recoverySuggestion)
    }

    // MARK: - errorDescription matches description

    func testErrorDescriptionMatchesDescriptionForAllCases() {
        let cases: [ManifestError] = [
            .invalidFormat("f"),
            .missingRequiredField("f"),
            .unsupportedVersion("v"),
            .invalidResourcePath("p"),
            .invalidResourceType("t"),
            .corruptedData
        ]
        for error in cases {
            XCTAssertEqual(error.errorDescription, error.description)
        }
    }

    // MARK: - ManifestVersion Static Properties

    func testMinimumSupportedVersion() {
        XCTAssertEqual(ManifestVersion.minimumSupported, "1.0.0")
    }

    func testMaximumSupportedVersion() {
        XCTAssertEqual(ManifestVersion.maximumSupported, "2.0.0")
    }

    func testCurrentFormat() {
        XCTAssertEqual(ManifestVersion.currentFormat, "2.0")
    }

    // MARK: - ManifestVersion Boundary Tests

    func testIsSupportedAtMinimumBoundary() {
        XCTAssertTrue(ManifestVersion.isSupported("1.0.0"))
    }

    func testIsSupportedAtMaximumBoundary() {
        XCTAssertTrue(ManifestVersion.isSupported("2.0.0"))
    }

    func testIsSupportedBelowMinimum() {
        XCTAssertFalse(ManifestVersion.isSupported("0.9.9"))
    }

    func testIsSupportedAboveMaximum() {
        XCTAssertFalse(ManifestVersion.isSupported("2.0.1"))
    }

    func testIsSupportedThreePartVersion() {
        XCTAssertTrue(ManifestVersion.isSupported("1.5.3"))
    }

    // MARK: - ManifestValidationResult with Multiple Items

    func testInvalidWithMultipleErrors() {
        let result = ManifestValidationResult.invalid(
            [.missingRequiredField("name"), .invalidFormat("bad")],
            warnings: ["warning1"]
        )
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errors.count, 2)
        XCTAssertEqual(result.warnings.count, 1)
    }

    func testValidWithMultipleWarnings() {
        let result = ManifestValidationResult.validWithWarnings(["w1", "w2", "w3"])
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.warnings.count, 3)
        XCTAssertTrue(result.errors.isEmpty)
    }

    // MARK: - ManifestError conforms to Error

    func testManifestErrorConformsToLocalizedError() {
        let error: LocalizedError = ManifestError.corruptedData
        XCTAssertNotNil(error.errorDescription)
        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertNotNil(error.failureReason)
    }

    func testManifestErrorWithEmptyStringParams() {
        let error = ManifestError.invalidFormat("")
        XCTAssertNotNil(error.description)
        XCTAssertNotNil(error.recoverySuggestion)
    }
}
