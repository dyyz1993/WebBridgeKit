import XCTest
@testable import WebBridgeKit

final class MessageChannelTests: XCTestCase {

    func testMessagePayloadDefaultValues() {
        let payload = MessagePayload(
            title: "Test",
            body: "Body",
            channel: "push"
        )

        XCTAssertFalse(payload.id.isEmpty)
        XCTAssertEqual(payload.title, "Test")
        XCTAssertEqual(payload.body, "Body")
        XCTAssertEqual(payload.channel, "push")
        XCTAssertNil(payload.subtitle)
        XCTAssertNil(payload.category)
        XCTAssertEqual(payload.priority, .normal)
        XCTAssertNil(payload.sound)
        XCTAssertNil(payload.badge)
        XCTAssertNil(payload.group)
        XCTAssertNil(payload.threadId)
        XCTAssertNil(payload.targetURL)
        XCTAssertNil(payload.targetAppId)
        XCTAssertNil(payload.targetMode)
        XCTAssertNil(payload.userInfo)
    }

    func testMessagePayloadHasRouteWithURL() {
        let payload = MessagePayload(
            title: "Test",
            body: "Body",
            channel: "push",
            targetURL: "https://example.com"
        )
        XCTAssertTrue(payload.hasRoute)
    }

    func testMessagePayloadHasRouteWithAppId() {
        let payload = MessagePayload(
            title: "Test",
            body: "Body",
            channel: "push",
            targetAppId: "com.app.id"
        )
        XCTAssertTrue(payload.hasRoute)
    }

    func testMessagePayloadHasRouteFalseWhenNoTarget() {
        let payload = MessagePayload(
            title: "Test",
            body: "Body",
            channel: "push"
        )
        XCTAssertFalse(payload.hasRoute)
    }

    func testMessagePriorityLowIntValue() {
        XCTAssertEqual(MessagePriority.low.intValue, 0)
    }

    func testMessagePriorityNormalIntValue() {
        XCTAssertEqual(MessagePriority.normal.intValue, 5)
    }

    func testMessagePriorityHighIntValue() {
        XCTAssertEqual(MessagePriority.high.intValue, 8)
    }

    func testMessagePriorityCriticalIntValue() {
        XCTAssertEqual(MessagePriority.critical.intValue, 10)
    }

    func testMessagePriorityAllCasesCount() {
        XCTAssertEqual(MessagePriority.allCases.count, 4)
    }

    func testMessageErrorChannelNotActiveDescription() {
        let error = MessageError.channelNotActive(channelId: "bark")
        XCTAssertEqual(error.errorDescription, "Channel 'bark' is not active")
    }

    func testMessageErrorChannelNotConfiguredDescription() {
        let error = MessageError.channelNotConfigured(channelId: "webhook")
        XCTAssertEqual(error.errorDescription, "Channel 'webhook' is not configured")
    }

    func testMessageErrorInvalidPayloadDescription() {
        let error = MessageError.invalidPayload(reason: "missing title")
        XCTAssertEqual(error.errorDescription, "Invalid payload: missing title")
    }

    func testMessageErrorSendFailedDescription() {
        let error = MessageError.sendFailed(reason: "timeout")
        XCTAssertEqual(error.errorDescription, "Send failed: timeout")
    }

    func testMessageErrorNetworkErrorDescription() {
        let underlying = NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "connection lost"])
        let error = MessageError.networkError(underlying: underlying)
        XCTAssertTrue(error.errorDescription?.contains("Network error") == true)
    }

    func testMessageErrorUnauthorizedDescription() {
        let error = MessageError.unauthorized
        XCTAssertEqual(error.errorDescription, "Unauthorized - check API key")
    }

    func testMessageErrorRateLimitedWithRetryAfter() {
        let error = MessageError.rateLimited(retryAfter: 30.0)
        XCTAssertEqual(error.errorDescription, "Rate limited - retry after 30.0 seconds")
    }

    func testMessageErrorRateLimitedWithoutRetryAfter() {
        let error = MessageError.rateLimited(retryAfter: nil)
        XCTAssertEqual(error.errorDescription, "Rate limited")
    }

    func testMessageErrorServerErrorDescription() {
        let error = MessageError.serverError(statusCode: 500, message: "Internal Error")
        XCTAssertEqual(error.errorDescription, "Server error (500): Internal Error")
    }

    func testMessageSendResultSuccess() {
        let result = MessageSendResult.success(messageId: "msg-1")
        if case .success(let id) = result {
            XCTAssertEqual(id, "msg-1")
        } else {
            XCTFail("Expected success case")
        }
    }

    func testMessageSendResultFailed() {
        let result = MessageSendResult.failed(error: .unauthorized)
        if case .failed(let error) = result {
            XCTAssertEqual(error.errorDescription, "Unauthorized - check API key")
        } else {
            XCTFail("Expected failed case")
        }
    }

    func testMessageSendResultQueued() {
        let result = MessageSendResult.queued(messageId: "msg-2")
        if case .queued(let id) = result {
            XCTAssertEqual(id, "msg-2")
        } else {
            XCTFail("Expected queued case")
        }
    }
}
