import XCTest

final class GroupedHangTest: XCTestCase {
    func testGroupedInboxHang() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        sleep(6)
        let notif = app.tabBars.buttons["通知"]
        if notif.waitForExistence(timeout: 6) { notif.tap() }
        sleep(2)
        let grouped = app.segmentedControls.buttons["分组"]
        if grouped.waitForExistence(timeout: 4) {
            grouped.tap()
            sleep(8)  // 停留分组模式，若有无限 reload/动画循环这里会暴露
        }
        let att = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        att.name = "grouped-state"
        att.lifetime = .keepAlways
        add(att)
        sleep(8)
    }
}
