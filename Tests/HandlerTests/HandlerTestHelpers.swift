import XCTest
@testable import WebBridgeKit

func assertSuccess(_ result: Any) -> [String: Any] {
    guard let dict = result as? [String: Any] else {
        XCTFail("Result is not a dictionary")
        return [:]
    }
    XCTAssertEqual(dict["success"] as? Bool, true)
    return dict
}

func assertFailure(_ result: Any) -> [String: Any] {
    guard let dict = result as? [String: Any] else {
        XCTFail("Result is not a dictionary")
        return [:]
    }
    XCTAssertEqual(dict["success"] as? Bool, false)
    return dict
}
