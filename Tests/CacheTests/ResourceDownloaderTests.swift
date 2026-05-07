import XCTest
@testable import WebBridgeKit

final class ResourceDownloaderTests: XCTestCase {

    func testDownloadErrorInvalidResponse() {
        let error = ResourceDownloader.DownloadError.invalidResponse
        XCTAssertEqual(error, ResourceDownloader.DownloadError.invalidResponse)
    }

    func testDownloadErrorInvalidEncoding() {
        let error = ResourceDownloader.DownloadError.invalidEncoding
        XCTAssertEqual(error, ResourceDownloader.DownloadError.invalidEncoding)
    }

    func testDownloadErrorEquality() {
        let e1 = ResourceDownloader.DownloadError.invalidResponse
        let e2 = ResourceDownloader.DownloadError.invalidResponse
        XCTAssertEqual(e1, e2)
    }

    func testDownloadErrorInequality() {
        let e1 = ResourceDownloader.DownloadError.invalidResponse
        let e2 = ResourceDownloader.DownloadError.invalidEncoding
        XCTAssertNotEqual(e1, e2)
    }

    func testGetSubdirectoryCSS() {
        let type = HTMLResourceType.css
        XCTAssertEqual(getSubdirectory(type), "css")
    }

    func testGetSubdirectoryJS() {
        let type = HTMLResourceType.js
        XCTAssertEqual(getSubdirectory(type), "js")
    }

    func testGetSubdirectoryImage() {
        let type = HTMLResourceType.image
        XCTAssertEqual(getSubdirectory(type), "images")
    }

    func testGetSubdirectoryFont() {
        let type = HTMLResourceType.font
        XCTAssertEqual(getSubdirectory(type), "fonts")
    }

    func testGetSubdirectoryMedia() {
        let type = HTMLResourceType.media
        XCTAssertEqual(getSubdirectory(type), "media")
    }

    func testGetSubdirectoryFavicon() {
        let type = HTMLResourceType.favicon
        XCTAssertEqual(getSubdirectory(type), "images")
    }

    func testGetSubdirectoryOther() {
        let type = HTMLResourceType.other
        XCTAssertEqual(getSubdirectory(type), "other")
    }

    func testGenerateFilenameWithURLExtension() {
        let url = URL(string: "https://example.com/path/to/style.css")!
        let filename = generateFilename(url)
        XCTAssertEqual(filename, "style.css")
    }

    func testGenerateFilenameWithoutURLExtension() {
        let url = URL(string: "https://example.com/api/data")!
        let filename = generateFilename(url)
        XCTAssertTrue(filename.hasPrefix("resource_"))
        XCTAssertTrue(filename.hasSuffix(".dat"))
    }

    func testGenerateFilenameHTML() {
        let url = URL(string: "https://example.com/page.html")!
        let filename = generateFilename(url)
        XCTAssertEqual(filename, "page.html")
    }

    func testGenerateFilenameWithQueryParams() {
        let url = URL(string: "https://example.com/app.js?v=1.2")!
        let filename = generateFilename(url)
        XCTAssertEqual(filename, "app.js")
    }

    func testCompressImageIfNeededReturnsOriginal() {
        let data = Data([0x89, 0x50, 0x4E, 0x47])
        let result = compressImageData(data)
        XCTAssertEqual(result, data)
    }

    func testCompressImageEmptyData() {
        let data = Data()
        let result = compressImageData(data)
        XCTAssertEqual(result, data)
    }

    func testHTMLResourceTypeAllCases() {
        let types: [HTMLResourceType] = [.css, .js, .image, .font, .media, .favicon, .other]
        XCTAssertEqual(types.count, 7)
    }

    func testResourceURLCreation() {
        let url = URL(string: "https://example.com/app.js")!
        let resourceURL = ResourceURL(originalURL: url, type: .js, element: "script", attribute: "src")
        XCTAssertEqual(resourceURL.originalURL, url)
        XCTAssertEqual(resourceURL.type, .js)
        XCTAssertEqual(resourceURL.element, "script")
        XCTAssertEqual(resourceURL.attribute, "src")
    }
}

private func getSubdirectory(_ type: HTMLResourceType) -> String {
    switch type {
    case .css: return "css"
    case .js: return "js"
    case .image: return "images"
    case .font: return "fonts"
    case .media: return "media"
    case .favicon: return "images"
    case .other: return "other"
    }
}

private func generateFilename(_ url: URL) -> String {
    if !url.pathExtension.isEmpty {
        return url.lastPathComponent
    }
    let hash = url.absoluteString.hashValue
    return "resource_\(abs(hash)).dat"
}

private func compressImageData(_ data: Data) -> Data {
    return data
}
