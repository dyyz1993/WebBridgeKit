import XCTest
@testable import WebBridgeKit

final class MessageEngineTests: XCTestCase {
    
    var engine: MessageEngine!
    
    override func setUp() async throws {
        try await super.setUp()
        engine = MessageEngine.shared
    }
    
    override func tearDown() async throws {
        await engine.setOnMessageReceived(nil)
        await engine.clearAllMessages()
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

    func testReceivePersistsExplicitMarkdownWithoutPipeline() async throws {
        let payload = MessagePayload(
            title: "部署结果",
            body: "部署完成",
            markdown: "## 部署完成",
            channel: "apns",
            contentType: .markdown
        )

        try await engine.receive(payload)

        let messages = await engine.getMessages()
        XCTAssertEqual(messages.first?.bodyType, MessageBodyType.markdown.rawValue)
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

    func testReceiveReplacesMatchingMessageAndPreservesReadState() async throws {
        let initial = MessagePayload(
            id: "payload-1",
            title: "需要确认",
            body: "等待处理",
            channel: "apns",
            category: "approval",
            replacementID: "approval-42",
            actionState: .pending,
            requestID: "approval-42",
            revision: 1
        )
        try await engine.receive(initial)
        let initialMessages = await engine.getMessages()
        let storedID = try XCTUnwrap(initialMessages.first?.id)
        await engine.markAsRead(id: storedID)

        let resolved = MessagePayload(
            id: "payload-2",
            title: "审批已通过",
            body: "状态已同步",
            channel: "apns",
            category: "approval",
            replacementID: "approval-42",
            actionState: .approved,
            requestID: "approval-42",
            revision: 2
        )
        try await engine.receive(resolved)

        let messages = await engine.getMessages()
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages.first?.id, storedID)
        XCTAssertEqual(messages.first?.payload.actionState, .approved)
        XCTAssertTrue(messages.first?.isRead == true)
    }

    func testReceiveIgnoresStaleRevision() async throws {
        let current = MessagePayload(
            title: "已通过",
            body: "最新状态",
            channel: "apns",
            replacementID: "approval-42",
            actionState: .approved,
            revision: 2
        )
        let stale = MessagePayload(
            title: "待确认",
            body: "旧状态",
            channel: "apns",
            replacementID: "approval-42",
            actionState: .pending,
            revision: 1
        )

        try await engine.receive(current)
        try await engine.receive(stale)

        let messages = await engine.getMessages()
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages.first?.payload.actionState, .approved)
        XCTAssertEqual(messages.first?.payload.revision, 2)
    }

    func testReceiveDeleteRemovesMatchingMessage() async throws {
        try await engine.receive(MessagePayload(
            title: "任务",
            body: "处理中",
            channel: "apns",
            replacementID: "task-7",
            revision: 1
        ))

        try await engine.receive(MessagePayload(
            title: "任务",
            body: "已撤回",
            channel: "apns",
            replacementID: "task-7",
            isDeleted: true,
            revision: 2
        ))

        let messages = await engine.getMessages()
        XCTAssertTrue(messages.isEmpty)
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
        let expectation = expectation(description: "Message received callback")
        
        await engine.setOnMessageReceived { message in
            expectation.fulfill()
        }
        
        let payload = MessagePayload(title: "Test", body: "Body", channel: "test")
        try await engine.receive(payload)
        
        await fulfillment(of: [expectation], timeout: 2.0)
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
