import XCTest
@testable import WebBridgeKit

final class CacheFileResourceTypeTests: XCTestCase {

    // MARK: - displayName

    func testDisplayName_WhenHTML_ReturnsHTML() {
        XCTAssertEqual(CacheFileResourceType.html.displayName, "HTML")
    }

    func testDisplayName_WhenScript_ReturnsJavaScript() {
        XCTAssertEqual(CacheFileResourceType.script.displayName, "JavaScript")
    }

    func testDisplayName_WhenStylesheet_ReturnsCSS() {
        XCTAssertEqual(CacheFileResourceType.stylesheet.displayName, "CSS")
    }

    func testDisplayName_WhenImage_ReturnsString() {
        XCTAssertEqual(CacheFileResourceType.image.displayName, "图片")
    }

    func testDisplayName_WhenFont_ReturnsString() {
        XCTAssertEqual(CacheFileResourceType.font.displayName, "字体")
    }

    func testDisplayName_WhenOther_ReturnsString() {
        XCTAssertEqual(CacheFileResourceType.other.displayName, "其他")
    }

    // MARK: - iconName

    func testIconName_WhenHTML_ReturnsDocText() {
        XCTAssertEqual(CacheFileResourceType.html.iconName, "doc.text")
    }

    func testIconName_WhenScript_ReturnsDocTextImage() {
        XCTAssertEqual(CacheFileResourceType.script.iconName, "doc.text.image")
    }

    func testIconName_WhenStylesheet_ReturnsPaintbrush() {
        XCTAssertEqual(CacheFileResourceType.stylesheet.iconName, "paintbrush")
    }

    func testIconName_WhenImage_ReturnsPhoto() {
        XCTAssertEqual(CacheFileResourceType.image.iconName, "photo")
    }

    func testIconName_WhenFont_ReturnsTextformat() {
        XCTAssertEqual(CacheFileResourceType.font.iconName, "textformat")
    }

    func testIconName_WhenOther_ReturnsDoc() {
        XCTAssertEqual(CacheFileResourceType.other.iconName, "doc")
    }

    // MARK: - iconColor

    func testIconColor_WhenHTML_ReturnsSystemBlue() {
        XCTAssertEqual(CacheFileResourceType.html.iconColor, .systemBlue)
    }

    func testIconColor_WhenScript_ReturnsSystemYellow() {
        XCTAssertEqual(CacheFileResourceType.script.iconColor, .systemYellow)
    }

    func testIconColor_WhenStylesheet_ReturnsSystemPink() {
        XCTAssertEqual(CacheFileResourceType.stylesheet.iconColor, .systemPink)
    }

    func testIconColor_WhenImage_ReturnsSystemPurple() {
        XCTAssertEqual(CacheFileResourceType.image.iconColor, .systemPurple)
    }

    func testIconColor_WhenFont_ReturnsSystemOrange() {
        XCTAssertEqual(CacheFileResourceType.font.iconColor, .systemOrange)
    }

    func testIconColor_WhenOther_ReturnsSystemGray() {
        XCTAssertEqual(CacheFileResourceType.other.iconColor, .systemGray)
    }
}

// MARK: - CacheResourceItem Tests

final class CacheResourceItemTests: XCTestCase {

    func testFormattedSize_WhenNoCompressedSize_ReturnsByteFormattedSize() {
        let item = CacheResourceItem(
            key: "test",
            url: "https://example.com/file.js",
            type: .script,
            size: 1024,
            compressedSize: nil,
            date: Date()
        )

        let formatted = item.formattedSize
        XCTAssertFalse(formatted.isEmpty, "Formatted size should not be empty")
        XCTAssertTrue(formatted.contains("KB"), "1KB file should show KB")
    }

    func testFormattedSize_WhenHasCompressedSize_ReturnsSavingsPercentage() {
        let item = CacheResourceItem(
            key: "test",
            url: "https://example.com/file.js",
            type: .script,
            size: 1000,
            compressedSize: 500,
            date: Date()
        )

        let formatted = item.formattedSize
        XCTAssertTrue(formatted.contains("节省"), "Should show savings percentage")
    }

