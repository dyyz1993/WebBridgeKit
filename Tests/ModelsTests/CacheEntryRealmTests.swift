//
//  CacheEntryRealmTests.swift
//  ModelsTests
//

import XCTest
@testable import WebBridgeKit

final class CacheEntryRealmTests: XCTestCase {

    // MARK: - CacheEntryRealm Defaults

    func testDefaultValues() {
        let entry = CacheEntryRealm()
        XCTAssertEqual(entry.key, "")
        XCTAssertEqual(entry.url, "")
        XCTAssertEqual(entry.mimeType, "")
        XCTAssertEqual(entry.originalSize, 0)
        XCTAssertEqual(entry.compressedSize, 0)
        XCTAssertFalse(entry.isCompressed)
        XCTAssertEqual(entry.compressionRatio, 0.0)
        XCTAssertEqual(entry.accessCount, 0)
        XCTAssertEqual(entry.filePath, "")
        XCTAssertNil(entry.etag)
        XCTAssertNil(entry.lastModified)
        XCTAssertNil(entry.responseHeaders)
    }

    // MARK: - Primary Key & Indexed Properties

    func testPrimaryKeyIsKey() {
        XCTAssertEqual(CacheEntryRealm.primaryKey(), "key")
    }

    func testIndexedProperties() {
        let indexed = CacheEntryRealm.indexedProperties()
        XCTAssertTrue(indexed.contains("url"))
        XCTAssertTrue(indexed.contains("createdAt"))
        XCTAssertTrue(indexed.contains("lastAccessedAt"))
        XCTAssertTrue(indexed.contains("isCompressed"))
    }

    // MARK: - Property Assignment

    func testPropertyAssignment() {
        let entry = CacheEntryRealm()
        entry.key = "abc123"
        entry.url = "https://example.com/app.js"
        entry.mimeType = "application/javascript"
        entry.originalSize = 1024
        entry.compressedSize = 512
        entry.isCompressed = true
        entry.compressionRatio = 0.5
        entry.accessCount = 10
        entry.filePath = "/cache/abc123"
        entry.etag = "\"etag-value\""
        entry.responseHeaders = "{\"content-type\":\"application/javascript\"}"

        XCTAssertEqual(entry.key, "abc123")
        XCTAssertEqual(entry.url, "https://example.com/app.js")
        XCTAssertEqual(entry.mimeType, "application/javascript")
        XCTAssertEqual(entry.originalSize, 1024)
        XCTAssertEqual(entry.compressedSize, 512)
        XCTAssertTrue(entry.isCompressed)
        XCTAssertEqual(entry.compressionRatio, 0.5)
        XCTAssertEqual(entry.accessCount, 10)
        XCTAssertEqual(entry.filePath, "/cache/abc123")
        XCTAssertEqual(entry.etag, "\"etag-value\"")
        XCTAssertEqual(entry.responseHeaders, "{\"content-type\":\"application/javascript\"}")
    }

    // MARK: - Domain Computed Property

    func testDomainFromValidURL() {
        let entry = CacheEntryRealm()
        entry.url = "https://www.example.com/page"
        XCTAssertEqual(entry.domain, "www.example.com")
    }

    func testDomainFromInvalidURL() {
        let entry = CacheEntryRealm()
        entry.url = "not-a-url"
        XCTAssertEqual(entry.domain, "unknown")
    }

    func testDomainFromEmptyURL() {
        let entry = CacheEntryRealm()
        entry.url = ""
        XCTAssertEqual(entry.domain, "unknown")
    }

    // MARK: - File Extension

    func testFileExtensionFromJS() {
        let entry = CacheEntryRealm()
        entry.url = "https://example.com/app.js"
        XCTAssertEqual(entry.fileExtension, "js")
    }

    func testFileExtensionFromCSS() {
        let entry = CacheEntryRealm()
        entry.url = "https://example.com/style.css"
        XCTAssertEqual(entry.fileExtension, "css")
    }

    func testFileExtensionNoExtension() {
        let entry = CacheEntryRealm()
        entry.url = "https://example.com/path"
        XCTAssertEqual(entry.fileExtension, "")
    }

    func testFileExtensionFromInvalidURL() {
        let entry = CacheEntryRealm()
        entry.url = "invalid"
        XCTAssertEqual(entry.fileExtension, "")
    }

    // MARK: - Resource Type

    func testResourceTypeJS() {
        let entry = CacheEntryRealm()
        entry.url = "https://example.com/app.js"
        XCTAssertEqual(entry.resourceType, .script)
    }

