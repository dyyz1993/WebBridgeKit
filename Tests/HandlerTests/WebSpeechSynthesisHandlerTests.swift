import XCTest
@testable import WebBridgeKit

final class WebSpeechSynthesisHandlerTests: XCTestCase {

    // MARK: - Speak Action

    func testSpeechSynthesisHandler_Speak_ReturnsSpeaking() {
        let handler = WebSpeechSynthesisHandler()
        let expectation = XCTestExpectation(description: "tts speak")

        handler.handle(body: ["params": ["action": "speak", "text": "hello", "lang": "en-US", "rate": 0.5]]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["status"] as? String, "speaking")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testSpeechSynthesisHandler_Speak_EmptyText_ReturnsSpeaking() {
        let handler = WebSpeechSynthesisHandler()
        let expectation = XCTestExpectation(description: "tts speak empty")

        handler.handle(body: ["params": ["action": "speak"]]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["status"] as? String, "speaking")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testSpeechSynthesisHandler_Speak_DefaultLang() {
        let handler = WebSpeechSynthesisHandler()
        let expectation = XCTestExpectation(description: "tts default lang")

        handler.handle(body: ["params": ["action": "speak", "text": "test"]]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["status"] as? String, "speaking")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Stop Action

    func testSpeechSynthesisHandler_Stop_ReturnsStopped() {
        let handler = WebSpeechSynthesisHandler()
        let expectation = XCTestExpectation(description: "tts stop")

        handler.handle(body: ["params": ["action": "stop"]]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["status"] as? String, "stopped")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testSpeechSynthesisHandler_StopWithoutSpeak_ReturnsStopped() {
        let handler = WebSpeechSynthesisHandler()
        let expectation = XCTestExpectation(description: "tts stop without speak")

        handler.handle(body: ["params": ["action": "stop"]]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["status"] as? String, "stopped")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Unsupported Actions

    func testSpeechSynthesisHandler_Pause_ReturnsError() {
        let handler = WebSpeechSynthesisHandler()
        let expectation = XCTestExpectation(description: "tts pause error")

        handler.handle(body: ["params": ["action": "pause"]]) { result in
            let dict = assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testSpeechSynthesisHandler_Resume_ReturnsError() {
        let handler = WebSpeechSynthesisHandler()
        let expectation = XCTestExpectation(description: "tts resume error")

        handler.handle(body: ["params": ["action": "resume"]]) { result in
            let dict = assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Handler Name

    func testSpeechSynthesisHandler_HandlerName() {
        let handler = WebSpeechSynthesisHandler()
        XCTAssertEqual(handler.handlerName, "SpeechSynthesis")
    }

    // MARK: - Speak Then Stop

    func testSpeechSynthesisHandler_SpeakThenStop() {
        let handler = WebSpeechSynthesisHandler()
        let speakExp = XCTestExpectation(description: "tts speak then stop")
        let stopExp = XCTestExpectation(description: "tts stop after speak")

        handler.handle(body: ["params": ["action": "speak", "text": "test"]]) { result in
            let dict = assertSuccess(result)
            XCTAssertEqual((dict["data"] as? [String: Any])?["status"] as? String, "speaking")
            speakExp.fulfill()
        }

        wait(for: [speakExp], timeout: 2.0)

        handler.handle(body: ["params": ["action": "stop"]]) { result in
            let dict = assertSuccess(result)
            XCTAssertEqual((dict["data"] as? [String: Any])?["status"] as? String, "stopped")
            stopExp.fulfill()
        }

        wait(for: [stopExp], timeout: 2.0)
    }
}