    func testFormattedSize_WhenZeroCompressedSize_Returns100PercentSavings() {
        let item = CacheResourceItem(
            key: "test",
            url: "https://example.com/file.js",
            type: .script,
            size: 1000,
            compressedSize: 0,
            date: Date()
        )

        let formatted = item.formattedSize
        XCTAssertTrue(formatted.contains("节省 100%"), "Zero compression should show 100% savings")
    }

    func testFileName_WhenFullPath_ReturnsLastPathComponent() {
        let item = CacheResourceItem(
            key: "/path/to/app.js",
            url: "/path/to/app.js",
            type: .script,
            size: 100,
            compressedSize: nil,
            date: Date()
        )

        XCTAssertEqual(item.fileName, "app.js")
    }

    func testFileName_WhenURL_ReturnsLastPathComponent() {
        let item = CacheResourceItem(
            key: "https://cdn.example.com/v2/bundle.min.js",
            url: "https://cdn.example.com/v2/bundle.min.js",
            type: .script,
            size: 100,
            compressedSize: nil,
            date: Date()
        )

        XCTAssertEqual(item.fileName, "bundle.min.js")
    }

    func testInit_WhenAllPropertiesSet_HoldsValues() {
        let date = Date()
        let item = CacheResourceItem(
            key: "unique-key",
            url: "https://example.com/style.css",
            type: .stylesheet,
            size: 2048,
            compressedSize: 1024,
            date: date
        )

        XCTAssertEqual(item.key, "unique-key")
        XCTAssertEqual(item.url, "https://example.com/style.css")
        XCTAssertEqual(item.type, .stylesheet)
        XCTAssertEqual(item.size, 2048)
        XCTAssertEqual(item.compressedSize, 1024)
        XCTAssertEqual(item.date, date)
    }
}

// MARK: - CacheResourceSection Tests

final class CacheResourceSectionTests: XCTestCase {

    func testTotalSize_WhenMultipleItems_ReturnsSum() {
        let items = [
            CacheResourceItem(key: "a", url: "a.js", type: .script, size: 100, compressedSize: nil, date: Date()),
            CacheResourceItem(key: "b", url: "b.js", type: .script, size: 200, compressedSize: nil, date: Date()),
            CacheResourceItem(key: "c", url: "c.js", type: .script, size: 300, compressedSize: nil, date: Date())
        ]

        let section = CacheResourceSection(type: .script, items: items)

        XCTAssertEqual(section.totalSize, 600)
    }

    func testTotalSize_WhenEmptyItems_ReturnsZero() {
        let section = CacheResourceSection(type: .html, items: [])

        XCTAssertEqual(section.totalSize, 0)
    }

    func testTotalSize_WhenSingleItem_ReturnsItemSize() {
        let items = [
            CacheResourceItem(key: "x", url: "x.png", type: .image, size: 5000, compressedSize: nil, date: Date())
        ]

        let section = CacheResourceSection(type: .image, items: items)

        XCTAssertEqual(section.totalSize, 5000)
    }

    func testFormattedTotalSize_WhenHasItems_ReturnsReadableString() {
        let items = [
            CacheResourceItem(key: "a", url: "a.css", type: .stylesheet, size: 1024, compressedSize: nil, date: Date())
        ]

        let section = CacheResourceSection(type: .stylesheet, items: items)

        XCTAssertFalse(section.formattedTotalSize.isEmpty, "Formatted total size should not be empty")
    }

    func testFormattedTotalSize_WhenZeroBytes_ReturnsZeroBytes() {
        let section = CacheResourceSection(type: .other, items: [])

        XCTAssertFalse(section.formattedTotalSize.isEmpty)
    }

    func testInit_WhenCreated_HoldsTypeAndItems() {
        let items = [
            CacheResourceItem(key: "a", url: "a.html", type: .html, size: 50, compressedSize: nil, date: Date())
        ]

        let section = CacheResourceSection(type: .html, items: items)

        XCTAssertEqual(section.type, .html)
        XCTAssertEqual(section.items.count, 1)
        XCTAssertEqual(section.items.first?.key, "a")
    }
}
