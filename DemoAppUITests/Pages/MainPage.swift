import XCTest

class MainPage: BasePage {

    // MARK: - UI Elements

    var collectionView: XCUIElement {
        return app.otherElements["main.collectionView"]
    }

    var scanButton: XCUIElement {
        return app.buttons["main.scanButton"]
    }

    // MARK: - Page Verification

    func verifyPageLoaded() -> Bool {
        return waitForElementToAppear(collectionView, timeout: 10)
    }

    // MARK: - Actions

    func tapCell(at index: Int) {
        let cell = getCell(at: index)
        // Make sure the cell exists and is hittable before tapping
        if cell.exists && cell.isHittable {
            tapElement(cell)
        } else {
            // Try scrolling to the cell
            collectionView.swipeUp()
            Thread.sleep(forTimeInterval: 0.5)
            let retryCell = getCell(at: index)
            if retryCell.exists {
                tapElement(retryCell)
            }
        }
    }

    func getCell(at index: Int) -> XCUIElement {
        // Access collection view cells properly
        return collectionView.cells.element(boundBy: index)
    }

    func getCellCount() -> Int {
        return collectionView.cells.count
    }

    func tapScanButton() {
        tapElement(scanButton)
    }

    func refreshPage() {
        if collectionView.exists {
            collectionView.swipeDown()
        }
    }

    // MARK: - Verification Helpers

    func verifyCellExists(at index: Int) -> Bool {
        let cell = getCell(at: index)
        return cell.exists && waitForElementToAppear(cell, timeout: 2)
    }

    func verifyPageNotEmpty() -> Bool {
        return getCellCount() > 0
    }
}
