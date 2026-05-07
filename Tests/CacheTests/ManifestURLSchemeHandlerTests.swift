import XCTest
@testable import WebBridgeKit

final class ManifestURLSchemeHandlerTests: XCTestCase {

    func testInit() {
        let handler = ManifestURLSchemeHandler()
        XCTAssertNotNil(handler)
    }

    func testManifestCacheErrorDescriptions() {
        let errors: [ManifestCacheError] = [
            .managerDeallocated,
            .resourceNotFound("/path/to/file"),
            .emptyData,
            .invalidURL
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    func testManifestCacheErrorManagerDeallocated() {
        let error = ManifestCacheError.managerDeallocated
        XCTAssertEqual(error.errorDescription, "Manager was deallocated")
    }

    func testManifestCacheErrorResourceNotFound() {
        let error = ManifestCacheError.resourceNotFound("/css/style.css")
        XCTAssertTrue(error.errorDescription!.contains("/css/style.css"))
    }

    func testManifestCacheErrorEmptyData() {
        let error = ManifestCacheError.emptyData
        XCTAssertEqual(error.errorDescription, "Empty data received")
    }

    func testManifestCacheErrorInvalidURL() {
        let error = ManifestCacheError.invalidURL
        XCTAssertEqual(error.errorDescription, "Invalid URL")
    }

    func testGetMimeTypeHTML() {
        XCTAssertEqual(schemeHandlerMimeType("page.html"), "text/html")
        XCTAssertEqual(schemeHandlerMimeType("page.htm"), "text/html")
    }

    func testGetMimeTypeJS() {
        XCTAssertEqual(schemeHandlerMimeType("app.js"), "application/javascript")
    }

    func testGetMimeTypeCSS() {
        XCTAssertEqual(schemeHandlerMimeType("style.css"), "text/css")
    }

    func testGetMimeTypeJSON() {
        XCTAssertEqual(schemeHandlerMimeType("data.json"), "application/json")
    }

    func testGetMimeTypeImages() {
        XCTAssertEqual(schemeHandlerMimeType("logo.png"), "image/png")
        XCTAssertEqual(schemeHandlerMimeType("photo.jpg"), "image/jpeg")
        XCTAssertEqual(schemeHandlerMimeType("photo.jpeg"), "image/jpeg")
        XCTAssertEqual(schemeHandlerMimeType("anim.gif"), "image/gif")
        XCTAssertEqual(schemeHandlerMimeType("icon.svg"), "image/svg+xml")
    }

    func testGetMimeTypeUnknown() {
        XCTAssertEqual(schemeHandlerMimeType("file.xyz"), "application/octet-stream")
    }

    func testExtractRelativePathCustomScheme() {
        let url = URL(string: "custom://res/style.css")!
        let path = extractRelativePath(from: url)
        XCTAssertEqual(path, "res/style.css")
    }

    func testExtractRelativePathWBResource() {
        let url = URL(string: "wb-resource://abc123/css/style.css")!
        let path = extractRelativePath(from: url)
        XCTAssertEqual(path, "css/style.css")
    }

    func testSetPageKey() {
        let handler = ManifestURLSchemeHandler()
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        handler.setPageKey("test-page", for: webView)
    }

    func testCleanupPage() {
        let handler = ManifestURLSchemeHandler()
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        handler.cleanupPage(for: webView)
    }

    func testRegisterAndUnregisterManifest() {
        let handler = ManifestURLSchemeHandler()
        let manifest: [String: String] = [
            "res/style.css": "https://example.com/style.css",
            "res/app.js": "https://example.com/app.js"
        ]
        handler.registerManifest(forPage: "test-page", manifest: manifest)
        handler.unregisterManifest(forPage: "test-page")
    }
}

private func schemeHandlerMimeType(_ path: String) -> String {
    let ext = (path as NSString).pathExtension.lowercased()
    switch ext {
    case "html", "htm": return "text/html"
    case "js": return "application/javascript"
    case "css": return "text/css"
    case "json": return "application/json"
    case "png": return "image/png"
    case "jpg", "jpeg": return "image/jpeg"
    case "gif": return "image/gif"
    case "svg": return "image/svg+xml"
    default: return "application/octet-stream"
    }
}

private func extractRelativePath(from url: URL) -> String {
    let absoluteString = url.absoluteString
    if absoluteString.hasPrefix("wb-resource://") {
        let pathWithoutScheme = absoluteString.replacingOccurrences(of: "wb-resource://", with: "")
        if let firstSlashIndex = pathWithoutScheme.firstIndex(of: "/") {
            return String(pathWithoutScheme[firstSlashIndex...].dropFirst())
        }
    }
    if absoluteString.hasPrefix("custom://") {
        let path = url.path
        let host = url.host ?? ""
        if !host.isEmpty {
            let fullPath = host + path
            return fullPath.hasPrefix("/") ? String(fullPath.dropFirst()) : fullPath
        }
        return path.hasPrefix("/") ? String(path.dropFirst()) : path
    }
    return url.path.hasPrefix("/") ? String(url.path.dropFirst()) : url.path
}
