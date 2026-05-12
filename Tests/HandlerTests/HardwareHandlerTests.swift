import XCTest
@testable import WebBridgeKit

extension AdvancedHandlerTests {

    // MARK: - WebSpeechSynthesisHandler

    func testSpeechSynthesisHandler_Speak() {
        let handler = WebSpeechSynthesisHandler()
        let expectation = XCTestExpectation(description: "speechSynthesis speak")

        handler.handle(body: ["params": ["action": "speak", "text": "hello", "lang": "en-US", "rate": 0.5]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["status"] as? String, "speaking")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testSpeechSynthesisHandler_Stop() {
        let handler = WebSpeechSynthesisHandler()
        let expectation = XCTestExpectation(description: "speechSynthesis stop")

        handler.handle(body: ["params": ["action": "stop"]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["status"] as? String, "stopped")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testSpeechSynthesisHandler_UnsupportedAction_ReturnsError() {
        let handler = WebSpeechSynthesisHandler()
        let expectation = XCTestExpectation(description: "speechSynthesis unsupported")

        handler.handle(body: ["params": ["action": "pause"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - WebSystemExtraHandler

    func testSystemExtraHandler_UnsupportedAction_ReturnsError() {
        let handler = WebSystemExtraHandler()
        let expectation = XCTestExpectation(description: "systemExtra unsupported")

        handler.handle(body: ["params": ["action": "restart"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - WebMirroringHandler

    func testMirroringHandler_GetStatus() {
        let handler = WebMirroringHandler()
        let expectation = XCTestExpectation(description: "mirroring getStatus")

        handler.handle(body: [:]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["isMirroring"])
            XCTAssertNotNil(data["screenCount"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testMirroringHandler_GetStatusAction() {
        let handler = WebMirroringHandler()
        let expectation = XCTestExpectation(description: "mirroring getStatus action")

        handler.handle(body: ["params": ["action": "getStatus"]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["isMirroring"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testMirroringHandler_StartObserve() {
        let handler = WebMirroringHandler()
        let expectation = XCTestExpectation(description: "mirroring startObserve")

        handler.handle(body: ["params": ["action": "startObserve"]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["status"] as? String, "observing")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testMirroringHandler_StopObserve() {
        let handler = WebMirroringHandler()
        let expectation = XCTestExpectation(description: "mirroring stopObserve")

        handler.handle(body: ["params": ["action": "stopObserve"]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["status"] as? String, "stopped")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testMirroringHandler_UnsupportedAction_ReturnsError() {
        let handler = WebMirroringHandler()
        let expectation = XCTestExpectation(description: "mirroring unsupported")

        handler.handle(body: ["params": ["action": "mirror"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - WebSensorsHandler

    func testSensorsHandler_GetStatus() {
        let handler = WebSensorsHandler()
        let expectation = XCTestExpectation(description: "sensors getStatus")

        handler.handle(body: [:]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["accelerometer"])
            XCTAssertNotNil(data["gyroscope"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testSensorsHandler_StopAccelerometer() {
        let handler = WebSensorsHandler()
        let expectation = XCTestExpectation(description: "sensors stopAccelerometer")

        handler.handle(body: ["params": ["action": "stopAccelerometer"]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["status"] as? String, "stopped")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testSensorsHandler_StopGyroscope() {
        let handler = WebSensorsHandler()
        let expectation = XCTestExpectation(description: "sensors stopGyroscope")

        handler.handle(body: ["params": ["action": "stopGyroscope"]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["status"] as? String, "stopped")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testSensorsHandler_UnsupportedAction_ReturnsError() {
        let handler = WebSensorsHandler()
        let expectation = XCTestExpectation(description: "sensors unsupported")

        handler.handle(body: ["params": ["action": "startMagnetometer"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - WebBluetoothHandler

    func testBluetoothHandler_CanBeCreated() {
        let handler = WebBluetoothHandler()
        XCTAssertNotNil(handler)
    }

    func testBluetoothHandler_GetStatus() {
        let handler = WebBluetoothHandler()
        let expectation = XCTestExpectation(description: "bluetooth getStatus")

        handler.handle(body: [:]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["available"])
            XCTAssertNotNil(data["state"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testBluetoothHandler_UnsupportedAction_ReturnsError() {
        let handler = WebBluetoothHandler()
        let expectation = XCTestExpectation(description: "bluetooth unsupported")

        handler.handle(body: ["params": ["action": "connect"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - WebPermissionHandler

    func testPermissionHandler_InvalidType_ReturnsError() {
        let handler = WebPermissionHandler()
        let expectation = XCTestExpectation(description: "permission invalid type")

        handler.handle(body: ["type": "invalidType"]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testPermissionHandler_MissingType_ReturnsError() {
        let handler = WebPermissionHandler()
        let expectation = XCTestExpectation(description: "permission missing type")

        handler.handle(body: [:]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - WebCameraHandler

    func testCameraHandler_CanBeCreated() {
        let handler = WebCameraHandler()
        XCTAssertNotNil(handler)
    }

    func testCameraHandler_UnknownType_ReturnsError() {
        let handler = WebCameraHandler()
        let expectation = XCTestExpectation(description: "camera unknown type")

        handler.handle(body: ["params": ["type": "hologram"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - WebContactsHandler

    func testContactsHandler_CheckPermission() {
        let handler = WebContactsHandler()
        let expectation = XCTestExpectation(description: "contacts checkPermission")

        handler.handle(body: ["params": ["action": "checkPermission"]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["authorized"])
            XCTAssertNotNil(data["status"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testContactsHandler_UnknownAction_ReturnsError() {
        let handler = WebContactsHandler()
        let expectation = XCTestExpectation(description: "contacts unknown action")

        handler.handle(body: ["params": ["action": "delete"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - WebLocationHandler

    func testLocationHandler_CanBeCreated() {
        let handler = WebLocationHandler()
        XCTAssertNotNil(handler)
    }

    // MARK: - WebScanHandler

    func testScanHandler_CanBeCreated() {
        let handler = WebScanHandler()
        XCTAssertNotNil(handler)
    }

    // MARK: - WebSpeechHandler

    func testSpeechHandler_CanBeCreated() {
        let handler = WebSpeechHandler()
        XCTAssertNotNil(handler)
    }

    // MARK: - WebAudioLevelHandler

    func testAudioLevelHandler_SetSensitivity() {
        let handler = WebAudioLevelHandler()
        let expectation = XCTestExpectation(description: "audioLevel setSensitivity")

        handler.handle(body: ["params": ["action": "setSensitivity", "sensitivity": 3.0]]) { result in
            let dict = self.assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(data["sensitivity"] as? Float, 3.0)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testAudioLevelHandler_StopWithoutStart() {
        let handler = WebAudioLevelHandler()
        let expectation = XCTestExpectation(description: "audioLevel stop without start")

        handler.handle(body: ["params": ["action": "stop"]]) { result in
            let dict = self.assertSuccess(result)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testAudioLevelHandler_UnknownAction_ReturnsError() {
        let handler = WebAudioLevelHandler()
        let expectation = XCTestExpectation(description: "audioLevel unknown action")

        handler.handle(body: ["params": ["action": "record"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - WebMediaHandler

    func testMediaHandler_UnsupportedAction_ReturnsError() {
        let handler = WebMediaHandler()
        let expectation = XCTestExpectation(description: "media unsupported action")

        handler.handle(body: ["params": ["action": "compress"]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testMediaHandler_SaveImage_InvalidData_ReturnsError() {
        let handler = WebMediaHandler()
        let expectation = XCTestExpectation(description: "media saveImage invalid")

        handler.handle(body: ["params": ["action": "saveImage", "data": ""]]) { result in
            let dict = self.assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testMediaHandler_UploadFile_WithValidURL_ReturnsSuccess() {
        let handler = WebMediaHandler()
        let expectation = XCTestExpectation(description: "media uploadFile valid url")

        handler.handle(body: ["params": ["action": "uploadFile", "path": "/tmp/file.txt", "url": "https://example.com/upload"]]) { result in
            if let response = result as? WebBridgeResponse {
                XCTAssertTrue(response.success)
            } else if let dict = result as? [String: Any] {
                XCTAssertEqual(dict["success"] as? Bool, true)
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - WebOpenSettingsHandler

    func testOpenSettingsHandler_CanBeCreated() {
        let handler = WebOpenSettingsHandler()
        XCTAssertNotNil(handler)
    }
}
