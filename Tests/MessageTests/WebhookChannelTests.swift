import XCTest
import CryptoKit
@testable import WebBridgeKit

final class WebhookChannelTests: XCTestCase {

    // MARK: - Channel ID

    func testChannelId() async {
        let channel = WebhookChannel()
        let channelId = await channel.channelId
        XCTAssertEqual(channelId, "webhook")
    }

    // MARK: - Active State

    func testChannelStartsInactive() async {
        let channel = WebhookChannel()
        XCTAssertFalse(await channel.isActive)
    }

    func testChannelBecomesActiveAfterStart() async {
        let channel = WebhookChannel()
        await channel.start()
        XCTAssertTrue(await channel.isActive)
    }

    func testChannelBecomesInactiveAfterStop() async {
        let channel = WebhookChannel()
        await channel.start()
        await channel.stop()
        XCTAssertFalse(await channel.isActive)
    }

    // MARK: - Send Always Fails

    func testSendReturnsChannelNotConfigured() async throws {
        let channel = WebhookChannel()
        let payload = MessagePayload(title: "Test", body: "Body", channel: "webhook")
        let result = try await channel.send(payload)

        if case .failed(let error) = result,
           case .channelNotConfigured(let id) = error {
            XCTAssertEqual(id, "webhook")
        } else {
            XCTFail("Expected channelNotConfigured error")
        }
    }

    // MARK: - Process Webhook - Valid JSON

    func testProcessWebhookWithValidJSON() async throws {
        let channel = WebhookChannel()
        let body = """
        {"title":"Hello","body":"World","url":"https://example.com","group":"test","sound":"default"}
        """
        let data = Data(body.utf8)

        let payload = try await channel.processWebhook(body: data, headers: [:])

        XCTAssertEqual(payload.title, "Hello")
        XCTAssertEqual(payload.body, "World")
        XCTAssertEqual(payload.targetURL, "https://example.com")
        XCTAssertEqual(payload.group, "test")
        XCTAssertEqual(payload.sound, "default")
        XCTAssertEqual(payload.channel, "webhook")
    }

    func testProcessWebhookContentFieldAsBody() async throws {
        let channel = WebhookChannel()
        let body = """
        {"title":"Title","content":"Content body"}
        """
        let data = Data(body.utf8)

        let payload = try await channel.processWebhook(body: data, headers: [:])
        XCTAssertEqual(payload.body, "Content body")
    }

    func testProcessWebhookTextFieldAsBody() async throws {
        let channel = WebhookChannel()
        let body = """
        {"title":"Title","text":"Text body"}
        """
        let data = Data(body.utf8)

        let payload = try await channel.processWebhook(body: data, headers: [:])
        XCTAssertEqual(payload.body, "Text body")
    }

    func testProcessWebhookBodyPriorityOverContent() async throws {
        let channel = WebhookChannel()
        let body = """
        {"title":"Title","body":"body text","content":"content text","text":"text body"}
        """
        let data = Data(body.utf8)

        let payload = try await channel.processWebhook(body: data, headers: [:])
        XCTAssertEqual(payload.body, "body text")
    }

    func testProcessWebhookDefaults() async throws {
        let channel = WebhookChannel()
        let body = """
        {}
        """
        let data = Data(body.utf8)

        let payload = try await channel.processWebhook(body: data, headers: [:])
        XCTAssertEqual(payload.title, "Webhook Message")
        XCTAssertEqual(payload.body, "")
    }

    // MARK: - Level Mapping

    func testProcessWebhookLevelPassive() async throws {
        let channel = WebhookChannel()
        let body = """{"level":"passive"}"""
        let payload = try await channel.processWebhook(body: Data(body.utf8), headers: [:])
        XCTAssertEqual(payload.priority, .low)
    }

    func testProcessWebhookLevelActive() async throws {
        let channel = WebhookChannel()
        let body = """{"level":"active"}"""
        let payload = try await channel.processWebhook(body: Data(body.utf8), headers: [:])
        XCTAssertEqual(payload.priority, .high)
    }

    func testProcessWebhookLevelTimeSensitive() async throws {
        let channel = WebhookChannel()
        let body = """{"level":"timeSensitive"}"""
        let payload = try await channel.processWebhook(body: Data(body.utf8), headers: [:])
        XCTAssertEqual(payload.priority, .critical)
    }

    func testProcessWebhookLevelUnknownDefaultsToNormal() async throws {
        let channel = WebhookChannel()
        let body = """{"level":"unknown"}"""
        let payload = try await channel.processWebhook(body: Data(body.utf8), headers: [:])
        XCTAssertEqual(payload.priority, .normal)
    }

    // MARK: - Unknown Fields → userInfo

    func testProcessWebhookUnknownFieldsToUserInfo() async throws {
        let channel = WebhookChannel()
        let body = """
        {"title":"T","body":"B","customField":"customValue","anotherKey":"anotherVal"}
        """
        let payload = try await channel.processWebhook(body: Data(body.utf8), headers: [:])

        XCTAssertEqual(payload.userInfo?["customField"], "customValue")
        XCTAssertEqual(payload.userInfo?["anotherKey"], "anotherVal")
    }

    func testProcessWebhookKnownFieldsNotInUserInfo() async throws {
        let channel = WebhookChannel()
        let body = """
        {"title":"T","body":"B","group":"G","sound":"S"}
        """
        let payload = try await channel.processWebhook(body: Data(body.utf8), headers: [:])

        XCTAssertNil(payload.userInfo?["title"])
        XCTAssertNil(payload.userInfo?["body"])
        XCTAssertNil(payload.userInfo?["group"])
        XCTAssertNil(payload.userInfo?["sound"])
    }

