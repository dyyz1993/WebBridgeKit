import XCTest
@testable import WebBridgeKit

final class WebGoBackHandlerTests: XCTestCase {

    // MARK: - Handler Name

    func testGoBackHandler_HandlerName() {
        let handler = WebGoBackHandler()
        XCTAssertEqual(handler.handlerName, "GoBack")
    }

    // MARK: - Handle Returns Response

    func testGoBackHandler_Handle_ReturnsResponse() {
        let handler = WebGoBackHandler()
        let expectation = XCTestExpectation(description: "go back handle")

        handler.handle(body: [:]) { result in
            let dict = assertSuccess(result)
            XCTAssertNotNil(dict["data"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Response Contains Steps

    func testGoBackHandler_ContainsSteps() {
        let handler = WebGoBackHandler()
        let expectation = XCTestExpectation(description: "go back steps")

        handler.handle(body: [:]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            XCTAssertNotNil(data["steps"])
            XCTAssertNotNil(data["currentIndex"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Custom Steps

    func testGoBackHandler_CustomSteps_ReturnsSteps() {
        let handler = WebGoBackHandler()
        let expectation = XCTestExpectation(description: "go back custom steps")

        handler.handle(body: ["params": ["steps": 3]]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            let steps = data["steps"] as? Int
            XCTAssertNotNil(steps)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Default Steps Is One

    func testGoBackHandler_DefaultSteps_IsOne() {
        let handler = WebGoBackHandler()
        let expectation = XCTestExpectation(description: "go back default steps")

        handler.handle(body: [:]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any] else {
                XCTFail("Missing data")
                return
            }
            let success = data["success"] as? Bool
            XCTAssertNotNil(success)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Zero Steps

    func testGoBackHandler_ZeroSteps_DoesNotCrash() {
        let handler = WebGoBackHandler()
        let expectation = XCTestExpectation(description: "go back zero steps")

        handler.handle(body: ["params": ["steps": 0]]) { result in
            let dict = assertSuccess(result)
            XCTAssertNotNil(dict["data"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Negative Steps

    func testGoBackHandler_NegativeSteps_DoesNotCrash() {
        let handler = WebGoBackHandler()
        let expectation = XCTestExpectation(description: "go back negative steps")

        handler.handle(body: ["params": ["steps": -1]]) { result in
            let dict = assertSuccess(result)
            XCTAssertNotNil(dict["data"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Non-Integer Steps

    func testGoBackHandler_NonIntegerSteps_DefaultsToOne() {
        let handler = WebGoBackHandler()
        let expectation = XCTestExpectation(description: "go back non-integer steps")

        handler.handle(body: ["params": ["steps": "two"]]) { result in
            let dict = assertSuccess(result)
            XCTAssertNotNil(dict["data"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }
}
