//
//  HistoryPage.swift
//  DemoAppUITests
//
//  Created on 2025-01-31.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import XCTest
@testable import WebBridgeKit

/// Page Object for Main/History page
/// The MainViewController displays WebPageHistory in a grid layout
class HistoryPage: BasePage {

    // MARK: - UI Elements

    var collectionView: XCUIElement {
        return app.otherElements["main.collectionView"]
    }

    var scanButton: XCUIElement {
        return app.buttons["main.scanButton"]
    }

    var emptyStateView: XCUIElement {
        return app.otherElements["EmptyStateView"]
    }

    var searchBar: XCUIElement {
        return app.searchFields["history.searchBar"]
    }

    // MARK: - Page Verification

    func verifyPageLoaded() -> Bool {
        return waitForElementToAppear(collectionView, timeout: 10)
    }

    func verifyEmptyState() -> Bool {
        return waitForElementToAppear(emptyStateView, timeout: 5)
    }

    // MARK: - Actions

    /// Tap a history cell at the given index
    func tapCell(at index: Int) {
        let cell = getCell(at: index)
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

    /// Long press a history cell to show action sheet
    func longPressCell(at index: Int) {
        let cell = getCell(at: index)
        XCTAssertTrue(cell.waitForExistence(timeout: timeout), "Cell does not exist at index \(index)")

        // Long press on the cell
        cell.press(forDuration: 1.0)
    }

    /// Refresh the history list using pull-to-refresh
    func refreshPage() {
        if collectionView.exists {
            collectionView.swipeDown()
        }
    }

    /// Tap the scan button
    func tapScanButton() {
        tapElement(scanButton)
    }

    /// Search history by keyword
    func searchHistory(_ keyword: String) {
        if searchBar.exists {
            typeText(keyword, into: searchBar)
        } else {
            // If there's no search bar, we'll need to handle this differently
            // For now, just log that search is not available
            print("Search bar not found on history page")
        }
    }

    /// Clear search text
    func clearSearch() {
        if searchBar.exists {
            let clearButton = searchBar.buttons["Clear text"]
            if clearButton.exists {
                clearButton.tap()
            }
        }
    }

    // MARK: - Cell Access

    func getCell(at index: Int) -> XCUIElement {
        return collectionView.cells.element(boundBy: index)
    }

    func getCellCount() -> Int {
        return collectionView.cells.count
    }

    /// Get the title label from a cell
    func getCellTitle(at index: Int) -> String? {
        let cell = getCell(at: index)
        if cell.exists {
            let titleLabel = cell.staticTexts.element(boundBy: 0)
            return titleLabel.label
        }
        return nil
    }

    /// Get the URL label from a cell
    func getCellURL(at index: Int) -> String? {
        let cell = getCell(at: index)
        if cell.exists {
            let urlLabel = cell.staticTexts.element(boundBy: 1)
            return urlLabel.label
        }
        return nil
    }

    /// Check if a cell has the favorite icon
    func isCellFavorited(at index: Int) -> Bool {
        let cell = getCell(at: index)
        if cell.exists {
            let favoriteIcon = cell.images["star.fill"]
            return favoriteIcon.exists
        }
        return false
    }

    /// Check if a cell has the cached badge
    func isCellCached(at index: Int) -> Bool {
        let cell = getCell(at: index)
        if cell.exists {
            let cachedBadge = cell.staticTexts["已缓存"]
            return cachedBadge.exists
        }
        return false
    }

    // MARK: - Verification Helpers

    func verifyCellExists(at index: Int) -> Bool {
        let cell = getCell(at: index)
        return cell.exists && waitForElementToAppear(cell, timeout: 2)
    }

    func verifyPageNotEmpty() -> Bool {
        return getCellCount() > 0
    }

    func verifyCellWithTitleExists(_ title: String) -> Bool {
        let cells = collectionView.cells
        for i in 0..<cells.count {
            let cell = cells.element(boundBy: i)
            if cell.exists {
                let titleLabel = cell.staticTexts.element(boundBy: 0)
                if titleLabel.label.contains(title) {
                    return true
                }
            }
        }
        return false
    }

    func verifyCellWithURLExists(_ url: String) -> Bool {
        let cells = collectionView.cells
        for i in 0..<cells.count {
            let cell = cells.element(boundBy: i)
            if cell.exists {
                let urlLabel = cell.staticTexts.element(boundBy: 1)
                if urlLabel.label.contains(url) {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Action Sheet Interactions

    /// Tap "打开" (Open) button in action sheet
    func tapOpenInActionSheet() {
        let openButton = app.buttons["actionsheet.打开"]
        XCTAssertTrue(openButton.waitForExistence(timeout: 5), "Open button should exist in action sheet")
        openButton.tap()
    }

    /// Tap "收藏" (Favorite) button in action sheet
    func tapFavoriteInActionSheet() {
        let favoriteButton = app.buttons["actionsheet.收藏"]
        XCTAssertTrue(favoriteButton.waitForExistence(timeout: 5), "Favorite button should exist in action sheet")
        favoriteButton.tap()
    }

    /// Tap "从历史移除" (Remove from history) button in action sheet
    func tapRemoveFromHistoryInActionSheet() {
        let removeButton = app.buttons["actionsheet.从历史移除"]
        XCTAssertTrue(removeButton.waitForExistence(timeout: 5), "Remove button should exist in action sheet")
        removeButton.tap()
    }

    /// Dismiss action sheet
    func dismissActionSheet() {
        // Tap outside the action sheet or tap Cancel if available
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.exists {
            cancelButton.tap()
        } else {
            app.tap()
        }
    }

    // MARK: - Navigation

    /// Navigate back to this page
    func navigateToHistory() {
        // Assuming this is the first tab (首页/Home)
        let tabBarController = app.tabBars.firstMatch
        let mainTab = tabBarController.buttons["首页"]
        if mainTab.exists {
            mainTab.tap()
        }
    }
}
