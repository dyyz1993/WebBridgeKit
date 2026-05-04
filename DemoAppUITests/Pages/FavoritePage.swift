import XCTest

class FavoritePage: BasePage {

    // MARK: - UI Elements

    var tableView: XCUIElement {
        return app.tables["favorite.tableView"]
    }

    var addButton: XCUIElement {
        return app.buttons["favorite.addButton"]
    }

    var emptyStateView: XCUIElement {
        return app.otherElements["favorite.emptyStateView"]
    }

    var navigationBar: XCUIElement {
        return app.navigationBars["Favorites"]
    }

    // MARK: - Page Verification

    func verifyPageLoaded() -> Bool {
        return waitForElementToAppear(tableView, timeout: 10)
    }

    func verifyEmptyStateShown() -> Bool {
        return waitForElementToAppear(emptyStateView, timeout: 5)
    }

    // MARK: - Actions

    func tapAddButton() {
        tapElement(addButton)
    }

    func tapCell(at index: Int) {
        let cell = getCell(at: index)
        tapElement(cell)
    }

    func swipeToDeleteCell(at index: Int) -> Bool {
        let cell = getCell(at: index)
        cell.swipeLeft()

        // Wait for delete button to appear
        let deleteButton = cell.buttons["Delete"]
        return waitForElementToAppear(deleteButton, timeout: 2)
    }

    func confirmDelete() {
        let deleteButton = app.buttons["Delete"]
        if deleteButton.exists {
            tapElement(deleteButton)
        }
    }

    // MARK: - Cell Access

    func getCell(at index: Int) -> XCUIElement {
        return tableView.cells.element(boundBy: index)
    }

    func getCellCount() -> Int {
        return tableView.cells.count
    }

    func getCellTitle(at index: Int) -> String {
        let cell = getCell(at: index)
        return cell.staticTexts.firstMatch.label
    }

    // MARK: - Search

    func searchFor(text: String) {
        let searchField = app.searchFields.firstMatch
        if searchField.exists {
            tapElement(searchField)
            typeText(text, into: searchField)
        }
    }

    // MARK: - Refresh

    func refreshPage() {
        tableView.swipeDown()
    }
}
