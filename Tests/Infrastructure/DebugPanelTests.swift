//
//  DebugPanelTests.swift
//  WebBridgeKitTests
//
//  Created on 2025-05-05.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import XCTest
@testable import WebBridgeKit
@testable import AppTemplate

@MainActor
final class DebugPanelTests: XCTestCase {

    var debugPanel: DebugPanelViewController!
    var tabBarController: TabBarController!

    override func setUp() {
        super.setUp()
        // Ensure handlers are registered
        _ = HandlerMetaRegistry.registerAll
    }

    override func tearDown() {
        debugPanel = nil
        tabBarController = nil
        super.tearDown()
    }

    // MARK: - Initialization

    func testDebugPanelInitialization() {
        debugPanel = DebugPanelViewController()
        XCTAssertNotNil(debugPanel)
        XCTAssertEqual(debugPanel.title, "🧠 Handlers")
    }

    func testTabBarControllerInitialization() {
        tabBarController = TabBarController()
        XCTAssertNotNil(tabBarController)
        XCTAssertEqual(tabBarController.viewControllers?.count, 5)
    }

    // MARK: - Tab Structure

    func testTabBarHasFiveTabs() {
        tabBarController = TabBarController()

        guard let viewControllers = tabBarController.viewControllers else {
            XCTFail("TabBarController should have view controllers")
            return
        }

        XCTAssertEqual(viewControllers.count, 5, "Should have 5 tabs")

        // Check tab bar items
        guard let tabItems = tabBarController.tabBar.items else {
            XCTFail("TabBarController should have tab bar items")
            return
        }

        XCTAssertEqual(tabItems.count, 5)

        // Verify tab titles
        let expectedTitles = ["Web", "Handlers", "Logs", "Diagnostics", "Settings"]
        let actualTitles = tabItems.map { $0.title ?? "" }
        XCTAssertEqual(actualTitles, expectedTitles)
    }

    func testHandlersTabIsSecond() {
        tabBarController = TabBarController()

        guard let viewControllers = tabBarController.viewControllers,
              viewControllers.count > 1 else {
            XCTFail("TabBarController should have at least 2 view controllers")
            return
        }

        let secondNav = viewControllers[1] as? UINavigationController
        XCTAssertNotNil(secondNav, "Second tab should be wrapped in UINavigationController")

        let handlersVC = secondNav?.viewControllers.first as? DebugPanelViewController
        XCTAssertNotNil(handlersVC, "Second tab root should be DebugPanelViewController")
    }

    // MARK: - Handler Display

    func testDebugPanelLoadsHandlers() {
        debugPanel = DebugPanelViewController()
        debugPanel.viewDidLoad()

        // Give time for async operations
        let expectation = self.expectation(description: "Handlers loaded")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)

        // Verify handlers are loaded
        let handlerCount = HandlerRegistry.shared.count
        XCTAssertGreaterThan(handlerCount, 0, "Should have handlers registered")
    }

    func testDebugPanelShowsCategories() {
        debugPanel = DebugPanelViewController()
        debugPanel.viewDidLoad()

        let expectation = self.expectation(description: "Categories loaded")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)

        // Verify categories are present
        let categories = HandlerRegistry.shared.categorySummary()
        XCTAssertGreaterThan(categories.count, 0, "Should have handler categories")
    }

    // MARK: - Navigation

    func testDebugPanelNavigatesToHandlerDetail() {
        debugPanel = DebugPanelViewController()
        debugPanel.viewDidLoad()

        let expectation = self.expectation(description: "Handlers loaded")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)

        // Get first handler
        let handlers = HandlerRegistry.shared.handlers(category: .hardware)
        guard let firstHandler = handlers.first else {
            XCTFail("Should have at least one hardware handler")
            return
        }

        // Create handler detail
        let detailVC = HandlerDetailViewController(meta: firstHandler)
        XCTAssertNotNil(detailVC)
    }

    // MARK: - One-Click Test

    func testDebugPanelHasOneClickTestButton() {
        debugPanel = DebugPanelViewController()
        debugPanel.viewDidLoad()

        XCTAssertNotNil(debugPanel.navigationItem.rightBarButtonItem)
        XCTAssertEqual(debugPanel.navigationItem.rightBarButtonItem?.title, "执行测试")
    }

    func testOneClickTestShowsActionSheet() {
        debugPanel = DebugPanelViewController()
        debugPanel.viewDidLoad()

        let expectation = self.expectation(description: "Action sheet presented")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            debugPanel.performOneClickTest()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if debugPanel.presentedViewController is UIAlertController {
                    expectation.fulfill()
                }
            }
        }

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Integration

    func testTabBarControllerCanBeRootViewController() {
        tabBarController = TabBarController()

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        window.rootViewController = tabBarController
        window.makeKeyAndVisible()

        XCTAssertNotNil(window.rootViewController)
        XCTAssertTrue(window.rootViewController is TabBarController)
    }

    func testDebugPanelCanBeEmbeddedInNavigationController() {
        debugPanel = DebugPanelViewController()
        let navController = UINavigationController(rootViewController: debugPanel)

        XCTAssertEqual(navController.viewControllers.count, 1)
        XCTAssertTrue(navController.viewControllers.first is DebugPanelViewController)
    }

    // MARK: - Handler Registry Integration

    func testDebugPanelUsesHandlerRegistry() {
        let registry = HandlerRegistry.shared

        debugPanel = DebugPanelViewController()
        debugPanel.viewDidLoad()

        let expectation = self.expectation(description: "Handlers loaded")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)

        // Verify debug panel shows handlers from registry
        let handlerCount = registry.count
        XCTAssertGreaterThan(handlerCount, 0)
    }

    func testCommonHandlersAvailable() {
        let registry = HandlerRegistry.shared

        let commonHandlers = ["camera", "getLocation", "share", "clipboard", "haptic"]

        for handlerAction in commonHandlers {
            let handler = registry.handler(for: handlerAction)
            XCTAssertNotNil(handler, "Handler \(handlerAction) should be registered")
        }
    }
}
