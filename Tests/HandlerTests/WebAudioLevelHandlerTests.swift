import XCTest
@testable import WebBridgeKit

final class WebAudioLevelHandlerTests: XCTestCase {

    // MARK: - Set Sensitivity

    func testAudioLevelHandler_SetSensitivity() {
        let handler = WebAudioLevelHandler()
        let expectation = XCTestExpectation(description: "audioLevel setSensitivity")

        handler.handle(body: ["params": ["action": "setSensitivity", "sensitivity": 3.0]]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["sensitivity"] as? Float, 3.0)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testAudioLevelHandler_SetSensitivity_HighValue() {
        let handler = WebAudioLevelHandler()
        let expectation = XCTestExpectation(description: "audioLevel high sensitivity")

        handler.handle(body: ["params": ["action": "setSensitivity", "sensitivity": 10.0]]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["sensitivity"] as? Float, 10.0)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testAudioLevelHandler_SetSensitivity_Zero() {
        let handler = WebAudioLevelHandler()
        let expectation = XCTestExpectation(description: "audioLevel zero sensitivity")

        handler.handle(body: ["params": ["action": "setSensitivity", "sensitivity": 0.0]]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["sensitivity"] as? Float, 0.0)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Stop

    func testAudioLevelHandler_StopWithoutStart_ReturnsSuccess() {
        let handler = WebAudioLevelHandler()
        let expectation = XCTestExpectation(description: "audioLevel stop without start")

        handler.handle(body: ["params": ["action": "stop"]]) { result in
            let dict = assertSuccess(result)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testAudioLevelHandler_Stop_ReturnsSuccess() {
        let handler = WebAudioLevelHandler()
        let expectation = XCTestExpectation(description: "audioLevel stop")

        handler.handle(body: ["params": ["action": "stop"]]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["message"] as? String, "Monitoring stopped")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Unknown Action

    func testAudioLevelHandler_UnknownAction_ReturnsError() {
        let handler = WebAudioLevelHandler()
        let expectation = XCTestExpectation(description: "audioLevel unknown action")

        handler.handle(body: ["params": ["action": "record"]]) { result in
            let dict = assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testAudioLevelHandler_AnalyzeAction_ReturnsError() {
        let handler = WebAudioLevelHandler()
        let expectation = XCTestExpectation(description: "audioLevel analyze action")

        handler.handle(body: ["params": ["action": "analyze"]]) { result in
            let dict = assertFailure(result)
            let error = dict["error"] as? String ?? ""
            XCTAssertTrue(error.contains("Unknown action"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Default Action

    func testAudioLevelHandler_DefaultAction_IsStart() {
        let handler = WebAudioLevelHandler()
        let expectation = XCTestExpectation(description: "audioLevel default action")

        handler.handle(body: ["params": [:]]) { result in
            guard let dict = result as? [String: Any] else {
                XCTFail("Result is not a dictionary")
                return
            }
            XCTAssertNotNil(dict["success"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Handler Name

    func testAudioLevelHandler_HandlerName() {
        let handler = WebAudioLevelHandler()
        XCTAssertEqual(handler.handlerName, "AudioLevel")
    }
}
