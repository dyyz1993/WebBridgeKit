import XCTest
@testable import WebBridgeKit

final class MessageStoreTests: XCTestCase {
    
    var store: InMemoryMessageStore!
    
    override func setUp() async throws {
        try await super.setUp()
        store = InMemoryMessageStore()
    }
    
    // MARK: - Save and Get
    
    func testSaveAndGet() async throws {
        let message = StoredMessage(
            payload: MessagePayload(title: "Test", body: "Body", channel: "test")
        )
        
        try await store.save(message)
        let retrieved = await store.get(id: message.id)
        
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.payload.title, "Test")
    }
    
    func testGetNonExistent() async {
        let result = await store.get(id: "nonexistent")
        XCTAssertNil(result)
    }
    
    // MARK: - GetAll
    
    func testGetAll() async throws {
        for i in 0..<3 {
            let message = StoredMessage(
                payload: MessagePayload(title: "Msg \(i)", body: "Body", channel: "test")
            )
            try await store.save(message)
        }
        
        let messages = await store.getAll()
        XCTAssertEqual(messages.count, 3)
    }
    
    func testGetAllSortedByDate() async throws {
        let msg1 = StoredMessage(
            payload: MessagePayload(title: "First", body: "Body", channel: "test"),
            receivedAt: Date().addingTimeInterval(-100)
        )
        let msg2 = StoredMessage(
            payload: MessagePayload(title: "Second", body: "Body", channel: "test"),
            receivedAt: Date()
        )
        
        try await store.save(msg1)
        try await store.save(msg2)
        
        let messages = await store.getAll()
        // Most recent first
        XCTAssertEqual(messages[0].payload.title, "Second")
        XCTAssertEqual(messages[1].payload.title, "First")
    }
    
    // MARK: - GetByChannel
    
    func testGetByChannel() async throws {
        let msg1 = StoredMessage(
            payload: MessagePayload(title: "Bark Msg", body: "Body", channel: "bark")
        )
        let msg2 = StoredMessage(
            payload: MessagePayload(title: "Webhook Msg", body: "Body", channel: "webhook")
        )
        
        try await store.save(msg1)
        try await store.save(msg2)
        
        let barkMessages = await store.getByChannel("bark")
        XCTAssertEqual(barkMessages.count, 1)
        XCTAssertEqual(barkMessages[0].payload.title, "Bark Msg")
    }
    
    // MARK: - Unread
    
    func testGetUnread() async throws {
        var msg1 = StoredMessage(
            payload: MessagePayload(title: "Unread", body: "Body", channel: "test")
        )
        var msg2 = StoredMessage(
            payload: MessagePayload(title: "Read", body: "Body", channel: "test"),
            isRead: true,
            readAt: Date()
        )
        
        try await store.save(msg1)
        try await store.save(msg2)
        
        let unread = await store.getUnread()
        XCTAssertEqual(unread.count, 1)
        XCTAssertEqual(unread[0].payload.title, "Unread")
    }
    
    func testGetUnreadCount() async throws {
        let msg1 = StoredMessage(
            payload: MessagePayload(title: "Msg 1", body: "Body", channel: "test")
        )
        let msg2 = StoredMessage(
            payload: MessagePayload(title: "Msg 2", body: "Body", channel: "test")
        )
        
        try await store.save(msg1)
        try await store.save(msg2)
        
        let count = await store.getUnreadCount()
        XCTAssertEqual(count, 2)
    }
    
    func testMarkAsRead() async throws {
        let message = StoredMessage(
            payload: MessagePayload(title: "Test", body: "Body", channel: "test")
        )
        
        try await store.save(message)
        await store.markAsRead(id: message.id)
        
        let retrieved = await store.get(id: message.id)
        XCTAssertTrue(retrieved!.isRead)
        XCTAssertNotNil(retrieved!.readAt)
    }
    
    func testMarkAllAsRead() async throws {
        for i in 0..<3 {
            let message = StoredMessage(
                payload: MessagePayload(title: "Msg \(i)", body: "Body", channel: "test")
            )
            try await store.save(message)
        }
        
        await store.markAllAsRead()
        
        let unreadCount = await store.getUnreadCount()
        XCTAssertEqual(unreadCount, 0)
    }
    
    // MARK: - Delete
    
    func testDelete() async throws {
        let message = StoredMessage(
            payload: MessagePayload(title: "Test", body: "Body", channel: "test")
        )
        
        try await store.save(message)
        await store.delete(id: message.id)
        
        let retrieved = await store.get(id: message.id)
        XCTAssertNil(retrieved)
    }
    
    func testDeleteAll() async throws {
        for i in 0..<3 {
            let message = StoredMessage(
                payload: MessagePayload(title: "Msg \(i)", body: "Body", channel: "test")
            )
            try await store.save(message)
        }
        
        await store.deleteAll()
        
        let count = await store.count()
        XCTAssertEqual(count, 0)
    }
    
    // MARK: - Count
    
    func testCount() async throws {
        XCTAssertEqual(await store.count(), 0)
        
        let message = StoredMessage(
            payload: MessagePayload(title: "Test", body: "Body", channel: "test")
        )
        try await store.save(message)
        
        XCTAssertEqual(await store.count(), 1)
    }
}
