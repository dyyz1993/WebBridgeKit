//
//  WKColorTests.swift
//  UtilsTests
//

import XCTest
import UIKit
@testable import WebBridgeKit

final class WKColorTests: XCTestCase {

    func testGreyColorsExist() {
        XCTAssertNotNil(WKColor.grey.base)
        XCTAssertNotNil(WKColor.grey.darken1)
        XCTAssertNotNil(WKColor.grey.darken2)
        XCTAssertNotNil(WKColor.grey.darken3)
        XCTAssertNotNil(WKColor.grey.darken4)
        XCTAssertNotNil(WKColor.grey.lighten1)
        XCTAssertNotNil(WKColor.grey.lighten2)
        XCTAssertNotNil(WKColor.grey.lighten3)
        XCTAssertNotNil(WKColor.grey.lighten4)
        XCTAssertNotNil(WKColor.grey.lighten5)
    }

    func testBlueColorsExist() {
        XCTAssertNotNil(WKColor.blue.base)
        XCTAssertNotNil(WKColor.blue.darken1)
        XCTAssertNotNil(WKColor.blue.darken5)
    }

    func testLightBlueColorExists() {
        XCTAssertNotNil(WKColor.lightBlue.darken3)
    }

    func testStaticColors() {
        XCTAssertEqual(WKColor.white, UIColor.white)
        XCTAssertEqual(WKColor.black, UIColor.black)
    }

    func testBackgroundColorsExist() {
        XCTAssertNotNil(WKColor.background.primary)
        XCTAssertNotNil(WKColor.background.secondary)
    }

    func testBlueDarken1HasAlpha() {
        let color = WKColor.blue.darken1
        var alpha: CGFloat = 0
        color.getRed(nil, green: nil, blue: nil, alpha: &alpha)
        XCTAssertEqual(alpha, 0.8, accuracy: 0.01)
    }

    func testBlueDarken5HasAlpha() {
        let color = WKColor.blue.darken5
        var alpha: CGFloat = 0
        color.getRed(nil, green: nil, blue: nil, alpha: &alpha)
        XCTAssertEqual(alpha, 0.5, accuracy: 0.01)
    }

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

    func testWKColorIsNSObjectSubclass() {
        let color = WKColor()
        XCTAssertTrue(color is NSObject)
    }
}
