import XCTest
import CoreLocation
@testable import WebBridgeKit

final class WebLocationHandlerTests: XCTestCase {

    private final class MockLocationProvider: WebLocationHandler.LocationProviding {
        var authorizationStatus: CLAuthorizationStatus = .authorizedWhenInUse
        var locationServicesEnabled: Bool = true
        private weak var handler: WebLocationHandler?

        func requestWhenInUseAuthorization() {}
        func requestLocation() {
            guard let handler = handler else { return }
            let location = CLLocation(latitude: 39.9042, longitude: 116.4074)
            handler.locationManager(CLLocationManager(), didUpdateLocations: [location])
        }

        func setDelegate(_ delegate: CLLocationManagerDelegate?) {
            self.handler = delegate as? WebLocationHandler
        }
    }

    private func makeHandler(provider: MockLocationProvider = MockLocationProvider()) -> WebLocationHandler {
        return WebLocationHandler(locationProvider: provider)
    }

    // MARK: - Handler Name

    func testLocationHandler_HandlerName() {
        let handler = makeHandler()
        XCTAssertEqual(handler.handlerName, "Location")
    }

    // MARK: - Handle Returns Response

    func testLocationHandler_Handle_ReturnsResponse() {
        let handler = makeHandler()
        let expectation = XCTestExpectation(description: "location handle")

        handler.handle(body: [:]) { result in
            guard let dict = result as? [String: Any] else {
                XCTFail("Result is not a dictionary")
                return
            }
            XCTAssertNotNil(dict["success"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Ignores Body Params

    func testLocationHandler_IgnoresBodyParams() {
        let handler = makeHandler()
        let expectation = XCTestExpectation(description: "location ignores body")

        handler.handle(body: ["accuracy": "high", "timeout": 10]) { result in
            guard let dict = result as? [String: Any] else {
                XCTFail("Result is not a dictionary")
                return
            }
            XCTAssertNotNil(dict["success"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Empty Body

    func testLocationHandler_EmptyBody_DoesNotCrash() {
        let handler = makeHandler()
        let expectation = XCTestExpectation(description: "location empty body")

        handler.handle(body: [:]) { result in
            guard let _ = result as? [String: Any] else {
                XCTFail("Result is not a dictionary")
                return
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Multiple Calls Don't Crash

    func testLocationHandler_MultipleCalls_DontCrash() {
        let handler = makeHandler()

        for i in 0..<3 {
            let expectation = XCTestExpectation(description: "location multiple \(i)")

            handler.handle(body: [:]) { result in
                guard let _ = result as? [String: Any] else {
                    XCTFail("Result is not a dictionary")
                    return
                }
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 5.0)
        }
    }

    // MARK: - WebView Nil Handling

    func testLocationHandler_WebViewNil_DoesNotCrash() {
        let handler = makeHandler()
        handler.webView = nil

        let expectation = XCTestExpectation(description: "location nil webView")

        handler.handle(body: [:]) { result in
            guard let _ = result as? [String: Any] else {
                XCTFail("Result is not a dictionary")
                return
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Location Services Disabled

    func testLocationHandler_LocationServicesDisabled_ReturnsError() {
        let provider = MockLocationProvider()
        provider.locationServicesEnabled = false
        let handler = makeHandler(provider: provider)
        let expectation = XCTestExpectation(description: "location disabled")

        handler.handle(body: [:]) { result in
            let dict = assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Permission Denied

    func testLocationHandler_PermissionDenied_ReturnsError() {
        let provider = MockLocationProvider()
        provider.authorizationStatus = .denied
        let handler = makeHandler(provider: provider)
        let expectation = XCTestExpectation(description: "location denied")

        handler.handle(body: [:]) { result in
            let dict = assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Returns Coordinates

    func testLocationHandler_ReturnsCoordinates() {
        let handler = makeHandler()
        let expectation = XCTestExpectation(description: "location coordinates")

        handler.handle(body: [:]) { result in
            let dict = assertSuccess(result)
            let data = dict["data"] as? [String: Any] ?? dict
            XCTAssertNotNil(data["latitude"])
            XCTAssertNotNil(data["longitude"])
            XCTAssertNotNil(data["accuracy"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }
}
