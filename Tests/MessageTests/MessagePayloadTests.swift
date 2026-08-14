import XCTest
@testable import WebBridgeKit

final class MessagePayloadTests: XCTestCase {
    
    // MARK: - Initialization
    
    func testDefaultInitialization() {
        let payload = MessagePayload(
            title: "Test",
            body: "Test body",
            channel: "test"
        )
        
        XCTAssertFalse(payload.id.isEmpty)
        XCTAssertEqual(payload.title, "Test")
        XCTAssertEqual(payload.body, "Test body")
        XCTAssertEqual(payload.channel, "test")
        XCTAssertEqual(payload.priority, .normal)
        XCTAssertNil(payload.targetURL)
        XCTAssertNil(payload.targetAppId)
        XCTAssertFalse(payload.hasRoute)
    }
    
    func testFullInitialization() {
        let payload = MessagePayload(
            title: "Test",
            body: "Test body",
            subtitle: "Subtitle",
            channel: "bark",
            category: "alert",
            priority: .high,
            sound: "alarm",
            badge: 3,
            group: "test-group",
            threadId: "thread-1",
            targetURL: "https://example.com",
            targetAppId: "myapp",
            route: "/messages/42",
            targetMode: "immersive",
            imageURL: "https://example.com/image.png",
            iconURL: "https://example.com/icon.png",
            interruptionLevel: .timeSensitive,
            soundVolume: 7,
            isCall: true,
            copyText: "copy-this",
            isAutoCopy: true,
            isArchive: true,
            ttl: 60,
            replacementID: "replace-1",
            actionState: .pending,
            requestID: "request-1",
            contentType: .approval,
            qrPayload: "webbridgekit://gateway/example",
            statePath: "/api/approvals/request-1",
            revision: 3,
            userInfo: ["key": "value"]
        )
        
        XCTAssertEqual(payload.title, "Test")
        XCTAssertEqual(payload.channel, "bark")
        XCTAssertEqual(payload.priority, .high)
        XCTAssertEqual(payload.route, "/messages/42")
        XCTAssertEqual(payload.interruptionLevel, .timeSensitive)
        XCTAssertEqual(payload.copyText, "copy-this")
        XCTAssertEqual(payload.replacementID, "replace-1")
        XCTAssertEqual(payload.actionState, .pending)
        XCTAssertEqual(payload.requestID, "request-1")
        XCTAssertEqual(payload.contentType, .approval)
        XCTAssertEqual(payload.revision, 3)
        XCTAssertTrue(payload.requiresUserAction)
        XCTAssertTrue(payload.hasRoute)
    }
    
    // MARK: - Priority
    
    func testPriorityIntValues() {
        XCTAssertEqual(MessagePriority.low.intValue, 0)
        XCTAssertEqual(MessagePriority.normal.intValue, 5)
        XCTAssertEqual(MessagePriority.high.intValue, 8)
        XCTAssertEqual(MessagePriority.critical.intValue, 10)
    }
    
    func testPriorityAllCases() {
        XCTAssertEqual(MessagePriority.allCases.count, 4)
    }
    
    // MARK: - Route Detection
    
    func testHasRouteWithURL() {
        let payload = MessagePayload(
            title: "Test",
            body: "Body",
            channel: "test",
            targetURL: "https://example.com"
        )
        XCTAssertTrue(payload.hasRoute)
    }
    
    func testHasRouteWithAppId() {
        let payload = MessagePayload(
            title: "Test",
            body: "Body",
            channel: "test",
            targetAppId: "myapp"
        )
        XCTAssertTrue(payload.hasRoute)
    }
    
    func testHasRouteWithoutTarget() {
        let payload = MessagePayload(
            title: "Test",
            body: "Body",
            channel: "test"
        )
        XCTAssertFalse(payload.hasRoute)
    }
    
    // MARK: - Codable
    
    func testCodableRoundTrip() throws {
        let payload = MessagePayload(
            title: "Test",
            body: "Body",
            channel: "test",
            priority: .high,
            targetURL: "https://example.com"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MessagePayload.self, from: data)
        
        XCTAssertEqual(decoded.id, payload.id)
        XCTAssertEqual(decoded.title, payload.title)
        XCTAssertEqual(decoded.body, payload.body)
        XCTAssertEqual(decoded.channel, payload.channel)
        XCTAssertEqual(decoded.priority, payload.priority)
        XCTAssertEqual(decoded.targetURL, payload.targetURL)
    }

