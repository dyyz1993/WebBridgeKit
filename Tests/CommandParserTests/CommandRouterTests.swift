import XCTest
@testable import WebBridgeKit

final class CommandRouterTests: XCTestCase {

    private var router: CommandRouter!

    override func setUp() {
        super.setUp()
        router = CommandRouter()
    }

    // MARK: - Singleton

    func testSharedIsSingleton() {
        let a = CommandRouter.shared
        let b = CommandRouter.shared
        XCTAssertTrue(a === b)
    }

    // MARK: - route - cachedApp

    func testRoute_withAppid_returnsCachedApp() {
        let payload = CommandPayload(appid: "shop")
        let result = router.route(payload)
        XCTAssertEqual(result, .cachedApp(appid: "shop"))
    }

    func testRoute_withAppidAndUrl_returnsCachedApp() {
        let payload = CommandPayload(appid: "shop", url: "https://example.com")
        let result = router.route(payload)
        XCTAssertEqual(result, .cachedApp(appid: "shop"))
    }

    func testRoute_withAppidAndAllFields_returnsCachedApp() {
        let payload = CommandPayload(
            appid: "myapp",
            url: "https://example.com",
            title: "Title",
            token: "tok",
            extra: ["k": "v"]
        )
        let result = router.route(payload)
        XCTAssertEqual(result, .cachedApp(appid: "myapp"))
    }

    // MARK: - route - URL (http/https)

    func testRoute_withHttpUrl_returnsURL() {
        let payload = CommandPayload(appid: "", url: "http://example.com")
        let result = router.route(payload)
        XCTAssertEqual(result, .url(url: "http://example.com"))
    }

    func testRoute_withHttpsUrl_returnsURL() {
        let payload = CommandPayload(appid: "", url: "https://example.com/path?q=1")
        let result = router.route(payload)
        XCTAssertEqual(result, .url(url: "https://example.com/path?q=1"))
    }

    func testRoute_emptyAppidWithHttpsUrl_returnsURL() {
        let payload = CommandPayload(appid: "", url: "https://example.com")
        let result = router.route(payload)
        XCTAssertEqual(result, .url(url: "https://example.com"))
    }

    // MARK: - route - Deeplink

    func testRoute_withCustomSchemeUrl_returnsDeeplink() {
        let payload = CommandPayload(appid: "", url: "myapp://open?page=home")
        let result = router.route(payload)
        XCTAssertEqual(result, .deeplink(url: "myapp://open?page=home"))
    }

    func testRoute_withTelScheme_returnsDeeplink() {
        let payload = CommandPayload(appid: "", url: "tel:+1234567890")
        let result = router.route(payload)
        XCTAssertEqual(result, .deeplink(url: "tel:+1234567890"))
    }

    func testRoute_withMailtoScheme_returnsDeeplink() {
        let payload = CommandPayload(appid: "", url: "mailto:user@example.com")
        let result = router.route(payload)
        XCTAssertEqual(result, .deeplink(url: "mailto:user@example.com"))
    }

    func testRoute_withWbskScheme_returnsDeeplink() {
        let payload = CommandPayload(appid: "", url: "wbsk://command?action=test")
        let result = router.route(payload)
        XCTAssertEqual(result, .deeplink(url: "wbsk://command?action=test"))
    }

    // MARK: - route - None

    func testRoute_emptyAppidNilUrl_returnsNone() {
        let payload = CommandPayload(appid: "")
        let result = router.route(payload)
        XCTAssertEqual(result, .none)
    }

    func testRoute_emptyAppidEmptyUrl_returnsNone() {
        let payload = CommandPayload(appid: "", url: "")
        let result = router.route(payload)
        XCTAssertEqual(result, .none)
    }

    // MARK: - route - Edge Cases

    func testRoute_emptyAppidInvalidUrl_returnsURL() {
        let payload = CommandPayload(appid: "", url: "not a valid url with spaces")
        let result = router.route(payload)
        XCTAssertEqual(result, .url(url: "not a valid url with spaces"))
    }

    func testRoute_httpUrlCaseInsensitive_returnsDeeplink() {
        let payload = CommandPayload(appid: "", url: "HTTP://EXAMPLE.COM")
        let result = router.route(payload)
        XCTAssertEqual(result, .deeplink(url: "HTTP://EXAMPLE.COM"))
    }

    func testRoute_httpsUrlCaseInsensitive_returnsDeeplink() {
        let payload = CommandPayload(appid: "", url: "HTTPS://EXAMPLE.COM")
        let result = router.route(payload)
        XCTAssertEqual(result, .deeplink(url: "HTTPS://EXAMPLE.COM"))
    }

    func testRoute_appidTakesPriorityOverUrl() {
        let payload = CommandPayload(appid: "priority", url: "myapp://deep")
        let result = router.route(payload)
        XCTAssertEqual(result, .cachedApp(appid: "priority"))
    }
}
