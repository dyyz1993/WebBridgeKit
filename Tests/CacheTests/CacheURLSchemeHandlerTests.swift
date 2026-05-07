import XCTest
@testable import WebBridgeKit

final class CacheURLSchemeHandlerTests: XCTestCase {

    func testSharedInstance() {
        let handler = CacheURLSchemeHandler()
        XCTAssertNotNil(handler)
    }

    func testAccessStatsInitiallyEmpty() {
        let handler = CacheURLSchemeHandler()
        let stats = handler.getAccessStats()
        XCTAssertTrue(stats.isEmpty)
    }

    func testMimeTypeHTML() {
        XCTAssertEqual(getMimeTypeForPath("index.html"), "text/html; charset=utf-8")
    }

    func testMimeTypeHTM() {
        XCTAssertEqual(getMimeTypeForPath("page.htm"), "text/html; charset=utf-8")
    }

    func testMimeTypeCSS() {
        XCTAssertEqual(getMimeTypeForPath("style.css"), "text/css; charset=utf-8")
    }

    func testMimeTypeJS() {
        XCTAssertEqual(getMimeTypeForPath("app.js"), "application/javascript; charset=utf-8")
    }

    func testMimeTypeJSON() {
        XCTAssertEqual(getMimeTypeForPath("data.json"), "application/json; charset=utf-8")
    }

    func testMimeTypePNG() {
        XCTAssertEqual(getMimeTypeForPath("logo.png"), "image/png")
    }

    func testMimeTypeJPG() {
        XCTAssertEqual(getMimeTypeForPath("photo.jpg"), "image/jpeg")
    }

    func testMimeTypeJPEG() {
        XCTAssertEqual(getMimeTypeForPath("photo.jpeg"), "image/jpeg")
    }

    func testMimeTypeGIF() {
        XCTAssertEqual(getMimeTypeForPath("anim.gif"), "image/gif")
    }

    func testMimeTypeSVG() {
        XCTAssertEqual(getMimeTypeForPath("icon.svg"), "image/svg+xml")
    }

    func testMimeTypeWebP() {
        XCTAssertEqual(getMimeTypeForPath("img.webp"), "image/webp")
    }

    func testMimeTypeICO() {
        XCTAssertEqual(getMimeTypeForPath("favicon.ico"), "image/x-icon")
    }

    func testMimeTypeWOFF() {
        XCTAssertEqual(getMimeTypeForPath("font.woff"), "font/woff2")
    }

    func testMimeTypeWOFF2() {
        XCTAssertEqual(getMimeTypeForPath("font.woff2"), "font/woff2")
    }

    func testMimeTypeTTF() {
        XCTAssertEqual(getMimeTypeForPath("font.ttf"), "font/ttf")
    }

    func testMimeTypeEOT() {
        XCTAssertEqual(getMimeTypeForPath("font.eot"), "application/vnd.ms-fontobject")
    }

    func testMimeTypeMP4() {
        XCTAssertEqual(getMimeTypeForPath("video.mp4"), "video/mp4")
    }

    func testMimeTypeWebM() {
        XCTAssertEqual(getMimeTypeForPath("video.webm"), "video/webm")
    }

    func testMimeTypeMP3() {
        XCTAssertEqual(getMimeTypeForPath("audio.mp3"), "audio/mpeg")
    }

    func testMimeTypeWAV() {
        XCTAssertEqual(getMimeTypeForPath("sound.wav"), "audio/wav")
    }

    func testMimeTypePDF() {
        XCTAssertEqual(getMimeTypeForPath("doc.pdf"), "application/pdf")
    }

    func testMimeTypeUnknown() {
        XCTAssertEqual(getMimeTypeForPath("file.xyz"), "application/octet-stream")
    }

    func testMimeTypeNoExtension() {
        XCTAssertEqual(getMimeTypeForPath("noext"), "application/octet-stream")
    }

    func testMimeTypeEmpty() {
        XCTAssertEqual(getMimeTypeForPath(""), "application/octet-stream")
    }
}

private func getMimeTypeForPath(_ path: String) -> String {
    let ext = (path as NSString).pathExtension.lowercased()
    switch ext {
    case "html", "htm": return "text/html; charset=utf-8"
    case "css": return "text/css; charset=utf-8"
    case "js": return "application/javascript; charset=utf-8"
    case "json": return "application/json; charset=utf-8"
    case "png": return "image/png"
    case "jpg", "jpeg": return "image/jpeg"
    case "gif": return "image/gif"
    case "svg": return "image/svg+xml"
    case "webp": return "image/webp"
    case "ico": return "image/x-icon"
    case "woff", "woff2": return "font/woff2"
    case "ttf": return "font/ttf"
    case "eot": return "application/vnd.ms-fontobject"
    case "mp4": return "video/mp4"
    case "webm": return "video/webm"
    case "mp3": return "audio/mpeg"
    case "wav": return "audio/wav"
    case "pdf": return "application/pdf"
    default: return "application/octet-stream"
    }
}