    func testResourceTypeMJS() {
        let entry = CacheEntryRealm()
        entry.url = "https://example.com/app.mjs"
        XCTAssertEqual(entry.resourceType, .script)
    }

    func testResourceTypeCSS() {
        let entry = CacheEntryRealm()
        entry.url = "https://example.com/style.css"
        XCTAssertEqual(entry.resourceType, .stylesheet)
    }

    func testResourceTypePNG() {
        let entry = CacheEntryRealm()
        entry.url = "https://example.com/img.png"
        XCTAssertEqual(entry.resourceType, .image)
    }

    func testResourceTypeJPG() {
        let entry = CacheEntryRealm()
        entry.url = "https://example.com/img.jpg"
        XCTAssertEqual(entry.resourceType, .image)
    }

    func testResourceTypeWebP() {
        let entry = CacheEntryRealm()
        entry.url = "https://example.com/img.webp"
        XCTAssertEqual(entry.resourceType, .image)
    }

    func testResourceTypeSVG() {
        let entry = CacheEntryRealm()
        entry.url = "https://example.com/icon.svg"
        XCTAssertEqual(entry.resourceType, .image)
    }

    func testResourceTypeWOFF() {
        let entry = CacheEntryRealm()
        entry.url = "https://example.com/font.woff"
        XCTAssertEqual(entry.resourceType, .font)
    }

    func testResourceTypeWOFF2() {
        let entry = CacheEntryRealm()
        entry.url = "https://example.com/font.woff2"
        XCTAssertEqual(entry.resourceType, .font)
    }

    func testResourceTypeMP4() {
        let entry = CacheEntryRealm()
        entry.url = "https://example.com/video.mp4"
        XCTAssertEqual(entry.resourceType, .video)
    }

    func testResourceTypeMP3() {
        let entry = CacheEntryRealm()
        entry.url = "https://example.com/audio.mp3"
        XCTAssertEqual(entry.resourceType, .audio)
    }

    func testResourceTypeHTML() {
        let entry = CacheEntryRealm()
        entry.url = "https://example.com/index.html"
        XCTAssertEqual(entry.resourceType, .html)
    }

    func testResourceTypeHTM() {
        let entry = CacheEntryRealm()
        entry.url = "https://example.com/index.htm"
        XCTAssertEqual(entry.resourceType, .html)
    }

    func testResourceTypeJSON() {
        let entry = CacheEntryRealm()
        entry.url = "https://example.com/data.json"
        XCTAssertEqual(entry.resourceType, .json)
    }

    func testResourceTypeUnknown() {
        let entry = CacheEntryRealm()
        entry.url = "https://example.com/file.xyz"
        XCTAssertEqual(entry.resourceType, .other)
    }

    func testResourceTypeCaseInsensitive() {
        let entry = CacheEntryRealm()
        entry.url = "https://example.com/app.JS"
        XCTAssertEqual(entry.resourceType, .script)
    }

    // MARK: - Formatted Properties

    func testFormattedOriginalSize() {
        let entry = CacheEntryRealm()
        entry.originalSize = 1024
        XCTAssertTrue(entry.formattedOriginalSize.contains("KB"))
    }

    func testFormattedCompressedSize() {
        let entry = CacheEntryRealm()
        entry.compressedSize = 2048
        XCTAssertTrue(entry.formattedCompressedSize.contains("KB"))
    }

    func testFormattedCompressionRatio() {
        let entry = CacheEntryRealm()
        entry.compressionRatio = 0.5
        XCTAssertEqual(entry.formattedCompressionRatio, "50.0%")
    }

    func testSavedSpace() {
        let entry = CacheEntryRealm()
        entry.originalSize = 1024
        entry.compressedSize = 256
        XCTAssertEqual(entry.savedSpace, 768)
    }

    func testFormattedSavedSpace() {
        let entry = CacheEntryRealm()
        entry.originalSize = 1024 * 1024
        entry.compressedSize = 0
        XCTAssertTrue(entry.formattedSavedSpace.contains("MB"))
    }

    // MARK: - updateAccess

    func testUpdateAccessIncrementsCount() {
        let entry = CacheEntryRealm()
        entry.accessCount = 5
        entry.updateAccess()
        XCTAssertEqual(entry.accessCount, 6)
    }