    func testLegacyPayloadWithoutPresentationFieldsStillDecodes() throws {
        let payload = MessagePayload(title: "Legacy", body: "Body", channel: "test")
        let encoded = try JSONEncoder().encode(payload)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        ["route", "imageURL", "iconURL", "interruptionLevel", "soundVolume", "isCall", "copyText", "isAutoCopy", "isArchive", "ttl", "replacementID", "isDeleted", "actionState", "requestID", "contentType", "qrPayload", "statePath", "revision"].forEach {
            object.removeValue(forKey: $0)
        }

        let decoded = try JSONDecoder().decode(
            MessagePayload.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        XCTAssertNil(decoded.route)
        XCTAssertNil(decoded.imageURL)
        XCTAssertNil(decoded.interruptionLevel)
        XCTAssertNil(decoded.ttl)
        XCTAssertNil(decoded.actionState)
        XCTAssertNil(decoded.contentType)
    }

    func testOnlyPendingNonExpiredActionRequiresAttention() {
        let pending = MessagePayload(
            title: "需要确认",
            body: "请打开审批页面",
            channel: "apns",
            category: "approval",
            expiresAt: Date().addingTimeInterval(60),
            actionState: .pending
        )
        let approved = MessagePayload(
            title: "已通过",
            body: "审批完成",
            channel: "apns",
            category: "approval",
            actionState: .approved
        )
        let expired = MessagePayload(
            title: "已过期",
            body: "审批超时",
            channel: "apns",
            category: "approval",
            expiresAt: Date().addingTimeInterval(-1),
            actionState: .pending
        )

        XCTAssertTrue(pending.requiresUserAction)
        XCTAssertFalse(approved.requiresUserAction)
        XCTAssertFalse(expired.requiresUserAction)
    }

    func testNativeApprovalPayloadRoundTripsWithActions() throws {
        let approval = MessageApproval(
            actions: [
                MessageApprovalAction(
                    id: "approve",
                    title: "通过",
                    style: .primary,
                    requiresReason: false,
                    resultState: .approved
                ),
                MessageApprovalAction(
                    id: "reject",
                    title: "拒绝",
                    style: .destructive,
                    requiresReason: true,
                    resultState: .rejected
                ),
            ]
        )
        let payload = MessagePayload(
            title: "需要确认",
            body: "是否发布？",
            channel: "apns",
            actionState: .pending,
            requestID: "approval-42",
            contentType: .approval,
            revision: 1,
            presentation: .native,
            approval: approval
        )

        let decoded = try JSONDecoder().decode(
            MessagePayload.self,
            from: JSONEncoder().encode(payload)
        )

        XCTAssertEqual(decoded.presentation, .native)
        XCTAssertEqual(decoded.approval?.actions.count, 2)
        XCTAssertEqual(decoded.approval?.actions.last?.requiresReason, true)
        XCTAssertEqual(decoded.approval?.actions.last?.resultState, .rejected)
        XCTAssertTrue(decoded.hasNativeApprovalActions)

        let resolved = decoded.updatingActionState(.approved, revision: 2)
        XCTAssertEqual(resolved.updateIdentity, payload.updateIdentity)
        XCTAssertEqual(resolved.actionState, .approved)
        XCTAssertEqual(resolved.revision, 2)
        XCTAssertEqual(resolved.approval, approval)
        XCTAssertFalse(resolved.hasNativeApprovalActions)
    }

    func testTTLDeterminesExpirationWhenNoExplicitDateExists() {
        let createdAt = Date(timeIntervalSince1970: 1_000)
        let payload = MessagePayload(
            title: "Short lived",
            body: "Body",
            channel: "test",
            ttl: 60,
            createdAt: createdAt
        )

        XCTAssertEqual(payload.expirationDate, Date(timeIntervalSince1970: 1_060))
    }
    
    // MARK: - Equatable
    
    func testEquality() {
        let id = UUID().uuidString
        let now = Date()
        let payload1 = MessagePayload(id: id, title: "Test", body: "Body", channel: "test", createdAt: now)
        let payload2 = MessagePayload(id: id, title: "Test", body: "Body", channel: "test", createdAt: now)
        
        XCTAssertEqual(payload1, payload2)
    }
    
    func testInequality() {
        let payload1 = MessagePayload(id: "1", title: "Test1", body: "Body", channel: "test")
        let payload2 = MessagePayload(id: "2", title: "Test2", body: "Body", channel: "test")
        
        XCTAssertNotEqual(payload1, payload2)
    }
}
