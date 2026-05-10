import XCTest

final class TabScreenshotTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["--UITesting", "-UITesting"]
        app.launch()
    }

    func testScreenshotAllTabs() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "Tab bar should exist")

        let tabs = [
            ("首页", "home"),
            ("收信箱", "inbox"),
            ("发现", "discover"),
            ("设置", "settings")
        ]

        for (index, (title, name)) in tabs.enumerated() {
            let tab = tabBar.buttons[title]
            XCTAssertTrue(tab.exists, "Tab '\(title)' should exist")
            tab.tap()
            sleep(1)

            let screenshot = app.screenshot()
            let path = "/tmp/wbk-tab-\(name).png"
            if let data = screenshot.image.pngData() {
                try data.write(to: URL(fileURLWithPath: path))
            }
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "tab-\(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