    func testProcessWebhookAppIdFields() async throws {
        let channel = WebhookChannel()
        let body = """{"title":"T","body":"B","appid":"com.test.app"}"""
        let payload = try await channel.processWebhook(body: Data(body.utf8), headers: [:])
        XCTAssertEqual(payload.targetAppId, "com.test.app")
    }

    func testProcessWebhookModeField() async throws {
        let channel = WebhookChannel()
        let body = """{"title":"T","body":"B","mode":"fullscreen"}"""
        let payload = try await channel.processWebhook(body: Data(body.utf8), headers: [:])
        XCTAssertEqual(payload.targetMode, "fullscreen")
    }

    // MARK: - Invalid JSON

    func testProcessWebhookInvalidJSONThrows() async {
        let channel = WebhookChannel()
        let invalidData = Data("not json".utf8)

        do {
            _ = try await channel.processWebhook(body: invalidData, headers: [:])
            XCTFail("Expected error to be thrown")
        } catch {
            if let msgError = error as? MessageError,
               case .invalidPayload = msgError {
            } else {
                XCTFail("Expected MessageError.invalidPayload")
            }
        }
    }

    // MARK: - Signature Validation

    func testProcessWebhookWithValidSignature() async throws {
        let secret = "my-secret-key"
        let channel = WebhookChannel(secret: secret)

        let body = """{"title":"Signed","body":"Message"}"""
        let bodyData = Data(body.utf8)
        let signature = computeHMAC(body: bodyData, secret: secret)

        let payload = try await channel.processWebhook(
            body: bodyData,
            headers: ["X-Webhook-Signature": signature]
        )
        XCTAssertEqual(payload.title, "Signed")
    }

    func testProcessWebhookWithSha256PrefixSignature() async throws {
        let secret = "my-secret"
        let channel = WebhookChannel(secret: secret)

        let body = """{"title":"Prefixed","body":"Msg"}"""
        let bodyData = Data(body.utf8)
        let signature = "sha256=" + computeHMAC(body: bodyData, secret: secret)

        let payload = try await channel.processWebhook(
            body: bodyData,
            headers: ["X-Webhook-Signature": signature]
        )
        XCTAssertEqual(payload.title, "Prefixed")
    }

    func testProcessWebhookWithWrongSignatureThrows() async {
        let secret = "correct-secret"
        let channel = WebhookChannel(secret: secret)

        let body = """{"title":"Wrong","body":"Sig"}"""
        let bodyData = Data(body.utf8)

        do {
            _ = try await channel.processWebhook(
                body: bodyData,
                headers: ["X-Webhook-Signature": "wrong-signature"]
            )
            XCTFail("Expected unauthorized error")
        } catch let error as MessageError {
            if case .unauthorized = error {
            } else {
                XCTFail("Expected unauthorized error")
            }
        }
    }

    func testProcessWebhookMissingSignatureThrows() async {
        let secret = "my-secret"
        let channel = WebhookChannel(secret: secret)

        let body = """{"title":"No","body":"Sig"}"""
        let bodyData = Data(body.utf8)

        do {
            _ = try await channel.processWebhook(body: bodyData, headers: [:])
            XCTFail("Expected unauthorized error")
        } catch let error as MessageError {
            if case .unauthorized = error {
            } else {
                XCTFail("Expected unauthorized error")
            }
        }
    }

    func testProcessWebhookNoSecretNoValidation() async throws {
        let channel = WebhookChannel()

        let body = """{"title":"NoSecret","body":"Works"}"""
        let bodyData = Data(body.utf8)

        let payload = try await channel.processWebhook(body: bodyData, headers: [:])
        XCTAssertEqual(payload.title, "NoSecret")
    }

    func testProcessWebhookHubSignature256Header() async throws {
        let secret = "hub-secret"
        let channel = WebhookChannel(secret: secret)

        let body = """{"title":"Hub","body":"Sig"}"""
        let bodyData = Data(body.utf8)
        let signature = computeHMAC(body: bodyData, secret: secret)

        let payload = try await channel.processWebhook(
            body: bodyData,
            headers: ["X-Hub-Signature-256": signature]
        )
        XCTAssertEqual(payload.title, "Hub")
    }

    // MARK: - OnReceive Callback

    func testOnReceiveCallback() async throws {
        let channel = WebhookChannel()
        let expectation = expectation(description: "callback received")

        await channel.onReceive { payload in
            XCTAssertEqual(payload.title, "Callback")
            expectation.fulfill()
        }

        let body = """{"title":"Callback","body":"Test"}"""
        _ = try await channel.processWebhook(body: Data(body.utf8), headers: [:])

        await fulfillment(of: [expectation], timeout: 2.0)
    }

    // MARK: - Multiple Start/Stop

    func testMultipleStartStopCycles() async {
        let channel = WebhookChannel()

        for _ in 0..<3 {
            await channel.start()
            XCTAssertTrue(await channel.isActive)
            await channel.stop()
            XCTAssertFalse(await channel.isActive)
        }
    }

    // MARK: - Helpers

    private func computeHMAC(body: Data, secret: String) -> String {
        let key = SymmetricKey(data: Data(secret.utf8))
        let hmac = HMAC<SHA256>.authenticationCode(for: body, using: key)
        return Data(hmac).map { String(format: "%02x", $0) }.joined()
    }
}
