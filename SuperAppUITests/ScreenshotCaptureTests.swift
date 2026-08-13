import XCTest

final class ScreenshotCaptureTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["--ui-testing"]
    }

    private func capture(_ name: String) {
        XCTAssertFalse(app.alerts.firstMatch.exists, "Screenshot must not contain a blocking alert")
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let outputDir = "/tmp/wbk-screenshots"
        let fm = FileManager.default
        try? fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
        if let data = screenshot.image.pngData() {
            try? data.write(to: URL(fileURLWithPath: "\(outputDir)/\(name).png"))
        }
    }

    private func navigateToTab(index: Int) {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.exists else { return }
        let buttons = tabBar.buttons.allElementsBoundByIndex
        guard index < buttons.count else { return }
        buttons[index].tap()
        sleep(1)
    }

    func testLightModeScreenshots() throws {
        app.launchEnvironment = ["UI_USER_INTERFACE_STYLE": "Light"]
        app.launch()
        sleep(2)

        navigateToTab(index: 0)
        capture("01-home-light")

        navigateToTab(index: 1)
        capture("02-inbox-light")

        navigateToTab(index: 2)
        capture("03-settings-light")
    }

    func testDarkModeScreenshots() throws {
        app.launchEnvironment = ["UI_USER_INTERFACE_STYLE": "Dark"]
        app.launch()
        sleep(2)

        navigateToTab(index: 0)
        capture("04-home-dark")

        navigateToTab(index: 1)
        capture("05-inbox-dark")

        navigateToTab(index: 2)
        capture("06-settings-dark")
    }
}
