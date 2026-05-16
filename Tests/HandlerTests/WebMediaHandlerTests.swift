import XCTest
@testable import WebBridgeKit

final class WebMediaHandlerTests: XCTestCase {

    // MARK: - Handler Name

    func testMediaHandler_HandlerName() {
        let handler = WebMediaHandler()
        XCTAssertEqual(handler.handlerName, "Media")
    }

    // MARK: - Unknown Action Returns Error

    func testMediaHandler_UnknownAction_ReturnsError() {
        let handler = WebMediaHandler()
        let expectation = XCTestExpectation(description: "media unknown action")

        handler.handle(body: ["params": ["action": "unknownAction"]]) { result in
            let dict = assertFailure(result)
            XCTAssertEqual(dict["code"] as? Int, 404)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Empty Action Returns Error

    func testMediaHandler_EmptyAction_ReturnsError() {
        let handler = WebMediaHandler()
        let expectation = XCTestExpectation(description: "media empty action")

        handler.handle(body: [:]) { result in
            let dict = assertFailure(result)
            XCTAssertEqual(dict["code"] as? Int, 404)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - SaveImage Invalid Data Returns Error

    func testMediaHandler_SaveImage_InvalidData_ReturnsError() {
        let handler = WebMediaHandler()
        let expectation = XCTestExpectation(description: "media save image invalid data")

        handler.handle(body: ["params": ["action": "saveImage", "data": "not-valid-base64"]]) { result in
            let dict = assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - SaveImage Empty Data Returns Error

    func testMediaHandler_SaveImage_EmptyData_ReturnsError() {
        let handler = WebMediaHandler()
        let expectation = XCTestExpectation(description: "media save image empty data")

        handler.handle(body: ["params": ["action": "saveImage", "data": ""]]) { result in
            let dict = assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - SaveFile Invalid Base64 Returns Error

    func testMediaHandler_SaveFile_InvalidBase64_ReturnsError() {
        let handler = WebMediaHandler()
        let expectation = XCTestExpectation(description: "media save file invalid base64")

        handler.handle(body: ["params": ["action": "saveFile", "data": "!!!invalid!!!", "fileName": "test.txt"]]) { result in
            let dict = assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - SaveFile Empty Data Returns Error

    func testMediaHandler_SaveFile_EmptyData_ReturnsError() {
        let handler = WebMediaHandler()
        let expectation = XCTestExpectation(description: "media save file empty data")

        handler.handle(body: ["params": ["action": "saveFile", "data": "", "fileName": "test.txt"]]) { result in
            let dict = assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - UploadFile Invalid URL Returns Error

    func testMediaHandler_UploadFile_InvalidURL_ReturnsError() {
        let handler = WebMediaHandler()
        let expectation = XCTestExpectation(description: "media upload invalid url")

        handler.handle(body: ["params": ["action": "uploadFile", "path": "/tmp/test.m4a", "url": "not-a-url"]]) { result in
            let dict = assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - UploadFile Empty URL Returns Error

    func testMediaHandler_UploadFile_EmptyURL_ReturnsError() {
        let handler = WebMediaHandler()
        let expectation = XCTestExpectation(description: "media upload empty url")

        handler.handle(body: ["params": ["action": "uploadFile", "path": "/tmp/test.m4a", "url": ""]]) { result in
            let dict = assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - UploadFile Missing Params Returns Error

    func testMediaHandler_UploadFile_MissingParams_ReturnsError() {
        let handler = WebMediaHandler()
        let expectation = XCTestExpectation(description: "media upload missing params")

        handler.handle(body: ["params": ["action": "uploadFile"]]) { result in
            let dict = assertFailure(result)
            XCTAssertNotNil(dict["error"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Error Message Contains Action Name

    func testMediaHandler_UnknownAction_ErrorContainsActionName() {
        let handler = WebMediaHandler()
        let expectation = XCTestExpectation(description: "media error contains action")

        handler.handle(body: ["params": ["action": "deleteMedia"]]) { result in
            let dict = assertFailure(result)
            let errorMsg = dict["error"] as? String ?? ""
            XCTAssertTrue(errorMsg.contains("deleteMedia"), "Error should contain the action name")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }
}
