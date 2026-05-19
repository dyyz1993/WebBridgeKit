import XCTest
@testable import WebBridgeKit

final class StructuredLoggerSanitizationTests: XCTestCase {

    var logger: StructuredLogger!

    override func setUp() {
        super.setUp()
        logger = StructuredLogger()
        logger.minLevel = .debug
        logger.clearBuffer()
    }

    override func tearDown() {
        logger.clearBuffer()
        super.tearDown()
    }

    func testSanitize_tokenKey_masksValue() {
        let longValue = "abcdefghijklmnopqrstuvwxyz"
        logger.debug("test", context: ["token": longValue])

        let entry = logger.query().last
        let sanitized = entry?.context?["token"]
        XCTAssertEqual(sanitized, "abcd****wxyz")
    }

    func testSanitize_authorizationKey_masksValue() {
        let longValue = "Bearer some-long-auth-value-here"
        logger.debug("test", context: ["authorization": longValue])

        let entry = logger.query().last
        let sanitized = entry?.context?["authorization"]
        XCTAssertEqual(sanitized, "Bear****here")
    }

    func testSanitize_cookieKey_masksValue() {
        let longValue = "session_id=abcdef1234567890"
        logger.debug("test", context: ["cookie": longValue])

        let entry = logger.query().last
        let sanitized = entry?.context?["cookie"]
        XCTAssertEqual(sanitized, "sess****7890")
    }

    func testSanitize_apikeyKey_masksValue() {
        let longValue = "ak-1234567890abcdef"
        logger.debug("test", context: ["apikey": longValue])

        let entry = logger.query().last
        let sanitized = entry?.context?["apikey"]
        XCTAssertEqual(sanitized, "ak-1****cdef")
    }

    func testSanitize_api_keyKey_masksValue() {
        let longValue = "sk-1234567890abcdef"
        logger.debug("test", context: ["api_key": longValue])

        let entry = logger.query().last
        let sanitized = entry?.context?["api_key"]
        XCTAssertEqual(sanitized, "sk-1****cdef")
    }

    func testSanitize_secretKey_masksValue() {
        let longValue = "my-super-secret-key-value"
        logger.debug("test", context: ["secret": longValue])

        let entry = logger.query().last
        let sanitized = entry?.context?["secret"]
        XCTAssertEqual(sanitized, "my-s****alue")
    }

    func testSanitize_passwordKey_masksValue() {
        let longValue = "P@ssw0rd123456!"
        logger.debug("test", context: ["password": longValue])

        let entry = logger.query().last
        let sanitized = entry?.context?["password"]
        XCTAssertEqual(sanitized, "P@ss****456!")
    }

    func testSanitize_bearerKey_masksValue() {
        let longValue = "Bearer-12345678-token"
        logger.debug("test", context: ["bearer": longValue])

        let entry = logger.query().last
        let sanitized = entry?.context?["bearer"]
        XCTAssertEqual(sanitized, "Bear****oken")
    }

    func testSanitize_shortValue_fullyMasked() {
        logger.debug("test", context: ["token": "short"])

        let entry = logger.query().last
        let sanitized = entry?.context?["token"]
        XCTAssertEqual(sanitized, "****")
    }

    func testSanitize_exactlyEightChars_fullyMasked() {
        logger.debug("test", context: ["password": "12345678"])

        let entry = logger.query().last
        let sanitized = entry?.context?["password"]
        XCTAssertEqual(sanitized, "****")
    }

    func testSanitize_nineChars_partialMask() {
        logger.debug("test", context: ["secret": "123456789"])

        let entry = logger.query().last
        let sanitized = entry?.context?["secret"]
        XCTAssertEqual(sanitized, "1234****6789")
    }

    func testSanitize_nonSensitiveKey_passesThrough() {
        let value = "https://example.com/page"
        logger.debug("test", context: ["url": value])

        let entry = logger.query().last
        XCTAssertEqual(entry?.context?["url"], value)
    }

    func testSanitize_mixedContext_processesAllKeys() {
        logger.debug("test", context: [
            "url": "https://example.com",
            "token": "abcdefghijklmnop",
            "method": "GET",
            "authorization": "Bearer xyz1234567890abc",
            "user_id": "user-12345"
        ])

        let entry = logger.query().last
        XCTAssertEqual(entry?.context?["url"], "https://example.com")
        XCTAssertEqual(entry?.context?["token"], "abcd****mnop")
        XCTAssertEqual(entry?.context?["method"], "GET")
        XCTAssertEqual(entry?.context?["authorization"], "Bear****0abc")
        XCTAssertEqual(entry?.context?["user_id"], "user-12345")
    }

    func testSanitize_caseInsensitiveKey_redactsValue() {
        logger.debug("test", context: ["TOKEN": "abcdefghijklmnop"])
        let entry = logger.query().last
        XCTAssertEqual(entry?.context?["TOKEN"], "abcd****mnop")

        logger.clearBuffer()
        logger.debug("test", context: ["Authorization": "Bearer xyz1234567890abc"])
        let entry2 = logger.query().last
        XCTAssertEqual(entry2?.context?["Authorization"], "Bear****0abc")
    }

    func testSanitize_keyContainingTokenSubstring_redactsValue() {
        logger.debug("test", context: ["access_token": "abcdefghijklmnop"])
        let entry = logger.query().last
        XCTAssertEqual(entry?.context?["access_token"], "abcd****mnop")

        logger.clearBuffer()
        logger.debug("test", context: ["refresh_token": "xyz123456789abc"])
        let entry2 = logger.query().last
        XCTAssertEqual(entry2?.context?["refresh_token"], "xyz1****9abc")
    }

    func testSanitize_emptyValue_fullyMasked() {
        logger.debug("test", context: ["token": ""])
        let entry = logger.query().last
        XCTAssertEqual(entry?.context?["token"], "****")
    }

    func testSanitize_nilContext_doesNotCrash() {
        logger.debug("test", context: nil)
        let entry = logger.query().last
        XCTAssertNotNil(entry)
    }

    func testSanitize_preservesNonSensitiveInBatch() {
        let contexts: [[String: String]] = [
            ["token": "abcdefghijklmnop", "name": "app1"],
            ["password": "mypassword123", "status": "ok"],
            ["url": "https://safe.com", "secret": "supersecretvalue"]
        ]

        for ctx in contexts {
            logger.debug("batch", context: ctx)
        }

        let entries = logger.query(search: "batch")
        XCTAssertEqual(entries.count, 3)

        XCTAssertEqual(entries[2].context?["token"], "abcd****mnop")
        XCTAssertEqual(entries[2].context?["name"], "app1")

        XCTAssertEqual(entries[1].context?["password"], "mypa****d123")
        XCTAssertEqual(entries[1].context?["status"], "ok")

        XCTAssertEqual(entries[0].context?["url"], "https://safe.com")
        XCTAssertEqual(entries[0].context?["secret"], "supe****alue")
    }
}