    func testUpdateAccessUpdatesLastAccessedAt() {
        let entry = CacheEntryRealm()
        let before = entry.lastAccessedAt
        Thread.sleep(forTimeInterval: 0.01)
        entry.updateAccess()
        XCTAssertTrue(entry.lastAccessedAt >= before)
    }

    // MARK: - CacheResourceType Enum

    func testCacheResourceTypeIconNames() {
        let types: [CacheEntryRealm.CacheResourceType] = [
            .html, .script, .stylesheet, .image, .font, .video, .audio, .json, .other
        ]
        for type in types {
            XCTAssertFalse(type.iconName.isEmpty)
        }
    }

    func testCacheResourceTypeDisplayNames() {
        XCTAssertEqual(CacheEntryRealm.CacheResourceType.html.displayName, "HTML")
        XCTAssertEqual(CacheEntryRealm.CacheResourceType.script.displayName, "JavaScript")
        XCTAssertEqual(CacheEntryRealm.CacheResourceType.stylesheet.displayName, "CSS")
        XCTAssertEqual(CacheEntryRealm.CacheResourceType.image.displayName, "图片")
        XCTAssertEqual(CacheEntryRealm.CacheResourceType.font.displayName, "字体")
        XCTAssertEqual(CacheEntryRealm.CacheResourceType.video.displayName, "视频")
        XCTAssertEqual(CacheEntryRealm.CacheResourceType.audio.displayName, "音频")
        XCTAssertEqual(CacheEntryRealm.CacheResourceType.json.displayName, "JSON")
        XCTAssertEqual(CacheEntryRealm.CacheResourceType.other.displayName, "其他")
    }

    // MARK: - createOrUpdate

    func testCreateOrUpdateWithCompression() {
        let options = CacheEntryRealm.CreationOptions(
            key: "test-key",
            url: "https://example.com/app.js",
            data: Data(repeating: 0xFF, count: 1000),
            compressedData: Data(repeating: 0x00, count: 500),
            mimeType: "application/javascript",
            filePath: "/cache/test"
        )
        let entry = CacheEntryRealm.createOrUpdate(options: options)
        XCTAssertEqual(entry.key, "test-key")
        XCTAssertEqual(entry.url, "https://example.com/app.js")
        XCTAssertEqual(entry.originalSize, 1000)
        XCTAssertEqual(entry.compressedSize, 500)
        XCTAssertTrue(entry.isCompressed)
        XCTAssertEqual(entry.compressionRatio, 0.5, accuracy: 0.01)
        XCTAssertEqual(entry.accessCount, 1)
    }

    func testCreateOrUpdateWithoutCompression() {
        let options = CacheEntryRealm.CreationOptions(
            key: "test-key-2",
            url: "https://example.com/data.json",
            data: Data(repeating: 0xFF, count: 800),
            compressedData: nil,
            mimeType: "application/json",
            filePath: "/cache/test2",
            etag: "\"v1\"",
            lastModified: Date(),
            responseHeaders: ["Content-Type": "application/json"]
        )
        let entry = CacheEntryRealm.createOrUpdate(options: options)
        XCTAssertFalse(entry.isCompressed)
        XCTAssertEqual(entry.compressedSize, 800)
        XCTAssertEqual(entry.compressionRatio, 1.0)
        XCTAssertEqual(entry.etag, "\"v1\"")
        XCTAssertNotNil(entry.lastModified)
        XCTAssertNotNil(entry.responseHeaders)
    }

    // MARK: - CacheMemoryInfo

    func testCacheMemoryInfoFromEmptyEntries() {
        let info = CacheMemoryInfo.from(entries: [])
        XCTAssertEqual(info.totalEntries, 0)
        XCTAssertEqual(info.totalOriginalSize, 0)
        XCTAssertEqual(info.totalCompressedSize, 0)
        XCTAssertEqual(info.compressionRatio, 1.0)
        XCTAssertEqual(info.savedSpace, 0)
    }

    func testCacheMemoryInfoFromEntries() {
        let entry1 = CacheEntryRealm()
        entry1.originalSize = 1000
        entry1.compressedSize = 500

        let entry2 = CacheEntryRealm()
        entry2.originalSize = 2000
        entry2.compressedSize = 1000

        let info = CacheMemoryInfo.from(entries: [entry1, entry2])
        XCTAssertEqual(info.totalEntries, 2)
        XCTAssertEqual(info.totalOriginalSize, 3000)
        XCTAssertEqual(info.totalCompressedSize, 1500)
        XCTAssertEqual(info.compressionRatio, 0.5, accuracy: 0.01)
        XCTAssertEqual(info.savedSpace, 1500)
    }

