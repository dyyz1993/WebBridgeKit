import XCTest
@testable import WebBridgeKit

final class MessageProcessorTests: XCTestCase {

    // MARK: - MarkdownProcessor

    func testMarkdownProcessorIdentifier() {
        let processor = MarkdownProcessor()
        XCTAssertEqual(processor.identifier, "markdown")
    }

    func testMarkdownProcessorPriority() {
        let processor = MarkdownProcessor()
        XCTAssertEqual(processor.priority, 100)
    }

    func testMarkdownProcessorIsEnabledByDefault() {
        let processor = MarkdownProcessor()
        XCTAssertTrue(processor.isEnabled)
    }

    func testMarkdownProcessorPlainTextPassThrough() async throws {
        let processor = MarkdownProcessor()
        var content = MutableMessageContent(body: "Hello world", bodyType: .plainText)
        let result = try await processor.process(content: content)
        XCTAssertEqual(result.body, "Hello world")
    }

    func testMarkdownProcessorStripsBold() async throws {
        let processor = MarkdownProcessor()
        var content = MutableMessageContent(body: "This is **bold** text", bodyType: .markdown)
        let result = try await processor.process(content: content)
        XCTAssertEqual(result.body, "This is bold text")
    }

    func testMarkdownProcessorStripsItalic() async throws {
        let processor = MarkdownProcessor()
        var content = MutableMessageContent(body: "This is *italic* text", bodyType: .markdown)
        let result = try await processor.process(content: content)
        XCTAssertEqual(result.body, "This is italic text")
    }

    func testMarkdownProcessorStripsCode() async throws {
        let processor = MarkdownProcessor()
        var content = MutableMessageContent(body: "Use `async` keyword", bodyType: .markdown)
        let result = try await processor.process(content: content)
        XCTAssertEqual(result.body, "Use async keyword")
    }

    func testMarkdownProcessorStripsLinks() async throws {
        let processor = MarkdownProcessor()
        var content = MutableMessageContent(body: "Visit [Apple](https://apple.com) now", bodyType: .markdown)
        let result = try await processor.process(content: content)
        XCTAssertEqual(result.body, "Visit Apple now")
    }

    func testMarkdownProcessorStripsHeadings() async throws {
        let processor = MarkdownProcessor()
        var content = MutableMessageContent(body: "## Section Title", bodyType: .markdown)
        let result = try await processor.process(content: content)
        XCTAssertEqual(result.body, "Section Title")
    }

    func testMarkdownProcessorStripsMultipleFormatting() async throws {
        let processor = MarkdownProcessor()
        var content = MutableMessageContent(
            body: "**Bold** and *italic* and `code` and [link](url)",
            bodyType: .markdown
        )
        let result = try await processor.process(content: content)
        XCTAssertEqual(result.body, "Bold and italic and code and link")
    }

    // MARK: - LevelProcessor

    func testLevelProcessorIdentifier() {
        let processor = LevelProcessor()
        XCTAssertEqual(processor.identifier, "level")
    }

    func testLevelProcessorPriority() {
        let processor = LevelProcessor()
        XCTAssertEqual(processor.priority, 200)
    }

    func testLevelProcessorReturnsContentUnchanged() async throws {
        let processor = LevelProcessor()
        var content = MutableMessageContent(title: "Test", body: "Body", level: .timeSensitive)
        let result = try await processor.process(content: content)
        XCTAssertEqual(result.title, "Test")
        XCTAssertEqual(result.body, "Body")
        XCTAssertEqual(result.level, .timeSensitive)
    }

    // MARK: - BadgeProcessor

    func testBadgeProcessorIdentifier() {
        let mockManager = MockBadgeManager()
        let processor = BadgeProcessor(badgeManager: mockManager)
        XCTAssertEqual(processor.identifier, "badge")
    }

    func testBadgeProcessorPriority() {
        let mockManager = MockBadgeManager()
        let processor = BadgeProcessor(badgeManager: mockManager)
        XCTAssertEqual(processor.priority, 300)
    }

    func testBadgeProcessorSetsBadge() async throws {
        let mockManager = MockBadgeManager()
        let processor = BadgeProcessor(badgeManager: mockManager)
        var content = MutableMessageContent(badge: 5)
        let result = try await processor.process(content: content)
        XCTAssertEqual(mockManager.lastBadge, 5)
    }

    func testBadgeProcessorNilBadgeDoesNotSetBadge() async throws {
        let mockManager = MockBadgeManager()
        let processor = BadgeProcessor(badgeManager: mockManager)
        var content = MutableMessageContent(badge: nil)
        let result = try await processor.process(content: content)
        XCTAssertNil(mockManager.lastBadge)
    }

