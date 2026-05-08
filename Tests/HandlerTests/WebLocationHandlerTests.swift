import XCTest
import CoreLocation
@testable import WebBridgeKit

final class WebLocationHandlerTests: XCTestCase {

    private final class MockLocationProvider: WebLocationHandler.LocationProviding {
        var authorizationStatus: CLAuthorizationStatus = .authorizedWhenInUse
        var locationServicesEnabled: Bool = true
        private weak var delegate: CLLocationManagerDelegate?

        func requestWhenInUseAuthorization() {}
        func requestLocation() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, let delegate = self.delegate else { return }
                let location = CLLocation(latitude: 39.9042, longitude: 116.4074)
                delegate.locationManager?(CLLocationManager() as! CLLocationManager, didUpdateLocations: [location])
            }
        }

        func setDelegate(_ delegate: CLLocationManagerDelegate?) {
            self.delegate = delegate
        }
    }

    private func makeHandler(provider: MockLocationProvider = MockLocationProvider()) -> WebLocationHandler {
        return WebLocationHandler(locationProvider: provider)
    }

    private func assertSuccess(_ result: Any) -> [String: Any] {
        guard let dict = result as? [String: Any] else {
            XCTFail("Result is not a dictionary")
            return [:]
        }
        XCTAssertEqual(dict["success"] as? Bool, true)
        return dict
    }

    private func assertFailure(_ result: Any) -> [String: Any] {
        guard let dict = result as? [String: Any] else {
            XCTFail("Result is not a dictionary")
            return [:]
        }
        XCTAssertEqual(dict["success"] as? Bool, false)
        return dict
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
            let dict = self.assertFailure(result)
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
            let dict = self.assertFailure(result)
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
            let dict = self.assertSuccess(result)
            XCTAssertNotNil(dict["latitude"])
            XCTAssertNotNil(dict["longitude"])
            XCTAssertNotNil(dict["accuracy"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }
}
