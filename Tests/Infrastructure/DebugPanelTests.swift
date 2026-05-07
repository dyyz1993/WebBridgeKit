//
//  DebugPanelTests.swift
//  WebBridgeKitTests
//

import XCTest
@testable import WebBridgeKit

@MainActor
final class DebugPanelTests: XCTestCase {

    var debugPanel: DebugPanel!

    override func setUp() {
        super.setUp()
        debugPanel = DebugPanel.shared
    }

    override func tearDown() {
        debugPanel = nil
        super.tearDown()
    }

    func testDebugPanelSingleton() {
        XCTAssertTrue(DebugPanel.shared === DebugPanel.shared)
    }

    func testDebugPanelNotShowingByDefault() {
        XCTAssertFalse(debugPanel.isShowing)
    }

    func testDebugPanelViewControllerInit() {
        let vc = DebugPanelViewController()
        XCTAssertNotNil(vc)
    }

    func testDebugPanelViewControllerCanBeEmbeddedInNavigation() {
        let vc = DebugPanelViewController()
        let navController = UINavigationController(rootViewController: vc)
        XCTAssertEqual(navController.viewControllers.count, 1)
    }

    func testHandlerRegistryHasHandlers() {
        let handlerCount = HandlerRegistry.shared.count
        XCTAssertGreaterThan(handlerCount, 0)
    }

    func testHandlerRegistryHasCategories() {
        let categories = HandlerRegistry.shared.categorySummary()
        XCTAssertGreaterThan(categories.count, 0)
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
