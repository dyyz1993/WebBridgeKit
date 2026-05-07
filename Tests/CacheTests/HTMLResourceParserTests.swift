import XCTest
@testable import WebBridgeKit

final class HTMLResourceParserTests: XCTestCase {

    private var parser: HTMLResourceParser!

    override func setUp() {
        super.setUp()
        parser = HTMLResourceParser()
    }

    // MARK: - CSS Links

    func testExtractCSSLinks() {
        let html = """
        <html>
        <head>
            <link rel="stylesheet" href="styles/main.css">
            <link rel="stylesheet" href="https://cdn.example.com/bootstrap.css">
        </head>
        </html>
        """
        let baseURL = URL(string: "https://example.com/page")!

        let resources = parser.parseResources(html: html, baseURL: baseURL)
        let cssResources = resources.filter { $0.type == .css }

        XCTAssertEqual(cssResources.count, 2)
        XCTAssertTrue(cssResources.contains { $0.originalURL.absoluteString.contains("main.css") })
        XCTAssertTrue(cssResources.contains { $0.originalURL.absoluteString.contains("bootstrap.css") })
    }

    func testExtractCSSLinkWithSingleQuotes() {
        let html = """
        <html><head>
            <link rel='stylesheet' href='theme.css'>
        </head></html>
        """
        let baseURL = URL(string: "https://example.com/")!

        let resources = parser.parseResources(html: html, baseURL: baseURL)
        let cssResources = resources.filter { $0.type == .css }

        XCTAssertEqual(cssResources.count, 1)
        XCTAssertTrue(cssResources.first?.originalURL.absoluteString.contains("theme.css") == true)
    }

    // MARK: - JS Scripts

    func testExtractScriptTags() {
        let html = """
        <html><body>
            <script src="app.js"></script>
            <script src="https://cdn.example.com/analytics.js"></script>
        </body></html>
        """
        let baseURL = URL(string: "https://example.com/page")!

        let resources = parser.parseResources(html: html, baseURL: baseURL)
        let jsResources = resources.filter { $0.type == .js }

        XCTAssertEqual(jsResources.count, 2)
        XCTAssertTrue(jsResources.contains { $0.originalURL.absoluteString.contains("app.js") })
        XCTAssertTrue(jsResources.contains { $0.originalURL.absoluteString.contains("analytics.js") })
    }

    // MARK: - Images

    func testExtractImageTags() {
        let html = """
        <html><body>
            <img src="logo.png" alt="Logo">
            <img src="https://cdn.example.com/banner.jpg" alt="Banner">
        </body></html>
        """
        let baseURL = URL(string: "https://example.com/page")!

        let resources = parser.parseResources(html: html, baseURL: baseURL)
        let imageResources = resources.filter { $0.type == .image }

        XCTAssertEqual(imageResources.count, 2)
    }

    // MARK: - Favicon

    func testExtractFavicon() {
        let html = """
        <html><head>
            <link rel="icon" href="favicon.ico">
            <link rel="shortcut icon" href="favicon-32.png">
        </head></html>
        """
        let baseURL = URL(string: "https://example.com/")!

        let resources = parser.parseResources(html: html, baseURL: baseURL)
        let faviconResources = resources.filter { $0.type == .favicon }

        XCTAssertEqual(faviconResources.count, 2)
    }

    // MARK: - Media Tags

    func testExtractVideoTags() {
        let html = """
        <html><body>
            <video src="intro.mp4"></video>
        </body></html>
        """
        let baseURL = URL(string: "https://example.com/")!

        let resources = parser.parseResources(html: html, baseURL: baseURL)
        let mediaResources = resources.filter { $0.type == .media }

        XCTAssertEqual(mediaResources.count, 1)
    }

    func testExtractAudioTags() {
        let html = """
        <html><body>
            <audio src="podcast.mp3"></audio>
        </body></html>
        """
        let baseURL = URL(string: "https://example.com/")!

        let resources = parser.parseResources(html: html, baseURL: baseURL)
        let mediaResources = resources.filter { $0.type == .media }

        XCTAssertEqual(mediaResources.count, 1)
    }

    // MARK: - Relative URLs

    func testRelativeURLResolution() {
        let html = """
        <html><head>
            <link rel="stylesheet" href="css/style.css">
            <script src="js/app.js"></script>
            <img src="images/photo.png">
        </head></html>
        """
        let baseURL = URL(string: "https://example.com/app/index.html")!

        let resources = parser.parseResources(html: html, baseURL: baseURL)

        XCTAssertTrue(resources.contains { $0.originalURL.absoluteString.contains("css/style.css") })
        XCTAssertTrue(resources.contains { $0.originalURL.absoluteString.contains("js/app.js") })
        XCTAssertTrue(resources.contains { $0.originalURL.absoluteString.contains("images/photo.png") })
    }

    // MARK: - Skip data: and javascript: URLs

    func testSkipsDataURLs() {
        let html = """
        <html><body>
            <img src="data:image/png;base64,iVBOR...">
        </body></html>
        """
        let baseURL = URL(string: "https://example.com/")!

        let resources = parser.parseResources(html: html, baseURL: baseURL)
        XCTAssertTrue(resources.isEmpty)
    }

    func testSkipsJavaScriptURLs() {
        let html = """
        <html><body>
            <a href="javascript:void(0)">click</a>
        </body></html>
        """
        let baseURL = URL(string: "https://example.com/")!

        let resources = parser.parseResources(html: html, baseURL: baseURL)
        let jsTypeResources = resources.filter { $0.type == .js }
        XCTAssertTrue(jsTypeResources.isEmpty)
    }

