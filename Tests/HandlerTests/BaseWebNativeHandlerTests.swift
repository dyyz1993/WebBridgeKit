import XCTest
import WebKit
@testable import WebBridgeKit

final class BaseWebNativeHandlerTests: XCTestCase {

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

    // MARK: - WebBridgeResponse Tests

    func testWebBridgeResponse_Success_NoData() {
        let response = WebBridgeResponse.success()
        XCTAssertTrue(response.success)
        XCTAssertNil(response.data)
        XCTAssertNil(response.error)
        XCTAssertNil(response.errorCode)
    }

    func testWebBridgeResponse_Success_WithData() {
        let data = ["key": "value"]
        let response = WebBridgeResponse.success(data: data)
        XCTAssertTrue(response.success)
        XCTAssertNotNil(response.data)
    }

    func testWebBridgeResponse_Error_WithCode() {
        let response = WebBridgeResponse.error(code: 403, message: "Forbidden")
        XCTAssertFalse(response.success)
        XCTAssertEqual(response.error, "Forbidden")
        XCTAssertEqual(response.errorCode, 403)
    }

    func testWebBridgeResponse_Error_WithoutCode_DefaultsTo500() {
        let response = WebBridgeResponse.error(message: "Something went wrong")
        XCTAssertFalse(response.success)
        XCTAssertEqual(response.error, "Something went wrong")
        XCTAssertEqual(response.errorCode, 500)
    }

    func testWebBridgeResponse_ToDictionary_ContainsSuccess() {
        let response = WebBridgeResponse.success(data: "hello")
        let dict = response.toDictionary()
        XCTAssertEqual(dict["success"] as? Bool, true)
        XCTAssertEqual(dict["data"] as? String, "hello")
    }

    func testWebBridgeResponse_ToDictionary_ErrorContainsCode() {
        let response = WebBridgeResponse.error(code: 404, message: "Not found")
        let dict = response.toDictionary()
        XCTAssertEqual(dict["success"] as? Bool, false)
        XCTAssertEqual(dict["error"] as? String, "Not found")
        XCTAssertEqual(dict["code"] as? Int, 404)
    }

    func testWebBridgeResponse_ToDictionary_ErrorWithoutData_NoDataKey() {
        let response = WebBridgeResponse.error(message: "error")
        let dict = response.toDictionary()
        XCTAssertNil(dict["data"])
        XCTAssertNotNil(dict["error"])
        XCTAssertNotNil(dict["code"])
    }

    // MARK: - BaseWebNativeHandler Subclass Default Behavior

    func testBaseHandler_DefaultHandle_RejectsWithNotImplemented() {
        let handler = BaseWebNativeHandler()
        let expectation = XCTestExpectation(description: "default handle rejects")

        handler.handle(body: [:]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testBaseHandler_Resolve_ReturnsSuccessResponse() {
        let handler = BaseWebNativeHandler()
        let expectation = XCTestExpectation(description: "resolve returns success")

        handler.resolve(["test": true], completion: { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["test"] as? Bool, true)
            expectation.fulfill()
        })

        wait(for: [expectation], timeout: 2.0)
    }

    func testBaseHandler_Resolve_NilData_ReturnsSuccess() {
        let handler = BaseWebNativeHandler()
        let expectation = XCTestExpectation(description: "resolve nil data")

        handler.resolve(completion: { result in
            let dict = self.assertSuccess(result)
            XCTAssertNil(dict["data"])
            expectation.fulfill()
        })

        wait(for: [expectation], timeout: 2.0)
    }

    func testBaseHandler_Reject_WithCode() {
        let handler = BaseWebNativeHandler()
        let expectation = XCTestExpectation(description: "reject with code")

        handler.reject(error: "test error", code: 400, completion: { result in
            let dict = self.assertFailure(result)
            XCTAssertEqual(dict["error"] as? String, "test error")
            XCTAssertEqual(dict["code"] as? Int, 400)
            expectation.fulfill()
        })

        wait(for: [expectation], timeout: 2.0)
    }

    func testBaseHandler_Reject_WithoutCode() {
        let handler = BaseWebNativeHandler()
        let expectation = XCTestExpectation(description: "reject without code")

        handler.reject(error: "no code", completion: { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        })

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Handler Name

    func testBaseHandler_HandlerName_StripsWebAndHandler() {
        let handler = WebShareHandler()
        let name = handler.handlerName
        XCTAssertFalse(name.contains("Web"))
        XCTAssertFalse(name.contains("Handler"))
        XCTAssertEqual(name, "Share")
    }

    func testBaseHandler_HandlerName_ForSimpleHandler() {
        let handler = WebVibrateHandler()
        let name = handler.handlerName
        XCTAssertEqual(name, "Vibrate")
    }

    // MARK: - WebView Property

    func testBaseHandler_WebView_DefaultsToNil() {
        let handler = BaseWebNativeHandler()
        XCTAssertNil(handler.webView)
    }

    func testBaseHandler_WebView_CanBeSet() {
        let handler = BaseWebNativeHandler()
        let webView = WKWebView()
        handler.webView = webView
        XCTAssertNotNil(handler.webView)
        handler.webView = nil
        XCTAssertNil(handler.webView)
    }

    // MARK: - RunOnMainThread

    func testBaseHandler_RunOnMainThread_ExecutesBlock() {
        let handler = BaseWebNativeHandler()
        let expectation = XCTestExpectation(description: "runOnMainThread")

        handler.runOnMainThread {
            XCTAssertTrue(Thread.isMainThread)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Permission Types

    func testPermissionType_DisplayNames() {
        let types: [BaseWebNativeHandler.PermissionType] = [
            .camera, .microphone, .location, .contacts,
            .photos, .speech, .notification, .sensors,
            .bluetooth, .unknown
        ]
        for type in types {
            XCTAssertFalse(type.displayName.isEmpty, "Display name for \(type.rawValue) should not be empty")
        }
    }

    func testPermissionType_RawValues() {
        XCTAssertEqual(BaseWebNativeHandler.PermissionType.camera.rawValue, "camera")
        XCTAssertEqual(BaseWebNativeHandler.PermissionType.microphone.rawValue, "microphone")
        XCTAssertEqual(BaseWebNativeHandler.PermissionType.location.rawValue, "location")
        XCTAssertEqual(BaseWebNativeHandler.PermissionType.contacts.rawValue, "contacts")
        XCTAssertEqual(BaseWebNativeHandler.PermissionType.photos.rawValue, "photos")
        XCTAssertEqual(BaseWebNativeHandler.PermissionType.speech.rawValue, "speech")
        XCTAssertEqual(BaseWebNativeHandler.PermissionType.notification.rawValue, "notification")
        XCTAssertEqual(BaseWebNativeHandler.PermissionType.sensors.rawValue, "sensors")
        XCTAssertEqual(BaseWebNativeHandler.PermissionType.bluetooth.rawValue, "bluetooth")
    }

    func testPermissionStatus_RawValues() {
        XCTAssertEqual(BaseWebNativeHandler.PermissionStatus.notDetermined.rawValue, "notDetermined")
        XCTAssertEqual(BaseWebNativeHandler.PermissionStatus.denied.rawValue, "denied")
        XCTAssertEqual(BaseWebNativeHandler.PermissionStatus.restricted.rawValue, "restricted")
        XCTAssertEqual(BaseWebNativeHandler.PermissionStatus.authorized.rawValue, "authorized")
    }
}
