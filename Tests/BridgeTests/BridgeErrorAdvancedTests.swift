import XCTest
@testable import WebBridgeKit

final class BridgeErrorAdvancedTests: XCTestCase {

    func testPermissionDeniedSuggestionContainsPermissionName() {
        let error = BridgeError.permissionDenied(action: "camera", permission: "camera")
        XCTAssertTrue(error.suggestion.contains("camera"))
    }

    func testParameterInvalidSuggestionContainsParameterName() {
        let error = BridgeError.parameterInvalid(action: "scan", param: "format", reason: "unsupported")
        XCTAssertTrue(error.suggestion.contains("format"))
    }

    func testHardwareUnavailableSuggestionContainsReason() {
        let error = BridgeError.hardwareUnavailable(action: "nfc", reason: "No NFC chip")
        XCTAssertTrue(error.suggestion.contains("No NFC chip"))
    }

    func testNotSupportedSuggestionContainsReason() {
        let error = BridgeError.notSupported(action: "ar", reason: "ARKit not available")
        XCTAssertTrue(error.suggestion.contains("ARKit not available"))
    }

    func testExecutionFailedSuggestionContainsUnderlyingErrorMessage() {
        let underlying = NSError(domain: "test", code: 500, userInfo: [NSLocalizedDescriptionKey: "Connection refused"])
        let error = BridgeError.executionFailed(action: "upload", underlyingError: underlying)
        XCTAssertTrue(error.suggestion.contains("Connection refused"))
    }

    func testNotRegisteredSuggestionContainsActionName() {
        let error = BridgeError.notRegistered(action: "myCustomAction")
        XCTAssertTrue(error.suggestion.contains("myCustomAction"))
    }

    func testJSErrorDictContainsSuccessFalseForAllErrorTypes() {
        let errors: [BridgeError] = [
            .permissionDenied(action: "a", permission: "p"),
            .parameterInvalid(action: "a", param: "p", reason: "r"),
            .hardwareUnavailable(action: "a", reason: "r"),
            .timeout(action: "a", seconds: 5),
            .cancelled(action: "a"),
            .notSupported(action: "a", reason: "r"),
            .executionFailed(action: "a", underlyingError: NSError(domain: "t", code: 1)),
            .notRegistered(action: "a")
        ]

        for error in errors {
            let dict = error.jsErrorDict
            XCTAssertEqual(dict["success"] as? Bool, false,
                           "\(error.errorCode) jsErrorDict should have success=false")
        }
    }

    func testJSErrorDictErrorSubdictHasAllRequiredKeys() {
        let errors: [BridgeError] = [
            .permissionDenied(action: "a", permission: "p"),
            .timeout(action: "a", seconds: 10),
            .notRegistered(action: "unknown")
        ]

        for error in errors {
            let dict = error.jsErrorDict
            guard let errorDict = dict["error"] as? [String: Any] else {
                XCTFail("\(error.errorCode) jsErrorDict should have 'error' subdict")
                continue
            }

            XCTAssertNotNil(errorDict["code"], "\(error.errorCode) error dict must have 'code'")
            XCTAssertNotNil(errorDict["action"], "\(error.errorCode) error dict must have 'action'")
            XCTAssertNotNil(errorDict["message"], "\(error.errorCode) error dict must have 'message'")
            XCTAssertNotNil(errorDict["suggestion"], "\(error.errorCode) error dict must have 'suggestion'")
        }
    }

    func testDebugInfoContainsAllRequiredSections() {
        let error = BridgeError.timeout(action: "fetchData", seconds: 15)
        let debug = error.debugInfo

        XCTAssertTrue(debug.contains("BridgeError:"))
        XCTAssertTrue(debug.contains("TIMEOUT"))
        XCTAssertTrue(debug.contains("Action: fetchData"))
        XCTAssertTrue(debug.contains("Message:"))
        XCTAssertTrue(debug.contains("Suggestion:"))
    }

    func testTimeoutErrorDescriptionContainsFormattedSeconds() {
        let error = BridgeError.timeout(action: "test", seconds: 0.5)
        XCTAssertTrue(error.errorDescription?.contains("0.5s") ?? false)

        let error2 = BridgeError.timeout(action: "test", seconds: 99.999)
        XCTAssertTrue(error2.errorDescription?.contains("100.0s") ?? false)
    }

    func testExecutionFailedPreservesUnderlyingErrorDescription() {
        let underlying = NSError(domain: "network", code: -1009, userInfo: [
            NSLocalizedDescriptionKey: "The Internet connection appears to be offline."
        ])
        let error = BridgeError.executionFailed(action: "sync", underlyingError: underlying)

        XCTAssertTrue(error.errorDescription?.contains("The Internet connection appears to be offline.") ?? false)
    }

    func testAllErrorsAreEquatableByErrorCode() {
        let error1 = BridgeError.permissionDenied(action: "a", permission: "p")
        let error2 = BridgeError.permissionDenied(action: "b", permission: "q")
        XCTAssertEqual(error1.errorCode, error2.errorCode)

        let differentError = BridgeError.timeout(action: "a", seconds: 1)
        XCTAssertNotEqual(error1.errorCode, differentError.errorCode)
    }

    func testErrorDescriptionWithSpecialCharacters() {
        let error = BridgeError.parameterInvalid(action: "test-action", param: "key=value", reason: "contains 'quotes' & symbols")
        let desc = error.errorDescription
        XCTAssertNotNil(desc)
        XCTAssertFalse(desc?.isEmpty ?? true)
    }

    func testCancelledSuggestion() {
        let error = BridgeError.cancelled(action: "operation")
        XCTAssertTrue(error.suggestion.contains("cancelled"))
    }

    func testTimeoutSuggestion() {
        let error = BridgeError.timeout(action: "request", seconds: 30)
        XCTAssertTrue(error.suggestion.contains("timeout"))
    }
}