    // MARK: - Empty / Invalid HTML

    func testEmptyHTMLReturnsNoResources() {
        let html = ""
        let baseURL = URL(string: "https://example.com/")!

        let resources = parser.parseResources(html: html, baseURL: baseURL)
        XCTAssertTrue(resources.isEmpty)
    }

    func testHTMLWithNoResourcesReturnsEmpty() {
        let html = """
        <html><head><title>Hello</title></head><body><p>No resources here</p></body></html>
        """
        let baseURL = URL(string: "https://example.com/")!

        let resources = parser.parseResources(html: html, baseURL: baseURL)
        XCTAssertTrue(resources.isEmpty)
    }

    func testMalformedHTMLStillExtractsResources() {
        let html = """
        <html><head>
            <link rel="stylesheet" href="style.css">
            <script src="app.js"></script>
            <img src="photo.jpg"
        </body></html>
        """
        let baseURL = URL(string: "https://example.com/")!

        let resources = parser.parseResources(html: html, baseURL: baseURL)
        XCTAssertGreaterThanOrEqual(resources.count, 2)
    }

    // MARK: - Deduplication

    func testDeduplicatesSameURL() {
        let html = """
        <html><body>
            <img src="logo.png">
            <img src="logo.png">
            <img src="logo.png">
        </body></html>
        """
        let baseURL = URL(string: "https://example.com/")!

        let resources = parser.parseResources(html: html, baseURL: baseURL)
        let imageResources = resources.filter { $0.type == .image }

        XCTAssertEqual(imageResources.count, 1)
    }

    // MARK: - Mixed Resource Types

    func testExtractsAllResourceTypes() {
        let html = """
        <html>
        <head>
            <link rel="stylesheet" href="style.css">
            <link rel="icon" href="favicon.ico">
            <script src="app.js"></script>
        </head>
        <body>
            <img src="hero.jpg">
            <video src="intro.mp4"></video>
        </body>
        </html>
        """
        let baseURL = URL(string: "https://example.com/")!

        let resources = parser.parseResources(html: html, baseURL: baseURL)

        let cssCount = resources.filter { $0.type == .css }.count
        let jsCount = resources.filter { $0.type == .js }.count
        let imageCount = resources.filter { $0.type == .image }.count
        let mediaCount = resources.filter { $0.type == .media }.count
        let faviconCount = resources.filter { $0.type == .favicon }.count

        XCTAssertEqual(cssCount, 1)
        XCTAssertEqual(jsCount, 1)
        XCTAssertEqual(imageCount, 1)
        XCTAssertEqual(mediaCount, 1)
        XCTAssertEqual(faviconCount, 1)
        XCTAssertEqual(resources.count, 5)
    }

    // MARK: - Resource Element and Attribute

    func testResourceElementAndAttribute() {
        let html = """
        <html>
        <head>
            <link rel="stylesheet" href="style.css">
            <script src="app.js"></script>
        </head>
        <body>
            <img src="photo.jpg">
        </body>
        </html>
        """
        let baseURL = URL(string: "https://example.com/")!

        let resources = parser.parseResources(html: html, baseURL: baseURL)

        let cssResource = resources.first { $0.type == .css }
        XCTAssertEqual(cssResource?.element, "link")
        XCTAssertEqual(cssResource?.attribute, "href")

        let jsResource = resources.first { $0.type == .js }
        XCTAssertEqual(jsResource?.element, "script")
        XCTAssertEqual(jsResource?.attribute, "src")

        let imgResource = resources.first { $0.type == .image }
        XCTAssertEqual(imgResource?.element, "img")
        XCTAssertEqual(imgResource?.attribute, "src")
    }

    // MARK: - URL Rewriting

    func testRewriteURLs() {
        let html = """
        <html>
        <head>
            <link rel="stylesheet" href="https://cdn.example.com/style.css">
            <script src="https://cdn.example.com/app.js"></script>
        </head>
        <body>
            <img src="https://cdn.example.com/logo.png">
        </body>
        </html>
        """
        let baseURL = URL(string: "https://example.com/")!
        let uuid = "test-uuid-1234"

        let rewritten = parser.rewriteURLs(html: html, baseURL: baseURL, uuid: uuid)

        XCTAssertTrue(rewritten.contains("bark-cache://\(uuid)/resources/css/style.css"))
        XCTAssertTrue(rewritten.contains("bark-cache://\(uuid)/resources/js/app.js"))
        XCTAssertTrue(rewritten.contains("bark-cache://\(uuid)/resources/images/logo.png"))
    }

    func testRewriteURLsPreservesNonResourceHTML() {
        let html = """
        <html><head><title>My Page</title></head>
        <body><p>Hello World</p></body></html>
        """
        let baseURL = URL(string: "https://example.com/")!

        let rewritten = parser.rewriteURLs(html: html, baseURL: baseURL, uuid: "uuid")

        XCTAssertTrue(rewritten.contains("My Page"))
        XCTAssertTrue(rewritten.contains("Hello World"))
    }

    // MARK: - Protocol-Relative URLs

    func testSkipsProtocolRelativeURLs() {
        let html = """
        <html><head>
            <script src="//cdn.example.com/app.js"></script>
        </head></html>
        """
        let baseURL = URL(string: "https://example.com/")!

        let resources = parser.parseResources(html: html, baseURL: baseURL)
        XCTAssertTrue(resources.isEmpty)
    }
}
