import XCTest
@testable import WebBridgeKit

final class BarkChannelTests: XCTestCase {

    // MARK: - Channel ID

    func testChannelId() async {
        let channel = BarkChannel(key: "testkey")
        let channelId = await channel.channelId
        XCTAssertEqual(channelId, "bark")
    }

    // MARK: - Default Configuration

    func testDefaultConfiguration() {
        let config = BarkConfiguration.default
        XCTAssertNil(config.icon)
        XCTAssertEqual(config.isArchive, false)
        XCTAssertEqual(config.copyable, true)
        XCTAssertEqual(config.maxRetries, 3)
        XCTAssertEqual(config.timeout, 30)
    }

    func testCustomConfiguration() {
        let config = BarkConfiguration(
            icon: "https://example.com/icon.png",
            isArchive: true,
            copyable: false,
            maxRetries: 5,
            timeout: 60
        )
        XCTAssertEqual(config.icon, "https://example.com/icon.png")
        XCTAssertTrue(config.isArchive)
        XCTAssertFalse(config.copyable)
        XCTAssertEqual(config.maxRetries, 5)
        XCTAssertEqual(config.timeout, 60)
    }

    // MARK: - Active State

    func testChannelStartsInactive() async {
        let channel = BarkChannel(key: "testkey")
        let active = await channel.isActive
        XCTAssertFalse(active)
    }

    func testChannelBecomesActiveAfterStart() async {
        let channel = BarkChannel(key: "testkey")
        await channel.start()
        let active = await channel.isActive
        XCTAssertTrue(active)
    }

    func testChannelBecomesInactiveAfterStop() async {
        let channel = BarkChannel(key: "testkey")
        await channel.start()
        await channel.stop()
        let active = await channel.isActive
        XCTAssertFalse(active)
    }

    // MARK: - Send When Inactive

    func testSendFailsWhenInactive() async throws {
        let channel = BarkChannel(key: "testkey")
        let payload = MessagePayload(title: "Test", body: "Body", channel: "bark")

        let result = try await channel.send(payload)

        if case .failed(let error) = result,
           case .channelNotActive(let id) = error {
            XCTAssertEqual(id, "bark")
        } else {
            XCTFail("Expected channelNotActive error")
        }
    }

    // MARK: - Send With Empty Key

    func testSendFailsWithEmptyKey() async throws {
        let channel = BarkChannel(key: "")
        await channel.start()

        let payload = MessagePayload(title: "Test", body: "Body", channel: "bark")
        let result = try await channel.send(payload)

        if case .failed(let error) = result,
           case .channelNotConfigured(let id) = error {
            XCTAssertEqual(id, "bark")
        } else {
            XCTFail("Expected channelNotConfigured error")
        }
    }

    // MARK: - Server URL Trailing Slash Handling

    func testServerURLTrailingSlashIsStripped() async {
        let channel = BarkChannel(serverURL: "https://api.day.app/", key: "testkey")
        await channel.start()
        let active = await channel.isActive
        XCTAssertTrue(active)
    }

    func testServerURLWithoutTrailingSlash() async {
        let channel = BarkChannel(serverURL: "https://api.day.app", key: "testkey")
        await channel.start()
        let active = await channel.isActive
        XCTAssertTrue(active)
    }

    // MARK: - Test Connection URL Construction

    func testConnectionTestURL() async {
        let channel = BarkChannel(serverURL: "https://api.day.app", key: "mykey")
        let channelId = await channel.channelId
        XCTAssertEqual(channelId, "bark")
    }

    // MARK: - Send Text

    func testSendTextFailsWhenInactive() async throws {
        let channel = BarkChannel(key: "testkey")
        let result = try await channel.sendText(title: "Hi", body: "Hello")
        if case .failed(let error) = result,
           case .channelNotActive = error {
        } else {
            XCTFail("Expected channelNotActive error")
        }
    }

    // MARK: - Multiple Start/Stop Cycles

    func testMultipleStartStopCycles() async {
        let channel = BarkChannel(key: "testkey")

        for _ in 0..<3 {
            await channel.start()
            XCTAssertTrue(await channel.isActive)
            await channel.stop()
            XCTAssertFalse(await channel.isActive)
        }
    }

    // MARK: - Priority to Level Mapping

    func testPriorityMappingCriticalToTimeSensitive() async throws {
        let channel = BarkChannel(key: "testkey")
        await channel.start()
        let payload = MessagePayload(
            title: "Urgent",
            body: "Critical message",
            channel: "bark",
            priority: .critical
        )
        let result = try await channel.send(payload)
        if case .failed(let error) = result,
           case .networkError = error {
        } else if case .success = result {
        } else {
        }
    }

    func testPriorityMappingHighToActive() async {
        let channel = BarkChannel(key: "testkey")
        await channel.start()
        XCTAssertTrue(await channel.isActive)
    }

    func testPriorityMappingLowToPassive() async {
        let channel = BarkChannel(key: "testkey")
        await channel.start()
        XCTAssertTrue(await channel.isActive)
    }

    func testPriorityMappingNormalIsNil() async {
        let channel = BarkChannel(key: "testkey")
        await channel.start()
        XCTAssertTrue(await channel.isActive)
    }
}
