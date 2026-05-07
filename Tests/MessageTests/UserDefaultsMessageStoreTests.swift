import XCTest
@testable import WebBridgeKit

final class UserDefaultsMessageStoreTests: XCTestCase {

    private var store: UserDefaultsMessageStore!

    private func makeStore(suite: String = "test.\(UUID().uuidString)") -> UserDefaultsMessageStore {
        UserDefaultsMessageStore(suiteName: suite, key: "TestMessages", maxMessages: 200)
    }

    override func tearDown() async throws {
        if let suite = store {
            await suite.deleteAll()
        }
        try await super.tearDown()
    }

    // MARK: - Save and Retrieve

    func testSaveAndRetrieve() async throws {
        store = makeStore()
        let payload = MessagePayload(title: "Hello", body: "World", channel: "test")
        let message = StoredMessage(payload: payload)

        try await store.save(message)

        let retrieved = await store.get(id: message.id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.payload.title, "Hello")
        XCTAssertEqual(retrieved?.payload.body, "World")
    }

    func testGetNonExistentReturnsNil() async {
        store = makeStore()
        let result = await store.get(id: "nonexistent")
        XCTAssertNil(result)
    }

    // MARK: - Get All

    func testGetAllReturnsAllMessages() async throws {
        store = makeStore()
        for i in 0..<5 {
            let payload = MessagePayload(title: "Msg \(i)", body: "Body", channel: "test")
            try await store.save(StoredMessage(payload: payload))
        }

        let all = await store.getAll()
        XCTAssertEqual(all.count, 5)
    }

    func testGetAllReturnsEmptyForNewStore() async {
        store = makeStore()
        let all = await store.getAll()
        XCTAssertTrue(all.isEmpty)
    }

    // MARK: - Get By Channel

    func testGetByChannel() async throws {
        store = makeStore()
        let payload1 = MessagePayload(title: "A", body: "B", channel: "bark")
        let payload2 = MessagePayload(title: "C", body: "D", channel: "webhook")
        let payload3 = MessagePayload(title: "E", body: "F", channel: "bark")

        try await store.save(StoredMessage(payload: payload1))
        try await store.save(StoredMessage(payload: payload2))
        try await store.save(StoredMessage(payload: payload3))

        let barkMessages = await store.getByChannel("bark")
        XCTAssertEqual(barkMessages.count, 2)

        let webhookMessages = await store.getByChannel("webhook")
        XCTAssertEqual(webhookMessages.count, 1)
    }

