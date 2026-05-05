import XCTest
@testable import WebBridgeKit

final class MessageRouterTests: XCTestCase {
    
    var router: MessageRouter!
    
    override func setUp() {
        super.setUp()
        router = MessageRouter()
    }
    
    // MARK: - App Routing
    
    func testRouteByAppId() {
        let payload = MessagePayload(
            title: "Test",
            body: "Body",
            channel: "test",
            targetAppId: "myapp",
            targetMode: "immersive"
        )
        
        let target = router.route(payload: payload)
        
        XCTAssertEqual(target.type, .appId)
        XCTAssertEqual(target.destination, "myapp")
        XCTAssertEqual(target.mode, "immersive")
    }
    
    // MARK: - URL Routing
    
    func testRouteByURL() {
        let payload = MessagePayload(
            title: "Test",
            body: "Body",
            channel: "test",
            targetURL: "https://example.com/page"
        )
        
        let target = router.route(payload: payload)
        
        XCTAssertEqual(target.type, .url)
        XCTAssertEqual(target.destination, "https://example.com/page")
    }
    
    // MARK: - Deep Link Routing
    
    func testRouteByDeepLink() {
        let payload = MessagePayload(
            title: "Test",
            body: "Body",
            channel: "test",
            targetURL: "myapp://detail?id=123"
        )
        
        let target = router.route(payload: payload)
        
        XCTAssertEqual(target.type, .deeplink)
        XCTAssertEqual(target.destination, "myapp://detail?id=123")
    }
    
    // MARK: - User Info Routing
    
    func testRouteByUserInfoAppId() {
        let payload = MessagePayload(
            title: "Test",
            body: "Body",
            channel: "test",
            userInfo: ["appid": "testapp", "mode": "modal"]
        )
        
        let target = router.route(payload: payload)
        
        XCTAssertEqual(target.type, .appId)
        XCTAssertEqual(target.destination, "testapp")
        XCTAssertEqual(target.mode, "modal")
    }
    
    func testRouteByUserInfoURL() {
        let payload = MessagePayload(
            title: "Test",
            body: "Body",
            channel: "test",
            userInfo: ["url": "https://example.com"]
        )
        
        let target = router.route(payload: payload)
        
        XCTAssertEqual(target.type, .url)
        XCTAssertEqual(target.destination, "https://example.com")
    }
    
    // MARK: - No Route
    
    func testNoRoute() {
        let payload = MessagePayload(
            title: "Test",
            body: "Body",
            channel: "test"
        )
        
        let target = router.route(payload: payload)
        
        XCTAssertEqual(target.type, .none)
        XCTAssertTrue(target.destination.isEmpty)
    }
    
    // MARK: - APNs UserInfo Routing
    
    func testRouteFromAPNsUserInfoWithAppId() {
        let userInfo: [AnyHashable: Any] = [
            "appid": "myapp",
            "mode": "immersive"
        ]
        
        let target = router.route(userInfo: userInfo)
        
        XCTAssertEqual(target.type, .appId)
        XCTAssertEqual(target.destination, "myapp")
        XCTAssertEqual(target.mode, "immersive")
    }
    
    func testRouteFromAPNsUserInfoWithUrl() {
        let userInfo: [AnyHashable: Any] = [
            "url": "https://example.com/page",
            "mode": "normal"
        ]
        
        let target = router.route(userInfo: userInfo)
        
        XCTAssertEqual(target.type, .url)
        XCTAssertEqual(target.destination, "https://example.com/page")
    }
    
    func testRouteFromAPNsUserInfoNoRoute() {
        let userInfo: [AnyHashable: Any] = [
            "title": "Test",
            "body": "Body"
        ]
        
        let target = router.route(userInfo: userInfo)
        
        XCTAssertEqual(target.type, .none)
    }
    
    // MARK: - Custom Resolver
    
    func testCustomResolver() {
        router.customResolver = { payload in
            if payload.title == "special" {
                return RouteTarget(type: .deeplink, destination: "custom://route")
            }
            return nil
        }
        
        let payload = MessagePayload(title: "special", body: "Body", channel: "test")
        let target = router.route(payload: payload)
        
        XCTAssertEqual(target.type, .deeplink)
        XCTAssertEqual(target.destination, "custom://route")
    }
    
    func testCustomResolverFallback() {
        router.customResolver = { _ in nil }
        
        let payload = MessagePayload(
            title: "Test",
            body: "Body",
            channel: "test",
            targetURL: "https://example.com"
        )
        let target = router.route(payload: payload)
        
        XCTAssertEqual(target.type, .url)
    }
}