    func testBadgeProcessorZeroBadge() async throws {
        let mockManager = MockBadgeManager()
        let processor = BadgeProcessor(badgeManager: mockManager)
        var content = MutableMessageContent(badge: 0)
        let result = try await processor.process(content: content)
        XCTAssertEqual(mockManager.lastBadge, 0)
    }

    func testBadgeProcessorNegativeBadge() async throws {
        let mockManager = MockBadgeManager()
        let processor = BadgeProcessor(badgeManager: mockManager)
        var content = MutableMessageContent(badge: -1)
        let result = try await processor.process(content: content)
        XCTAssertEqual(mockManager.lastBadge, -1)
    }

    // MARK: - AutoCopyProcessor

    func testAutoCopyProcessorIdentifier() {
        let processor = AutoCopyProcessor()
        XCTAssertEqual(processor.identifier, "autoCopy")
    }

    func testAutoCopyProcessorPriority() {
        let processor = AutoCopyProcessor()
        XCTAssertEqual(processor.priority, 400)
    }

    func testAutoCopyProcessorCopiesBodyWhenEnabled() async throws {
        let processor = AutoCopyProcessor()
        var content = MutableMessageContent(body: "copy me", isAutoCopy: true)
        let result = try await processor.process(content: content)
        XCTAssertTrue(result.isAutoCopy)
    }

    func testAutoCopyProcessorDoesNotCopyWhenDisabled() async throws {
        let processor = AutoCopyProcessor()
        var content = MutableMessageContent(body: "don't copy", isAutoCopy: false)
        let result = try await processor.process(content: content)
        XCTAssertFalse(result.isAutoCopy)
    }

    func testAutoCopyProcessorUsesCustomCopyText() async throws {
        let processor = AutoCopyProcessor()
        var content = MutableMessageContent(body: "body text", isAutoCopy: true, copyText: "custom copy")
        let result = try await processor.process(content: content)
        XCTAssertEqual(result.copyText, "custom copy")
    }

    // MARK: - ArchiveProcessor

    func testArchiveProcessorIdentifier() async {
        let store = MockMessageStore()
        let processor = ArchiveProcessor(store: store)
        XCTAssertEqual(processor.identifier, "archive")
    }

    func testArchiveProcessorPriority() async {
        let store = MockMessageStore()
        let processor = ArchiveProcessor(store: store)
        XCTAssertEqual(processor.priority, 500)
    }

