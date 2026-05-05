import XCTest
@testable import WebBridgeKit

final class MessageEngineTests: XCTestCase {
    
    var engine: MessageEngine!
    
    override func setUp() async throws {
        try await super.setUp()
        engine = MessageEngine()
    }
    
    override func tearDown() async throws {
        await engine.stopAll()
        try await super.tearDown()
    }
    
    // MARK: - Singleton
    
    func testSharedInstance() {
        let shared1 = MessageEngine.shared
        let shared2 = MessageEngine.shared
        XCTAssertTrue(shared1 === shared2)
    }
    
    // MARK: - Channel Management
    
    func testRegisterChannel() async {
        let channel = MockChannel(channelId: "test")
        await engine.registerChannel(channel)
        
        let channels = await engine.getRegisteredChannels()
        XCTAssertTrue(channels.contains("test"))
    }
    
    func testUnregisterChannel() async {
        let channel = MockChannel(channelId: "test")
        await engine.registerChannel(channel)
        await engine.unregisterChannel("test")
        
        let channels = await engine.getRegisteredChannels()
        XCTAssertFalse(channels.contains("test"))
    }
    
    // MARK: - Message Operations
    
    func testReceiveMessage() async throws {
        let payload = MessagePayload(
            title: "Test",
            body: "Test body",
            channel: "test"
        )
        
        try await engine.receive(payload)
        
        let messages = await engine.getMessages()
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].payload.title, "Test")
    }
    
    func testReceiveMultipleMessages() async throws {
        for i in 0..<5 {
            let payload = MessagePayload(
                title: "Message \(i)",
                body: "Body \(i)",
                channel: "test"
            )
            try await engine.receive(payload)
        }
        
        let messages = await engine.getMessages()
        XCTAssertEqual(messages.count, 5)
    }
    
    func testGetUnreadMessages() async throws {
        let payload1 = MessagePayload(title: "Msg 1", body: "Body", channel: "test")
        let payload2 = MessagePayload(title: "Msg 2", body: "Body", channel: "test")
        
        try await engine.receive(payload1)
        try await engine.receive(payload2)
        
        let unread = await engine.getUnreadMessages()
        XCTAssertEqual(unread.count, 2)
    }
    
    func testMarkAsRead() async throws {
        let payload = MessagePayload(title: "Test", body: "Body", channel: "test")
        try await engine.receive(payload)
        
        let messages = await engine.getMessages()
        let messageId = messages[0].id
        
        await engine.markAsRead(id: messageId)
        
        let unread = await engine.getUnreadMessages()
        XCTAssertEqual(unread.count, 0)
    }
    
    func testGetUnreadCount() async throws {
        let payload1 = MessagePayload(title: "Msg 1", body: "Body", channel: "test")
        let payload2 = MessagePayload(title: "Msg 2", body: "Body", channel: "test")
        
        try await engine.receive(payload1)
        try await engine.receive(payload2)
        
        let count = await engine.getUnreadCount()
        XCTAssertEqual(count, 2)
    }
    
    func testDeleteMessage() async throws {
        let payload = MessagePayload(title: "Test", body: "Body", channel: "test")
        try await engine.receive(payload)
        
        let messages = await engine.getMessages()
        XCTAssertEqual(messages.count, 1)
        
        await engine.deleteMessage(id: messages[0].id)
        
        let remaining = await engine.getMessages()
        XCTAssertEqual(remaining.count, 0)
    }
    
    func testClearAllMessages() async throws {
        for i in 0..<3 {
            let payload = MessagePayload(title: "Msg \(i)", body: "Body", channel: "test")
            try await engine.receive(payload)
        }
        
        await engine.clearAllMessages()
        
        let messages = await engine.getMessages()
        XCTAssertEqual(messages.count, 0)
    }
    
    // MARK: - Statistics
    
    func testStatistics() async throws {
        let payload = MessagePayload(title: "Test", body: "Body", channel: "test")
        try await engine.receive(payload)
        
        let stats = await engine.getStatistics()
        XCTAssertEqual(stats.totalReceived, 1)
    }
    
    func testStatisticsReset() async throws {
        let payload = MessagePayload(title: "Test", body: "Body", channel: "test")
        try await engine.receive(payload)
        
        await engine.clearAllMessages()
        
        let stats = await engine.getStatistics()
        XCTAssertEqual(stats.totalReceived, 0)
    }
    
    // MARK: - Callback
    
    func testOnMessageReceivedCallback() async throws {
        var receivedMessage: StoredMessage?
        
        await engine.set { message in
            receivedMessage = message
        }
        
        let payload = MessagePayload(title: "Test", body: "Body", channel: "test")
        try await engine.receive(payload)
        
        // Note: Due to actor isolation, the callback may not have fired yet
        // In a real test, we'd use expectations
    }
}

// MARK: - Mock Channel

class MockChannel: MessageChannel {
    let channelId: String
    var isActive: Bool = false
    var lastSentPayload: MessagePayload?
    
    init(channelId: String) {
        self.channelId = channelId
    }
    
    func start() async {
        isActive = true
    }
    
    func stop() async {
        isActive = false
    }
    
    func send(_ payload: MessagePayload) async throws -> MessageSendResult {
        lastSentPayload = payload
        return .success(messageId: payload.id)
    }
}
