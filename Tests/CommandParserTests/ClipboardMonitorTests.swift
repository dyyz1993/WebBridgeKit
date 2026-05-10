import XCTest
@testable import WebBridgeKit

final class ClipboardMonitorTests: XCTestCase {

    // MARK: - Singleton

    func testSharedIsSingleton() {
        let a = ClipboardMonitor.shared
        let b = ClipboardMonitor.shared
        XCTAssertTrue(a === b)
    }

    // MARK: - looksLikeCommand - Command Prefix

    func testLooksLikeCommand_withCommandPrefix_returnsTrue() {
        let result = ClipboardMonitor.shared.looksLikeCommand("【WebBridgeKit】some payload")
        XCTAssertTrue(result)
    }

    func testLooksLikeCommand_withOnlyCommandPrefix_returnsTrue() {
        let result = ClipboardMonitor.shared.looksLikeCommand("【WebBridgeKit】")
        XCTAssertTrue(result)
    }

    // MARK: - looksLikeCommand - URL Scheme Prefix

    func testLooksLikeCommand_withUrlSchemePrefixLowercase_returnsTrue() {
        let result = ClipboardMonitor.shared.looksLikeCommand("wbsk://command?action=open")
        XCTAssertTrue(result)
    }

    func testLooksLikeCommand_withUrlSchemePrefixUppercase_returnsTrue() {
        let result = ClipboardMonitor.shared.looksLikeCommand("WBSK://COMMAND?action=open")
        XCTAssertTrue(result)
    }

    func testLooksLikeCommand_withUrlSchemePrefixMixedCase_returnsTrue() {
        let result = ClipboardMonitor.shared.looksLikeCommand("Wbsk://Command?action=open")
        XCTAssertTrue(result)
    }

    func testLooksLikeCommand_withOnlyUrlSchemePrefix_returnsTrue() {
        let result = ClipboardMonitor.shared.looksLikeCommand("wbsk://command")
        XCTAssertTrue(result)
    }

    // MARK: - looksLikeCommand - Base64

    func testLooksLikeCommand_withValidBase64String_returnsTrue() {
        let base64 = "SGVsbG8gV29ybGQgV2ViQnJpZGdlS2l0"
        let result = ClipboardMonitor.shared.looksLikeCommand(base64)
        XCTAssertTrue(result)
    }

    func testLooksLikeCommand_withBase64Exactly16Chars_returnsTrue() {
        let base64 = "ABCDEFGHIJKLMNOP"
        let result = ClipboardMonitor.shared.looksLikeCommand(base64)
        XCTAssertTrue(result)
    }

    func testLooksLikeCommand_withBase64WithPadding_returnsTrue() {
        let base64 = "SGVsbG8gV29ybGQgV2ViQnJpZGdlS2l0=="
        let result = ClipboardMonitor.shared.looksLikeCommand(base64)
        XCTAssertTrue(result)
    }

    func testLooksLikeCommand_withBase15Chars_returnsFalse() {
        let text = "ABCDEFGHIJKLMNO"
        let result = ClipboardMonitor.shared.looksLikeCommand(text)
        XCTAssertFalse(result)
    }

    // MARK: - looksLikeCommand - Negative Cases

    func testLooksLikeCommand_emptyString_returnsFalse() {
        let result = ClipboardMonitor.shared.looksLikeCommand("")
        XCTAssertFalse(result)
    }

    func testLooksLikeCommand_whitespaceOnly_returnsFalse() {
        let result = ClipboardMonitor.shared.looksLikeCommand("   \t\n  ")
        XCTAssertFalse(result)
    }

    func testLooksLikeCommand_plainText_returnsFalse() {
        let result = ClipboardMonitor.shared.looksLikeCommand("Hello, this is normal text")
        XCTAssertFalse(result)
    }

    func testLooksLikeCommand_shortText_returnsFalse() {
        let result = ClipboardMonitor.shared.looksLikeCommand("hi")
        XCTAssertFalse(result)
    }

    func testLooksLikeCommand_commandPrefixWithLeadingWhitespace_returnsTrue() {
        let result = ClipboardMonitor.shared.looksLikeCommand("  【WebBridgeKit】data")
        XCTAssertTrue(result)
    }

    func testLooksLikeCommand_urlSchemeWithLeadingWhitespace_returnsTrue() {
        let result = ClipboardMonitor.shared.looksLikeCommand("\twbsk://command")
        XCTAssertTrue(result)
    }

    // MARK: - clearLastClipboardHash

    func testClearLastClipboardHash_doesNotCrash() {
        ClipboardMonitor.shared.clearLastClipboardHash()
    }
}
