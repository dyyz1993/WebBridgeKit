import XCTest

class SettingsPage: BasePage {

    // MARK: - UI Elements

    var tableView: XCUIElement {
        return app.tables["settings.tableView"]
    }

    var navigationBar: XCUIElement {
        return app.navigationBars["设置"]
    }

    // MARK: - Page Verification

    func verifyPageLoaded() -> Bool {
        return waitForElementToAppear(tableView, timeout: 10)
    }

    // MARK: - Cell Access

    func getCell(at index: Int) -> XCUIElement {
        return tableView.cells.element(boundBy: index)
    }

    func getCellCount() -> Int {
        return tableView.cells.count
    }

    // MARK: - Menu Items

    enum SettingsMenuItem: String {
        case tokenManage = "口令管理"
        case serverConfig = "服务器配置"
        case apiKeyManage = "密钥管理"
        case about = "关于"

        var cellIdentifier: String {
            switch self {
            case .tokenManage: return "settings.cell.tokenManage"
            case .serverConfig: return "settings.cell.serverConfig"
            case .apiKeyManage: return "settings.cell.apiKeyManage"
            case .about: return "settings.cell.about"
            }
        }
    }

    // MARK: - Actions

    func tapMenuItem(_ item: SettingsMenuItem) {
        let cell = tableView.cells[item.cellIdentifier]
        tapElement(cell)
    }

    func tapCell(at index: Int) {
        let cell = getCell(at: index)
        tapElement(cell)
    }

    func tapTokenManage() {
        tapMenuItem(.tokenManage)
    }

    func tapServerConfig() {
        tapMenuItem(.serverConfig)
    }

    func tapApiKeyManage() {
        tapMenuItem(.apiKeyManage)
    }

    func tapAbout() {
        tapMenuItem(.about)
    }

    // MARK: - Verification

    func verifyMenuItemExists(_ item: SettingsMenuItem) -> Bool {
        let cell = tableView.cells[item.cellIdentifier]
        return cell.exists
    }

    func verifyAllMenuItemsExist() -> Bool {
        return verifyMenuItemExists(.tokenManage) &&
               verifyMenuItemExists(.serverConfig) &&
               verifyMenuItemExists(.apiKeyManage) &&
               verifyMenuItemExists(.about)
    }

    // MARK: - Navigation

    func navigateBack() {
        let backButton = navigationBar.buttons.firstMatch
        if backButton.exists {
            tapElement(backButton)
        }
    }
}
