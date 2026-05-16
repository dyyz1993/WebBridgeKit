import XCTest
@testable import WebBridgeKit

final class WebPermissionStatusHandlerTests: XCTestCase {

    // MARK: - Handler Name

    func testPermissionStatusHandler_HandlerName() {
        let handler = WebPermissionStatusHandler()
        XCTAssertEqual(handler.handlerName, "PermissionStatus")
    }

    // MARK: - Handle Returns Success

    func testPermissionStatusHandler_Handle_ReturnsSuccess() {
        let handler = WebPermissionStatusHandler()
        let expectation = XCTestExpectation(description: "permission status handle")

        handler.handle(body: [:]) { result in
            let dict = assertSuccess(result)
            XCTAssertNotNil(dict["data"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Returns Permissions Array

    func testPermissionStatusHandler_ReturnsPermissionsArray() {
        let handler = WebPermissionStatusHandler()
        let expectation = XCTestExpectation(description: "permission status array")

        handler.handle(body: [:]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any],
                  let permissions = data["permissions"] as? [[String: Any]] else {
                XCTFail("Missing permissions array")
                return
            }
            XCTAssertGreaterThan(permissions.count, 0, "Should return at least one permission")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Returns Summary

    func testPermissionStatusHandler_ReturnsSummary() {
        let handler = WebPermissionStatusHandler()
        let expectation = XCTestExpectation(description: "permission status summary")

        handler.handle(body: [:]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any],
                  let summary = data["summary"] as? [String: Any] else {
                XCTFail("Missing summary")
                return
            }
            XCTAssertNotNil(summary["total"])
            XCTAssertNotNil(summary["granted"])
            XCTAssertNotNil(summary["denied"])
            XCTAssertNotNil(summary["notDetermined"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Summary Total Matches Permissions Count

    func testPermissionStatusHandler_SummaryTotalMatchesPermissionsCount() {
        let handler = WebPermissionStatusHandler()
        let expectation = XCTestExpectation(description: "permission status total matches")

        handler.handle(body: [:]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any],
                  let permissions = data["permissions"] as? [[String: Any]],
                  let summary = data["summary"] as? [String: Any],
                  let total = summary["total"] as? Int else {
                XCTFail("Missing data")
                return
            }
            XCTAssertEqual(total, permissions.count, "Summary total should match permissions count")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Each Permission Has Required Keys

    func testPermissionStatusHandler_EachPermissionHasRequiredKeys() {
        let handler = WebPermissionStatusHandler()
        let expectation = XCTestExpectation(description: "permission status keys")

        handler.handle(body: [:]) { result in
            let dict = assertSuccess(result)
            guard let data = dict["data"] as? [String: Any],
                  let permissions = data["permissions"] as? [[String: Any]] else {
                XCTFail("Missing permissions")
                return
            }

            let requiredKeys: Set<String> = ["type", "displayName", "icon", "status", "granted"]
            for (index, permission) in permissions.enumerated() {
                let keys = Set(permission.keys)
                XCTAssertTrue(requiredKeys.isSubset(of: keys),
                              "Permission at index \(index) is missing keys: \(requiredKeys.subtracting(keys))")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Ignores Body Params

    func testPermissionStatusHandler_IgnoresBodyParams() {
        let handler = WebPermissionStatusHandler()
        let expectation = XCTestExpectation(description: "permission status ignores body")

        handler.handle(body: ["filter": "camera", "detail": true]) { result in
            let dict = assertSuccess(result)
            XCTAssertNotNil(dict["data"])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }
}
