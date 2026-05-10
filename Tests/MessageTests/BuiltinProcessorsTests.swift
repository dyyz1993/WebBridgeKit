import XCTest
@testable import WebBridgeKit

final class BuiltinProcessorsTests: XCTestCase {

    func testMarkdownProcessorIdentifier() {
        let processor = MarkdownProcessor()
        XCTAssertEqual(processor.identifier, "markdown")
    }

    func testMarkdownProcessorPriority() {
        let processor = MarkdownProcessor()
        XCTAssertEqual(processor.priority, 100)
    }

    func testMarkdownProcessorIsEnabled() {
        let processor = MarkdownProcessor()
        XCTAssertTrue(processor.isEnabled)
    }

    func testMarkdownProcessorStripsBold() async throws {
        let processor = MarkdownProcessor()
        var content = MutableMessageContent(body: "**bold** text", bodyType: .markdown)
        let result = try await processor.process(content: content)
        XCTAssertEqual(result.body, "bold text")
    }

    func testMarkdownProcessorStripsItalic() async throws {
        let processor = MarkdownProcessor()
        var content = MutableMessageContent(body: "*italic* text", bodyType: .markdown)
        let result = try await processor.process(content: content)
        XCTAssertEqual(result.body, "italic text")
    }

    func testMarkdownProcessorStripsCode() async throws {
        let processor = MarkdownProcessor()
        var content = MutableMessageContent(body: "`code` here", bodyType: .markdown)
        let result = try await processor.process(content: content)
        XCTAssertEqual(result.body, "code here")
    }

    func testMarkdownProcessorStripsLink() async throws {
        let processor = MarkdownProcessor()
        var content = MutableMessageContent(body: "[link](https://example.com)", bodyType: .markdown)
        let result = try await processor.process(content: content)
        XCTAssertEqual(result.body, "link")
    }

    func testMarkdownProcessorStripsHeader() async throws {
        let processor = MarkdownProcessor()
        var content = MutableMessageContent(body: "# Header", bodyType: .markdown)
        let result = try await processor.process(content: content)
        XCTAssertEqual(result.body, "Header")
    }

    func testMarkdownProcessorPlainTextUnchanged() async throws {
        let processor = MarkdownProcessor()
        var content = MutableMessageContent(body: "plain **text**", bodyType: .plainText)
        let result = try await processor.process(content: content)
        XCTAssertEqual(result.body, "plain **text**")
    }

    func testLevelProcessorIdentifier() {
        let processor = LevelProcessor()
        XCTAssertEqual(processor.identifier, "level")
    }

    func testLevelProcessorPriority() {
        let processor = LevelProcessor()
        XCTAssertEqual(processor.priority, 200)
    }

    func testLevelProcessorPassThrough() async throws {
        let processor = LevelProcessor()
        var content = MutableMessageContent(title: "Test", body: "Body", level: .timeSensitive)
        let result = try await processor.process(content: content)
        XCTAssertEqual(result.title, "Test")
        XCTAssertEqual(result.body, "Body")
        XCTAssertEqual(result.level, .timeSensitive)
    }

    func testMuteProcessorMuteGroup() {
        var processor = MuteProcessor()
        processor.muteGroup("alerts")
    }

    func testMuteProcessorUnmuteGroup() {
        var processor = MuteProcessor()
        processor.muteGroup("alerts")
        processor.unmuteGroup("alerts")
    }

    func testMuteProcessorMutedGroupGetsPassiveLevel() async throws {
        var processor = MuteProcessor()
        processor.muteGroup("alerts")
        var content = MutableMessageContent(group: "alerts", level: .active)
        let result = try await processor.process(content: content)
        XCTAssertEqual(result.level, .passive)
    }

    func testMuteProcessorUnmutedGroupKeepsLevel() async throws {
        var processor = MuteProcessor()
        processor.muteGroup("other")
        var content = MutableMessageContent(group: "alerts", level: .active)
        let result = try await processor.process(content: content)
        XCTAssertEqual(result.level, .active)
    }

    func testBadgeProcessorIdentifier() {
        let mockManager = MockBadgeMgr()
        let processor = BadgeProcessor(badgeManager: mockManager)
        XCTAssertEqual(processor.identifier, "badge")
    }

    func testBadgeProcessorPriority() {
        let mockManager = MockBadgeMgr()
        let processor = BadgeProcessor(badgeManager: mockManager)
        XCTAssertEqual(processor.priority, 300)
    }

    func testBadgeProcessorIsEnabled() {
        let mockManager = MockBadgeMgr()
        let processor = BadgeProcessor(badgeManager: mockManager)
        XCTAssertTrue(processor.isEnabled)
    }

    func testBadgeProcessorProcessSetsBadge() async throws {
        let mockManager = MockBadgeMgr()
        let processor = BadgeProcessor(badgeManager: mockManager)
        var content = MutableMessageContent(badge: 5)
        _ = try await processor.process(content: content)
        XCTAssertEqual(mockManager.lastSetBadge, 5)
    }

    func testAutoCopyProcessorIdentifier() {
        let processor = AutoCopyProcessor()
        XCTAssertEqual(processor.identifier, "autoCopy")
    }

    func testAutoCopyProcessorPriority() {
        let processor = AutoCopyProcessor()
        XCTAssertEqual(processor.priority, 400)
    }

    func testAutoCopyProcessorIsEnabled() {
        let processor = AutoCopyProcessor()
        XCTAssertTrue(processor.isEnabled)
    }

    func testPipelineRegisterSortsByPriority() async {
        let pipeline = MessageProcessorPipeline()
        await pipeline.register(LevelProcessor())
        await pipeline.register(MarkdownProcessor())

        let list = await pipeline.listProcessors()
        XCTAssertEqual(list[0].id, "markdown")
        XCTAssertEqual(list[1].id, "level")
    }

    func testPipelineListProcessors() async {
        let pipeline = MessageProcessorPipeline()
        await pipeline.register(MarkdownProcessor())
        await pipeline.register(LevelProcessor())

        let list = await pipeline.listProcessors()
        XCTAssertEqual(list.count, 2)
    }

    func testPipelineProcessThroughEnabledProcessors() async throws {
        let pipeline = MessageProcessorPipeline()
        await pipeline.register(MarkdownProcessor())

        var content = MutableMessageContent(body: "**bold** text", bodyType: .markdown)
        let result = try await pipeline.process(content: content)
        XCTAssertEqual(result.body, "bold text")
    }
}

class MockBadgeMgr: BadgeManageable {
    var lastSetBadge: Int?

    func setBadge(_ count: Int) async {
        lastSetBadge = count
    }
}