    func testArchiveProcessorSavesWhenArchiveEnabled() async throws {
        let store = MockMessageStore()
        let processor = ArchiveProcessor(store: store)
        var content = MutableMessageContent(
            title: "Test",
            body: "Body",
            isArchive: true
        )
        let result = try await processor.process(content: content)
        let saved = await store.getAll()
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved[0].payload.title, "Test")
    }

    func testArchiveProcessorSkipsWhenArchiveDisabled() async throws {
        let store = MockMessageStore()
        let processor = ArchiveProcessor(store: store)
        var content = MutableMessageContent(
            title: "Test",
            body: "Body",
            isArchive: false
        )
        let result = try await processor.process(content: content)
        let count = await store.count()
        XCTAssertEqual(count, 0)
    }

    // MARK: - MuteProcessor

    func testMuteProcessorIdentifier() async {
        var processor = MuteProcessor()
        XCTAssertEqual(processor.identifier, "mute")
    }

    func testMuteProcessorPriority() async {
        var processor = MuteProcessor()
        XCTAssertEqual(processor.priority, 600)
    }

    func testMuteProcessorMutedGroupGetsPassiveLevel() async throws {
        var processor = MuteProcessor()
        processor.muteGroup("alerts")
        var content = MutableMessageContent(group: "alerts", level: .active)
        let result = try await processor.process(content: content)
        XCTAssertEqual(result.level, .passive)
    }

    func testMuteProcessorUnmutedGroupStaysActive() async throws {
        var processor = MuteProcessor()
        processor.muteGroup("alerts")
        var content = MutableMessageContent(group: "news", level: .active)
        let result = try await processor.process(content: content)
        XCTAssertEqual(result.level, .active)
    }

    func testMuteProcessorNoGroupStaysActive() async throws {
        var processor = MuteProcessor()
        processor.muteGroup("alerts")
        var content = MutableMessageContent(group: nil, level: .active)
        let result = try await processor.process(content: content)
        XCTAssertEqual(result.level, .active)
    }

    func testMuteProcessorUnmuteRestoresLevel() async throws {
        var processor = MuteProcessor()
        processor.muteGroup("alerts")
        processor.unmuteGroup("alerts")
        var content = MutableMessageContent(group: "alerts", level: .timeSensitive)
        let result = try await processor.process(content: content)
        XCTAssertEqual(result.level, .timeSensitive)
    }

    func testMuteProcessorMultipleMutedGroups() async throws {
        var processor = MuteProcessor()
        processor.muteGroup("alerts")
        processor.muteGroup("promo")

        var content1 = MutableMessageContent(group: "alerts", level: .active)
        var content2 = MutableMessageContent(group: "promo", level: .critical)
        var content3 = MutableMessageContent(group: "news", level: .active)

        let result1 = try await processor.process(content: content1)
        let result2 = try await processor.process(content: content2)
        let result3 = try await processor.process(content: content3)

        XCTAssertEqual(result1.level, .passive)
        XCTAssertEqual(result2.level, .passive)
        XCTAssertEqual(result3.level, .active)
    }

    // MARK: - PushPayloadParser

    func testPushPayloadParserParseUserInfo() {
        let parser = PushPayloadParser()
        let userInfo: [AnyHashable: Any] = [
            "title": "Hello",
            "body": "World",
            "sound": "default",
            "badge": 3,
            "group": "test",
            "level": "timeSensitive",
            "url": "https://example.com"
        ]

        let content = parser.parse(userInfo: userInfo)

        XCTAssertEqual(content.title, "Hello")
        XCTAssertEqual(content.body, "World")
        XCTAssertEqual(content.sound, "default")
        XCTAssertEqual(content.badge, 3)
        XCTAssertEqual(content.group, "test")
        XCTAssertEqual(content.level, .timeSensitive)
        XCTAssertEqual(content.targetURL, "https://example.com")
    }

    func testPushPayloadParserParseUserInfoWithApsFallback() {
        let parser = PushPayloadParser()
        let userInfo: [AnyHashable: Any] = [
            "aps": [
                "alert": [
                    "title": "APS Title",
                    "body": "APS Body"
                ]
            ]
        ]

        let content = parser.parse(userInfo: userInfo)
        XCTAssertEqual(content.title, "APS Title")
        XCTAssertEqual(content.body, "APS Body")
    }

    func testPushPayloadParserParseBarkURLBodyOnly() {
        let parser = PushPayloadParser()
        let content = parser.parseBarkURL(path: "/mykey/hello world", query: [:])
        XCTAssertEqual(content.body, "hello world")
    }

    func testPushPayloadParserParseBarkURLTitleAndBody() {
        let parser = PushPayloadParser()
        let content = parser.parseBarkURL(path: "/mykey/Title/Body text", query: [:])
        XCTAssertEqual(content.title, "Title")
        XCTAssertEqual(content.body, "Body text")
    }

    func testPushPayloadParserParseBarkURLSubtitleTitleAndBody() {
        let parser = PushPayloadParser()
        let content = parser.parseBarkURL(path: "/mykey/Sub/Title/Body text", query: [:])
        XCTAssertEqual(content.subtitle, "Title")
        XCTAssertEqual(content.title, "Sub")
        XCTAssertEqual(content.body, "Body text")
    }

    func testPushPayloadParserParseBarkURLWithQueryParams() {
        let parser = PushPayloadParser()
        let content = parser.parseBarkURL(
            path: "/mykey/Test/Body",
            query: [
                "url": "https://example.com",
                "group": "testGroup",
                "icon": "https://example.com/icon.png",
                "sound": "alarm",
                "image": "https://example.com/img.png",
                "copy": "copy text",
                "call": "1",
                "isArchive": "1",
                "automaticallyCopy": "1",
                "markdown": "1",
                "level": "passive",
                "badge": "7",
                "volume": "5.5"
            ]
        )

        XCTAssertEqual(content.targetURL, "https://example.com")
        XCTAssertEqual(content.group, "testGroup")
        XCTAssertEqual(content.iconURL, "https://example.com/icon.png")
        XCTAssertEqual(content.sound, "alarm")
        XCTAssertEqual(content.imageURL, "https://example.com/img.png")
        XCTAssertEqual(content.copyText, "copy text")
        XCTAssertTrue(content.isCall)
        XCTAssertTrue(content.isArchive)
        XCTAssertTrue(content.isAutoCopy)
        XCTAssertEqual(content.bodyType, .markdown)
        XCTAssertEqual(content.level, .passive)
        XCTAssertEqual(content.badge, 7)
        XCTAssertEqual(content.volume, 5.5)
    }

    func testPushPayloadParserParseBarkURLInvalidLevelFallsBackToActive() {
        let parser = PushPayloadParser()
        let content = parser.parseBarkURL(path: "/key/T/B", query: ["level": "invalid"])
        XCTAssertEqual(content.level, .active)
    }

    func testPushPayloadParserParseBarkURLInvalidBadgeIsNil() {
        let parser = PushPayloadParser()
        let content = parser.parseBarkURL(path: "/key/T/B", query: ["badge": "notanumber"])
        XCTAssertNil(content.badge)
    }

    func testPushPayloadParserParseBarkURLVolumeClampedToMax10() {
        let parser = PushPayloadParser()
        let content = parser.parseBarkURL(path: "/key/T/B", query: ["volume": "15.0"])
        XCTAssertEqual(content.volume, 10.0)
    }

    func testPushPayloadParserParseBarkURLVolumeClampedToMin0() {
        let parser = PushPayloadParser()
        let content = parser.parseBarkURL(path: "/key/T/B", query: ["volume": "-5.0"])
        XCTAssertEqual(content.volume, 0.0)
    }

    func testPushPayloadParserParseBarkURLEmptyPath() {
        let parser = PushPayloadParser()
        let content = parser.parseBarkURL(path: "", query: [:])
        XCTAssertEqual(content.body, "")
        XCTAssertEqual(content.title, "")
    }

    func testPushPayloadParserParseUserInfoDefaults() {
        let parser = PushPayloadParser()
        let content = parser.parse(userInfo: [:])
        XCTAssertEqual(content.title, "")
        XCTAssertEqual(content.body, "")
        XCTAssertEqual(content.level, .active)
        XCTAssertEqual(content.bodyType, .plainText)
    }

    func testPushPayloadParserAutoCopyAliases() {
        let parser = PushPayloadParser()

        let content1 = parser.parseBarkURL(path: "/k/T/B", query: ["automaticallyCopy": "1"])
        XCTAssertTrue(content1.isAutoCopy)

        let content2 = parser.parseBarkURL(path: "/k/T/B", query: ["autoCopy": "1"])
        XCTAssertTrue(content2.isAutoCopy)

        let content3 = parser.parseBarkURL(path: "/k/T/B", query: [:])
        XCTAssertFalse(content3.isAutoCopy)
    }

    // MARK: - Pipeline

    func testPipelineSortsByPriority() async {
        let pipeline = MessageProcessorPipeline()
        let level = LevelProcessor()
        let markdown = MarkdownProcessor()

        await pipeline.register(level)
        await pipeline.register(markdown)

        let list = await pipeline.listProcessors()
        XCTAssertEqual(list[0].id, "markdown")
        XCTAssertEqual(list[1].id, "level")
    }

    func testPipelineProcessesInOrder() async throws {
        let pipeline = MessageProcessorPipeline()
        await pipeline.register(MarkdownProcessor())

        var content = MutableMessageContent(body: "**bold** text", bodyType: .markdown)
        let result = try await pipeline.process(content: content)
        XCTAssertEqual(result.body, "bold text")
    }

    func testPipelineSkipsDisabledProcessors() async throws {
        let pipeline = MessageProcessorPipeline()
        var processor = MarkdownProcessor()
        processor.isEnabled = false
        await pipeline.register(processor)

        var content = MutableMessageContent(body: "**bold** text", bodyType: .markdown)
        let result = try await pipeline.process(content: content)
        XCTAssertEqual(result.body, "**bold** text")
    }
}

// MARK: - Mock Helpers

class MockBadgeManager: BadgeManageable {
    var lastBadge: Int?

    func setBadge(_ count: Int) async {
        lastBadge = count
    }
}

actor MockMessageStore: MessageStore {
    private var messages: [StoredMessage] = []

    func save(_ message: StoredMessage) async throws {
        messages.append(message)
    }

    func get(id: String) async -> StoredMessage? {
        messages.first { $0.id == id }
    }

    func getAll() async -> [StoredMessage] {
        messages
    }

    func getByChannel(_ channel: String) async -> [StoredMessage] {
        messages.filter { $0.payload.channel == channel }
    }

    func getUnread() async -> [StoredMessage] {
        messages.filter { !$0.isRead }
    }

    func getUnreadCount() async -> Int {
        messages.filter { !$0.isRead }.count
    }

    func markAsRead(id: String) async {
        if let index = messages.firstIndex(where: { $0.id == id }) {
            messages[index].markRead()
        }
    }

    func markAllAsRead() async {
        for i in messages.indices {
            messages[i].markRead()
        }
    }

    func delete(id: String) async {
        messages.removeAll { $0.id == id }
    }

    func deleteAll() async {
        messages.removeAll()
    }

    func count() async -> Int {
        messages.count
    }
}
