import XCTest
@testable import WebBridgeKit

final class CacheMemoryInfoTests: XCTestCase {

    func testCacheMemoryInfoInit() {
        let info = CacheMemoryInfo(
            totalEntries: 10,
            totalOriginalSize: 1000,
            totalCompressedSize: 500,
            compressionRatio: 0.5,
            savedSpace: 500
        )
        XCTAssertEqual(info.totalEntries, 10)
        XCTAssertEqual(info.totalOriginalSize, 1000)
        XCTAssertEqual(info.totalCompressedSize, 500)
        XCTAssertEqual(info.compressionRatio, 0.5)
        XCTAssertEqual(info.savedSpace, 500)
    }

    func testFormattedTotalOriginalSize() {
        let info = CacheMemoryInfo(
            totalEntries: 0,
            totalOriginalSize: 1536,
            totalCompressedSize: 0,
            compressionRatio: 1.0,
            savedSpace: 1536
        )
        XCTAssertFalse(info.formattedTotalOriginalSize.isEmpty)
    }

    func testFormattedTotalCompressedSize() {
        let info = CacheMemoryInfo(
            totalEntries: 0,
            totalOriginalSize: 0,
            totalCompressedSize: 2048,
            compressionRatio: 1.0,
            savedSpace: 0
        )
        XCTAssertFalse(info.formattedTotalCompressedSize.isEmpty)
    }

    func testFormattedSavedSpace() {
        let info = CacheMemoryInfo(
            totalEntries: 0,
            totalOriginalSize: 1024,
            totalCompressedSize: 512,
            compressionRatio: 0.5,
            savedSpace: 512
        )
        XCTAssertFalse(info.formattedSavedSpace.isEmpty)
    }

    func testFormattedCompressionRatio() {
        let info = CacheMemoryInfo(
            totalEntries: 0,
            totalOriginalSize: 1000,
            totalCompressedSize: 750,
            compressionRatio: 0.75,
            savedSpace: 250
        )
        XCTAssertTrue(info.formattedCompressionRatio.contains("75"))
    }

    func testFormattedCompressionRatioZeroPercent() {
        let info = CacheMemoryInfo(
            totalEntries: 0,
            totalOriginalSize: 100,
            totalCompressedSize: 0,
            compressionRatio: 0.0,
            savedSpace: 100
        )
        XCTAssertTrue(info.formattedCompressionRatio.contains("0"))
    }

    func testFromEmptyEntries() {
        let info = CacheMemoryInfo.from(entries: [])
        XCTAssertEqual(info.totalEntries, 0)
        XCTAssertEqual(info.totalOriginalSize, 0)
        XCTAssertEqual(info.totalCompressedSize, 0)
        XCTAssertEqual(info.compressionRatio, 1.0)
        XCTAssertEqual(info.savedSpace, 0)
    }

    func testFormattedZeroSize() {
        let info = CacheMemoryInfo(
            totalEntries: 0,
            totalOriginalSize: 0,
            totalCompressedSize: 0,
            compressionRatio: 1.0,
            savedSpace: 0
        )
        XCTAssertFalse(info.formattedTotalOriginalSize.isEmpty)
        XCTAssertFalse(info.formattedTotalCompressedSize.isEmpty)
        XCTAssertFalse(info.formattedSavedSpace.isEmpty)
    }
}
