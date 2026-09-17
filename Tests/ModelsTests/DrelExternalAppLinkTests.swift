import XCTest
@testable import WebBridgeKit

final class DrelExternalAppLinkTests: XCTestCase {

    func testParsesAppIDRouteAndNamespacedParameters() {
        // Fully percent-encoded, as a real sender (URLComponents) produces it.
        let url = URL(string: "drel://app?app_id=dev.drel.data-template&route=/test/template/v1/index.html&param_title=%E5%8F%91%E5%B8%83%E5%AE%8C%E6%88%90&param_body=all%20checks%20passed")!

        let link = DrelExternalAppLink.parse(url)

        XCTAssertEqual(link?.appID, "dev.drel.data-template")
        XCTAssertEqual(link?.route, "/test/template/v1/index.html")
        XCTAssertEqual(link?.parameters, ["title": "发布完成", "body": "all checks passed"])
    }

    func testRouteOptionalAndUnknownQueryKeysIgnored() {
        let url = URL(string: "drel://app?app_id=com.example.chat&param_a=1&mode=immersive&param_=x")!

        let link = DrelExternalAppLink.parse(url)

        XCTAssertEqual(link?.appID, "com.example.chat")
        XCTAssertNil(link?.route)
        // Host vocabulary (`mode`) and empty param names must not leak through.
        XCTAssertEqual(link?.parameters, ["a": "1"])
    }

    func testRejectsMissingAppIDWrongSchemeOrHost() {
        XCTAssertNil(DrelExternalAppLink.parse(URL(string: "drel://app")!))
        XCTAssertNil(DrelExternalAppLink.parse(URL(string: "drel://app?route=/x")!))
        XCTAssertNil(DrelExternalAppLink.parse(URL(string: "webbridgekit://app?app_id=a")!))
        XCTAssertNil(DrelExternalAppLink.parse(URL(string: "drel://self-hosted-push?server=https://x")!))
        XCTAssertNil(DrelExternalAppLink.parse(URL(string: "https://drel.app")!))
    }

    func testSchemeAndHostCaseInsensitive() {
        let link = DrelExternalAppLink.parse(URL(string: "DREL://APP?app_id=a.b")!)
        XCTAssertEqual(link?.appID, "a.b")
    }
}
