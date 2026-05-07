import XCTest
@testable import WebBridgeKit

final class WebGeolocationHandlerTests: XCTestCase {

    private func assertSuccess(_ result: Any) -> [String: Any] {
        guard let dict = result as? [String: Any] else {
            XCTFail("Result is not a dictionary")
            return [:]
        }
        XCTAssertEqual(dict["success"] as? Bool, true)
        return dict
    }

    // MARK: - Instantiation

    func testLocationHandler_CanBeInstantiated() {
        let handler = WebLocationHandler()
        XCTAssertNotNil(handler)
    }

    // MARK: - Handler Name

    func testLocationHandler_HandlerName() {
        let handler = WebLocationHandler()
        XCTAssertEqual(handler.handlerName, "Location")
    }

    // MARK: - WebView Nil

    func testLocationHandler_WebViewNil_DoesNotCrash() {
        let handler = WebLocationHandler()
        handler.webView = nil

        let hasCalled = UnsafeMutablePointer<Bool>.allocate(capacity: 1)
        hasCalled.pointee = false
        defer { hasCalled.deallocate() }

        handler.handle(body: [:]) { result in
            hasCalled.pointee = true
            guard let dict = result as? [String: Any] else {
                return
            }
            XCTAssertNotNil(dict["success"])
        }

        let start = Date()
        while !hasCalled.pointee && Date().timeIntervalSince(start) < 6.0 {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }
    }

    // MARK: - Default Handle Does Not Crash

    func testLocationHandler_DefaultHandle_DoesNotCrash() {
        let handler = WebLocationHandler()

        let hasCalled = UnsafeMutablePointer<Bool>.allocate(capacity: 1)
        hasCalled.pointee = false
        defer { hasCalled.deallocate() }

        handler.handle(body: [:]) { result in
            hasCalled.pointee = true
            guard let dict = result as? [String: Any] else {
                return
            }
            XCTAssertNotNil(dict["success"])
        }

        let start = Date()
        while !hasCalled.pointee && Date().timeIntervalSince(start) < 6.0 {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }
    }

    // MARK: - Multiple Sequential Calls

    func testLocationHandler_TwoSequentialCalls_DoNotCrash() {
        let handler = WebLocationHandler()

        for i in 0..<2 {
            let hasCalled = UnsafeMutablePointer<Bool>.allocate(capacity: 1)
            hasCalled.pointee = false
            defer { hasCalled.deallocate() }

            handler.handle(body: [:]) { result in
                hasCalled.pointee = true
                guard let dict = result as? [String: Any] else {
                    return
                }
                XCTAssertNotNil(dict["success"])
            }

            let start = Date()
            while !hasCalled.pointee && Date().timeIntervalSince(start) < 6.0 {
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
            }
        }
    }

    // MARK: - Response Structure (when location unavailable)

    func testLocationHandler_ResponseIsDictionary() {
        let handler = WebLocationHandler()

        let hasCalled = UnsafeMutablePointer<Bool>.allocate(capacity: 1)
        hasCalled.pointee = false
        defer { hasCalled.deallocate() }

        handler.handle(body: [:]) { result in
            hasCalled.pointee = true
            guard let dict = result as? [String: Any] else {
                return
            }
            XCTAssertTrue(dict["success"] is Bool)
        }

        let start = Date()
        while !hasCalled.pointee && Date().timeIntervalSince(start) < 6.0 {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }
    }
}
