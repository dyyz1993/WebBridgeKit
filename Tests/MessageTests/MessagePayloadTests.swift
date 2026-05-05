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
            targetMode: "immersive",
            userInfo: ["key": "value"]
        )
        
        XCTAssertEqual(payload.title, "Test")
        XCTAssertEqual(payload.channel, "bark")
        XCTAssertEqual(payload.priority, .high)
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
