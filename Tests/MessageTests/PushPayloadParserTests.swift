import XCTest
@testable import WebBridgeKit

final class PushPayloadParserTests: XCTestCase {

    func testParseBasicUserInfo() {
        let parser = PushPayloadParser()
        let userInfo: [AnyHashable: Any] = [
            "title": "Hello",
            "body": "World"
        ]

        let content = parser.parse(userInfo: userInfo)

        XCTAssertEqual(content.title, "Hello")
        XCTAssertEqual(content.body, "World")
    }

    func testParseFromApsAlert() {
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

    func testParseExtractsURLToTargetURL() {
        let parser = PushPayloadParser()
        let userInfo: [AnyHashable: Any] = [
            "url": "https://example.com/page"
        ]

        let content = parser.parse(userInfo: userInfo)

        XCTAssertEqual(content.targetURL, "https://example.com/page")
    }

    func testParseBarkURLTwoSegmentsBodyOnly() {
        let parser = PushPayloadParser()
        let content = parser.parseBarkURL(path: "/key/hello world", query: [:])

        XCTAssertEqual(content.body, "hello world")
        XCTAssertEqual(content.title, "")
    }

    func testParseBarkURLThreeSegmentsTitleAndBody() {
        let parser = PushPayloadParser()
        let content = parser.parseBarkURL(path: "/key/Title/Body text", query: [:])

        XCTAssertEqual(content.title, "Title")
        XCTAssertEqual(content.body, "Body text")
    }

    func testParseBarkURLFourPlusSegmentsSubtitleTitleAndBody() {
        let parser = PushPayloadParser()
        let content = parser.parseBarkURL(path: "/key/Sub/Title/Body text", query: [:])

        XCTAssertEqual(content.title, "Sub")
        XCTAssertEqual(content.subtitle, "Title")
        XCTAssertEqual(content.body, "Body text")
    }

    func testParseBarkURLQueryURL() {
        let parser = PushPayloadParser()
        let content = parser.parseBarkURL(path: "/k/T/B", query: ["url": "https://example.com"])

        XCTAssertEqual(content.targetURL, "https://example.com")
    }

    func testParseBarkURLQueryGroup() {
        let parser = PushPayloadParser()
        let content = parser.parseBarkURL(path: "/k/T/B", query: ["group": "alerts"])

        XCTAssertEqual(content.group, "alerts")
    }

    func testParseBarkURLQueryIcon() {
        let parser = PushPayloadParser()
        let content = parser.parseBarkURL(path: "/k/T/B", query: ["icon": "https://img.png"])

        XCTAssertEqual(content.iconURL, "https://img.png")
    }

    func testParseBarkURLQuerySound() {
        let parser = PushPayloadParser()
        let content = parser.parseBarkURL(path: "/k/T/B", query: ["sound": "alarm"])

        XCTAssertEqual(content.sound, "alarm")
    }

    func testParseBarkURLQueryImage() {
        let parser = PushPayloadParser()
        let content = parser.parseBarkURL(path: "/k/T/B", query: ["image": "https://photo.jpg"])

        XCTAssertEqual(content.imageURL, "https://photo.jpg")
    }

    func testParseBarkURLQueryCopy() {
        let parser = PushPayloadParser()
        let content = parser.parseBarkURL(path: "/k/T/B", query: ["copy": "copy this"])

        XCTAssertEqual(content.copyText, "copy this")
    }

    func testParseBarkURLQueryCallFlag() {
        let parser = PushPayloadParser()
        let content = parser.parseBarkURL(path: "/k/T/B", query: ["call": "1"])

        XCTAssertTrue(content.isCall)
    }

    func testParseBarkURLQueryIsArchiveFlag() {
        let parser = PushPayloadParser()
        let content = parser.parseBarkURL(path: "/k/T/B", query: ["isArchive": "1"])

        XCTAssertTrue(content.isArchive)
    }

    func testParseBarkURLQueryAutoCopyFlag() {
        let parser = PushPayloadParser()

        let content1 = parser.parseBarkURL(path: "/k/T/B", query: ["autoCopy": "1"])
        XCTAssertTrue(content1.isAutoCopy)

        let content2 = parser.parseBarkURL(path: "/k/T/B", query: ["automaticallyCopy": "1"])
        XCTAssertTrue(content2.isAutoCopy)
    }

    func testParseBarkURLQueryMarkdownFlag() {
        let parser = PushPayloadParser()
        let content = parser.parseBarkURL(path: "/k/T/B", query: ["markdown": "1"])

        XCTAssertEqual(content.bodyType, .markdown)
    }

    func testParseBarkURLQueryLevel() {
        let parser = PushPayloadParser()
        let content = parser.parseBarkURL(path: "/k/T/B", query: ["level": "passive"])

        XCTAssertEqual(content.level, .passive)
    }

    func testParseBarkURLQueryBadge() {
        let parser = PushPayloadParser()
        let content = parser.parseBarkURL(path: "/k/T/B", query: ["badge": "7"])

        XCTAssertEqual(content.badge, 7)
    }

    func testParseBarkURLQueryVolume() {
        let parser = PushPayloadParser()
        let content = parser.parseBarkURL(path: "/k/T/B", query: ["volume": "5.0"])

        XCTAssertEqual(content.volume, 5.0)
    }

    func testParseBarkURLEmptyPathReturnsEmptyContent() {
        let parser = PushPayloadParser()
        let content = parser.parseBarkURL(path: "", query: [:])

        XCTAssertEqual(content.title, "")
        XCTAssertEqual(content.body, "")
        XCTAssertNil(content.subtitle)
    }
}
