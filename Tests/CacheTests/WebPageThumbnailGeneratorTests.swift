import XCTest
@testable import WebBridgeKit

final class WebPageThumbnailGeneratorTests: XCTestCase {

    func testSharedInstance() {
        let generator = WebPageThumbnailGenerator.shared
        XCTAssertNotNil(generator)
    }

    func testThumbnailSize() {
        let generator = WebPageThumbnailGenerator.shared
        XCTAssertEqual(generator.thumbnailSize.width, 300)
        XCTAssertEqual(generator.thumbnailSize.height, 400)
    }

    func testMaxMemoryMB() {
        let generator = WebPageThumbnailGenerator.shared
        XCTAssertEqual(generator.maxMemoryMB, 50)
    }

    func testCompressionQuality() {
        let generator = WebPageThumbnailGenerator.shared
        XCTAssertEqual(generator.compressionQuality, 0.7)
    }
}
