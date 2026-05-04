import XCTest
@testable import WebBridgeKit

final class FavoriteManagementTests: XCTestCase {

    var app: XCUIApplication!
    var favoritePage: FavoritePage!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = AppLauncher.shared.launchApp()
        favoritePage = FavoritePage(app: app)

        // Navigate to favorites page
        // (Assuming navigation from main page via tab bar or menu)
        let favoritesTab = app.tabBars.buttons["Favorites"]
        if favoritesTab.exists {
            favoritesTab.tap()
        }
    }

    override func tearDownWithError() throws {
        TestDataManager.shared.cleanupTestData()
        AppLauncher.shared.terminateApp(app)
        app = nil
        favoritePage = nil
    }

    // MARK: - Test Cases

    func testFavoritesPageLoads() {
        // Verify the favorites page loads successfully
        XCTAssertTrue(favoritePage.verifyPageLoaded(), "Favorites page should load within 10 seconds")
    }

    func testEmptyFavoritesState() {
        // Clear all favorites first
        TestDataManager.shared.cleanupTestData()

        // Verify empty state is shown
        XCTAssertTrue(favoritePage.verifyEmptyStateShown(), "Empty state should be shown when no favorites exist")
    }

    func testAddNewFavorite() {
        // Tap add button
        favoritePage.tapAddButton()

        // Wait for add UI to appear
        let addAlert = app.alerts.firstMatch
        XCTAssertTrue(addAlert.waitForExistence(timeout: 5), "Add favorite alert should appear")

        // For actual implementation, would fill in URL and title
        // This test verifies the flow works
        let cancelButton = addAlert.buttons["Cancel"]
        if cancelButton.exists {
            cancelButton.tap()
        }
    }

    func testViewFavoriteDetails() {
        // Prepare test data
        TestDataManager.shared.prepareMockData()

        // Wait for data to load
        let expectation = XCTestExpectation(description: "Wait for favorites")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)

        // Verify favorites exist
        let cellCount = favoritePage.getCellCount()
        if cellCount > 0 {
            // Tap first favorite
            favoritePage.tapCell(at: 0)

            // Verify detail view loads (implementation-specific)
            // For now, verify navigation occurred
            let navigationBar = app.navigationBars.firstMatch
            XCTAssertTrue(navigationBar.exists, "Should navigate to detail view")
        }
    }

    func testDeleteFavorite() {
        // Prepare test data
        TestDataManager.shared.prepareMockData()

        // Wait for data to load
        let expectation = XCTestExpectation(description: "Wait for favorites")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)

        let initialCount = favoritePage.getCellCount()

        if initialCount > 0 {
            // Swipe to delete
            let deleteConfirmed = favoritePage.swipeToDeleteCell(at: 0)
            XCTAssertTrue(deleteConfirmed, "Delete action should be available")

            // Confirm deletion
            favoritePage.confirmDelete()

            // Verify count decreased
            let finalCount = favoritePage.getCellCount()
            XCTAssertEqual(finalCount, initialCount - 1, "Favorite count should decrease by 1")
        }
    }

    func testRefreshFavorites() {
        // Test pull-to-refresh
        favoritePage.refreshPage()

        // Wait for refresh
        let expectation = XCTestExpectation(description: "Wait for refresh")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)

        // Verify table still exists
        XCTAssertTrue(favoritePage.tableView.exists, "Table view should exist after refresh")
    }

    func testFavoritesAccessibility() {
        // Verify all accessibility identifiers
        XCTAssertTrue(app.tables["favorite.tableView"].exists, "Table view accessibility identifier should exist")
        XCTAssertTrue(app.buttons["favorite.addButton"].exists, "Add button accessibility identifier should exist")
    }
}