    func testCacheMemoryInfoFormattedProperties() {
        let info = CacheMemoryInfo(
            totalEntries: 5,
            totalOriginalSize: 1024 * 1024,
            totalCompressedSize: 512 * 1024,
            compressionRatio: 0.5,
            savedSpace: 512 * 1024
        )
        XCTAssertTrue(info.formattedTotalOriginalSize.contains("MB"))
        XCTAssertTrue(info.formattedTotalCompressedSize.contains("KB") || info.formattedTotalCompressedSize.contains("MB"))
        XCTAssertTrue(info.formattedSavedSpace.contains("KB") || info.formattedSavedSpace.contains("MB"))
        XCTAssertEqual(info.formattedCompressionRatio, "50.0%")
    }

    // MARK: - CacheEntryInfo

    func testCacheEntryInfoInitFromRealmEntry() {
        let entry = CacheEntryRealm()
        entry.key = "info-key"
        entry.url = "https://cdn.example.com/bundle.js"
        entry.originalSize = 2048
        entry.compressedSize = 1024
        entry.compressionRatio = 0.5
        entry.accessCount = 3
        entry.mimeType = "application/javascript"
        entry.isCompressed = true

        let info = CacheEntryInfo(from: entry)
        XCTAssertEqual(info.key, "info-key")
        XCTAssertEqual(info.url, "https://cdn.example.com/bundle.js")
        XCTAssertEqual(info.originalSize, 2048)
        XCTAssertEqual(info.compressedSize, 1024)
        XCTAssertEqual(info.compressionRatio, 0.5)
        XCTAssertEqual(info.accessCount, 3)
        XCTAssertEqual(info.mimeType, "application/javascript")
        XCTAssertEqual(info.domain, "cdn.example.com")
        XCTAssertTrue(info.isCompressed)
    }

    func testCacheEntryInfoSavedSpace() {
        let entry = CacheEntryRealm()
        entry.originalSize = 5000
        entry.compressedSize = 1000
        let info = CacheEntryInfo(from: entry)
        XCTAssertEqual(info.savedSpace, 4000)
    }

    func testCacheEntryInfoFormattedProperties() {
        let entry = CacheEntryRealm()
        entry.originalSize = 1024
        entry.compressedSize = 512
        entry.compressionRatio = 0.5
        let info = CacheEntryInfo(from: entry)
        XCTAssertTrue(info.formattedOriginalSize.contains("KB"))
        XCTAssertTrue(info.formattedCompressedSize.contains("bytes") || info.formattedCompressedSize.contains("B"))
        XCTAssertTrue(info.formattedSavedSpace.contains("bytes") || info.formattedSavedSpace.contains("B"))
        XCTAssertEqual(info.formattedCompressionRatio, "50.0%")
    }

    func testCacheEntryInfoToDictionary() {
        let entry = CacheEntryRealm()
        entry.key = "dict-key"
        entry.url = "https://example.com/app.js"
        entry.originalSize = 1024
        entry.compressedSize = 512
        entry.compressionRatio = 0.5
        entry.accessCount = 1
        entry.mimeType = "application/javascript"
        entry.isCompressed = true

        let info = CacheEntryInfo(from: entry)
        let dict = info.toDictionary()

        XCTAssertEqual(dict["key"] as? String, "dict-key")
        XCTAssertEqual(dict["url"] as? String, "https://example.com/app.js")
        XCTAssertEqual(dict["originalSize"] as? Int64, 1024)
        XCTAssertEqual(dict["compressedSize"] as? Int64, 512)
        XCTAssertEqual(dict["savedSpace"] as? Int64, 512)
        XCTAssertEqual(dict["accessCount"] as? Int, 1)
        XCTAssertEqual(dict["mimeType"] as? String, "application/javascript")
        XCTAssertEqual(dict["isCompressed"] as? Bool, true)
        XCTAssertNotNil(dict["createdAt"])
        XCTAssertNotNil(dict["lastAccessedAt"])
        XCTAssertNotNil(dict["formattedOriginalSize"])
        XCTAssertNotNil(dict["formattedCompressedSize"])
        XCTAssertNotNil(dict["formattedSavedSpace"])
    }

    func testCacheEntryInfoResourceTypeFromEntry() {
        let entry = CacheEntryRealm()
        entry.url = "https://example.com/style.css"
        let info = CacheEntryInfo(from: entry)
        XCTAssertEqual(info.resourceType, "stylesheet")
    }
}
