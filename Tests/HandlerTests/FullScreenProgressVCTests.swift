import XCTest
@testable import WebBridgeKit

final class FullScreenProgressVCTests: XCTestCase {

    func testInit_DefaultTotalResources_IsZero() {
        let vc = FullScreenProgressViewController()
        _ = vc.view
        XCTAssertEqual(vc.modalPresentationStyle, .fullScreen)
    }

    func testInit_CustomTotalResources_DoesNotCrash() {
        let vc = FullScreenProgressViewController(totalResources: 5)
        _ = vc.view
        XCTAssertEqual(vc.modalPresentationStyle, .fullScreen)
    }

    func testModalPresentationStyle_IsFullScreen() {
        let vc = FullScreenProgressViewController(totalResources: 10)
        XCTAssertEqual(vc.modalPresentationStyle, .fullScreen)
    }

    func testUpdateProgress_ThreeOfTen_Shows30Percent() {
        let vc = FullScreenProgressViewController(totalResources: 10)
        _ = vc.view

        let expectation = XCTestExpectation(description: "progress 30%")

        vc.updateProgress(current: 3, total: 10, message: "Downloading")

        DispatchQueue.main.async {
            let label = self.findLabel(in: vc.view, matchingPrefix: "30%")
            XCTAssertNotNil(label, "Expected label with text '30%'")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testUpdateProgress_OneOfTwo_Shows50Percent() {
        let vc = FullScreenProgressViewController(totalResources: 2)
        _ = vc.view

        let expectation = XCTestExpectation(description: "progress 50%")

        vc.updateProgress(current: 1, total: 2, message: "Loading")

        DispatchQueue.main.async {
            let label = self.findLabel(in: vc.view, matchingPrefix: "50%")
            XCTAssertNotNil(label, "Expected label with text '50%'")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testUpdateProgress_Completion_Shows100Percent() {
        let vc = FullScreenProgressViewController(totalResources: 5)
        _ = vc.view

        let expectation = XCTestExpectation(description: "progress 100%")

        vc.updateProgress(current: 5, total: 5, message: "Complete")

        DispatchQueue.main.async {
            let label = self.findLabel(in: vc.view, matchingPrefix: "100%")
            XCTAssertNotNil(label, "Expected label with text '100%'")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testUpdateProgress_ZeroOfTen_Shows0Percent() {
        let vc = FullScreenProgressViewController(totalResources: 10)
        _ = vc.view

        let expectation = XCTestExpectation(description: "progress 0%")

        vc.updateProgress(current: 0, total: 10, message: "Starting")

        DispatchQueue.main.async {
            let label = self.findLabel(in: vc.view, matchingPrefix: "0%")
            XCTAssertNotNil(label, "Expected label with text '0%'")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testUpdateProgress_WithResourceName_ShowsInDetailLabel() {
        let vc = FullScreenProgressViewController(totalResources: 10)
        _ = vc.view

        let expectation = XCTestExpectation(description: "resource name in detail")

        vc.updateProgress(current: 3, total: 10, message: "Downloading", resourceName: "app.js")

        DispatchQueue.main.async {
            let label = self.findLabel(in: vc.view, containing: "app.js")
            XCTAssertNotNil(label, "Expected detail label to contain 'app.js'")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testUpdateProgress_WithoutResourceName_ShowsCount() {
        let vc = FullScreenProgressViewController(totalResources: 10)
        _ = vc.view

        let expectation = XCTestExpectation(description: "count in detail without resource name")

        vc.updateProgress(current: 3, total: 10, message: "Downloading")

        DispatchQueue.main.async {
            let label = self.findLabel(in: vc.view, containing: "3 / 10")
            XCTAssertNotNil(label, "Expected detail label to show '3 / 10'")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testUpdateProgress_UpdatesStatusLabel() {
        let vc = FullScreenProgressViewController(totalResources: 10)
        _ = vc.view

        let expectation = XCTestExpectation(description: "status label updated")

        let customMessage = "正在缓存页面资源"
        vc.updateProgress(current: 3, total: 10, message: customMessage)

        DispatchQueue.main.async {
            let label = self.findLabel(in: vc.view, exactText: customMessage)
            XCTAssertNotNil(label, "Expected status label to show '\(customMessage)'")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testAccessibilityIdentifier_IsSet() {
        let vc = FullScreenProgressViewController()
        _ = vc.view
        XCTAssertEqual(vc.view.accessibilityIdentifier, "FullScreenProgressViewController")
    }

    private func findLabel(in view: UIView, exactText: String) -> UILabel? {
        for subview in view.subviews {
            if let label = subview as? UILabel, label.text == exactText {
                return label
            }
            if let found = findLabel(in: subview, exactText: exactText) {
                return found
            }
        }
        return nil
    }

    private func findLabel(in view: UIView, containing: String) -> UILabel? {
        for subview in view.subviews {
            if let label = subview as? UILabel, let text = label.text, text.contains(containing) {
                return label
            }
            if let found = findLabel(in: subview, containing: containing) {
                return found
            }
        }
        return nil
    }

    private func findLabel(in view: UIView, matchingPrefix prefix: String) -> UILabel? {
        for subview in view.subviews {
            if let label = subview as? UILabel, let text = label.text, text.hasPrefix(prefix) {
                return label
            }
            if let found = findLabel(in: subview, matchingPrefix: prefix) {
                return found
            }
        }
        return nil
    }
}