    func testGetByChannelReturnsEmptyForUnknown() async throws {
        store = makeStore()
        let payload = MessagePayload(title: "A", body: "B", channel: "test")
        try await store.save(StoredMessage(payload: payload))

        let result = await store.getByChannel("unknown")
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Get Unread

    func testGetUnread() async throws {
        store = makeStore()
        let payload = MessagePayload(title: "Unread", body: "Body", channel: "test")
        try await store.save(StoredMessage(payload: payload))

        let unread = await store.getUnread()
        XCTAssertEqual(unread.count, 1)
        XCTAssertTrue(unread[0].isRead == false)
    }

    func testGetUnreadCount() async throws {
        store = makeStore()
        for i in 0..<3 {
            let payload = MessagePayload(title: "Msg \(i)", body: "Body", channel: "test")
            try await store.save(StoredMessage(payload: payload))
        }

        let count = await store.getUnreadCount()
        XCTAssertEqual(count, 3)
    }

    // MARK: - Mark As Read

    func testMarkAsRead() async throws {
        store = makeStore()
        let payload = MessagePayload(title: "Test", body: "Body", channel: "test")
        let message = StoredMessage(payload: payload)
        try await store.save(message)

        await store.markAsRead(id: message.id)

        let retrieved = await store.get(id: message.id)
        XCTAssertTrue(retrieved?.isRead == true)
        XCTAssertNotNil(retrieved?.readAt)

        let unread = await store.getUnread()
        XCTAssertEqual(unread.count, 0)
    }

    func testMarkAsReadNonExistentDoesNothing() async throws {
        store = makeStore()
        let payload = MessagePayload(title: "Test", body: "Body", channel: "test")
        try await store.save(StoredMessage(payload: payload))

        await store.markAsRead(id: "nonexistent")

        let unread = await store.getUnread()
        XCTAssertEqual(unread.count, 1)
    }

    func testMarkAllAsRead() async throws {
        store = makeStore()
        for i in 0..<3 {
            let payload = MessagePayload(title: "Msg \(i)", body: "Body", channel: "test")
            try await store.save(StoredMessage(payload: payload))
        }

        await store.markAllAsRead()

        let unread = await store.getUnread()
        XCTAssertEqual(unread.count, 0)

        let all = await store.getAll()
        XCTAssertTrue(all.allSatisfy { $0.isRead })
    }

    // MARK: - Delete

    func testDelete() async throws {
        store = makeStore()
        let payload = MessagePayload(title: "Delete", body: "Me", channel: "test")
        let message = StoredMessage(payload: payload)
        try await store.save(message)

        let countBefore = await store.count()
        XCTAssertEqual(countBefore, 1)

        await store.delete(id: message.id)

        let retrieved = await store.get(id: message.id)
        XCTAssertNil(retrieved)
        let countAfter = await store.count()
        XCTAssertEqual(countAfter, 0)
    }

    func testDeleteNonExistentDoesNothing() async throws {
        store = makeStore()
        let payload = MessagePayload(title: "Keep", body: "Me", channel: "test")
        try await store.save(StoredMessage(payload: payload))

        await store.delete(id: "nonexistent")

        let count = await store.count()
        XCTAssertEqual(count, 1)
    }

    // MARK: - Delete All

    func testDeleteAll() async throws {
        store = makeStore()
        for i in 0..<5 {
            let payload = MessagePayload(title: "Msg \(i)", body: "Body", channel: "test")
            try await store.save(StoredMessage(payload: payload))
        }

        let countBefore = await store.count()
        XCTAssertEqual(countBefore, 5)

        await store.deleteAll()

        let all = await store.getAll()
        XCTAssertTrue(all.isEmpty)
        let countAfter = await store.count()
        XCTAssertEqual(countAfter, 0)
    }

    // MARK: - Count

    func testCountReturnsCorrectNumber() async throws {
        store = makeStore()
        let countInitial = await store.count()
        XCTAssertEqual(countInitial, 0)

        for i in 0..<10 {
            let payload = MessagePayload(title: "Msg \(i)", body: "Body", channel: "test")
            try await store.save(StoredMessage(payload: payload))
        }

        let countFinal = await store.count()
        XCTAssertEqual(countFinal, 10)
    }

    // MARK: - Persistence Across Instances

    func testPersistenceAcrossInstances() async throws {
        let suiteName = "test.persist.\(UUID().uuidString)"

        let store1 = makeStore(suite: suiteName)
        let payload = MessagePayload(title: "Persist", body: "Test", channel: "test")
        let message = StoredMessage(payload: payload)
        try await store1.save(message)

        let store2 = makeStore(suite: suiteName)
        let retrieved = await store2.get(id: message.id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.payload.title, "Persist")

        await store2.deleteAll()
    }

    // MARK: - Max Messages Truncation

    func testMaxMessagesTruncation() async throws {
        let maxMessages = 5
        let suiteName = "test.max.\(UUID().uuidString)"
        let limitedStore = UserDefaultsMessageStore(
            suiteName: suiteName,
            key: "LimitedMessages",
            maxMessages: maxMessages
        )

        var savedIDs: [String] = []
        for i in 0..<8 {
            let payload = MessagePayload(title: "Msg \(i)", body: "Body", channel: "test")
            let message = StoredMessage(id: "msg-\(i)", payload: payload)
            try await limitedStore.save(message)
            savedIDs.append("msg-\(i)")
        }

        let all = await limitedStore.getAll()
        XCTAssertEqual(all.count, maxMessages)

        let firstSaved = await limitedStore.get(id: "msg-0")
        XCTAssertNil(firstSaved)

        let lastSaved = await limitedStore.get(id: "msg-7")
        XCTAssertNotNil(lastSaved)

        await limitedStore.deleteAll()
    }

    // MARK: - Save Order (Newest First)

    func testSaveOrderNewestFirst() async throws {
        store = makeStore()
        let payload1 = MessagePayload(title: "First", body: "Body", channel: "test")
        let payload2 = MessagePayload(title: "Second", body: "Body", channel: "test")

        try await store.save(StoredMessage(payload: payload1))
        try await store.save(StoredMessage(payload: payload2))

        let all = await store.getAll()
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(all[0].payload.title, "Second")
        XCTAssertEqual(all[1].payload.title, "First")
    }
}
