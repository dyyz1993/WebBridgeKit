import XCTest
import UIKit
@testable import WebBridgeKit

final class LetterIconTests: XCTestCase {

    func testLetterIconWithValidText() {
        let imageView = UIImageView()
        imageView.setLetterIcon(for: "Apple", size: CGSize(width: 40, height: 40))
        XCTAssertNotNil(imageView.image)
    }

    func testLetterIconWithNilText() {
        let imageView = UIImageView()
        imageView.setLetterIcon(for: nil, size: CGSize(width: 40, height: 40))
        XCTAssertNotNil(imageView.image)
    }

    func testLetterIconWithEmptyText() {
        let imageView = UIImageView()
        imageView.setLetterIcon(for: "", size: CGSize(width: 40, height: 40))
        XCTAssertNotNil(imageView.image)
    }

    func testLetterIconWithUnicodeText() {
        let imageView = UIImageView()
        imageView.setLetterIcon(for: "中文", size: CGSize(width: 40, height: 40))
        XCTAssertNotNil(imageView.image)
    }

    func testLetterIconWithCustomSize() {
        let imageView = UIImageView()
        let customSize = CGSize(width: 80, height: 80)
        imageView.setLetterIcon(for: "Test", size: customSize)
        XCTAssertNotNil(imageView.image)
        XCTAssertEqual(imageView.image?.size.width, customSize.width)
        XCTAssertEqual(imageView.image?.size.height, customSize.height)
    }

    func testLetterIconConsistentColorForSameText() {
        let imageView1 = UIImageView()
        let imageView2 = UIImageView()
        imageView1.setLetterIcon(for: "example.com")
        imageView2.setLetterIcon(for: "example.com")
        XCTAssertNotNil(imageView1.image)
        XCTAssertNotNil(imageView2.image)
        XCTAssertEqual(imageView1.image?.size, imageView2.image?.size)
    }
}
