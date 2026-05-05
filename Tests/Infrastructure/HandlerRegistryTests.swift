//
//  HandlerRegistryTests.swift
//  WebBridgeKitTests
//

import XCTest
@testable import WebBridgeKit

final class HandlerRegistryTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Ensure handlers are registered
        _ = HandlerMetaRegistry.registerAll
    }
    
    // MARK: - Registration
    
    func testHandlersRegistered() {
        let registry = HandlerRegistry.shared
        XCTAssertGreaterThan(registry.count, 0)
    }
    
    func testSpecificHandlerExists() {
        let registry = HandlerRegistry.shared
        
        XCTAssertNotNil(registry.handler(for: "camera"))
        XCTAssertNotNil(registry.handler(for: "getLocation"))
        XCTAssertNotNil(registry.handler(for: "share"))
        XCTAssertNotNil(registry.handler(for: "clipboard"))
        XCTAssertNotNil(registry.handler(for: "haptic"))
        XCTAssertNotNil(registry.handler(for: "openPage"))
        XCTAssertNotNil(registry.handler(for: "closePage"))
    }
    
    func testHandlerMeta() {
        let camera = HandlerRegistry.shared.handler(for: "camera")
        XCTAssertNotNil(camera)
        XCTAssertEqual(camera?.action, "camera")
        XCTAssertEqual(camera?.category, .hardware)
        XCTAssertEqual(camera?.displayName, "相机")
        XCTAssertFalse(camera?.parameters.isEmpty ?? true)
        XCTAssertTrue(camera?.requiresHardware ?? false)
        XCTAssertTrue(camera?.requiredPermissions.contains("camera") ?? false)
    }
    
    // MARK: - Category Query
    
    func testCategoryQuery() {
        let hardware = HandlerRegistry.shared.handlers(category: .hardware)
        XCTAssertGreaterThan(hardware.count, 0)
        
        for handler in hardware {
            XCTAssertEqual(handler.category, .hardware)
        }
    }
    
    func testCategorySummary() {
        let summary = HandlerRegistry.shared.categorySummary()
        XCTAssertGreaterThan(summary.count, 0)
        
        for (category, count) in summary {
            XCTAssertGreaterThan(count, 0)
            XCTAssertFalse(category.displayName.isEmpty)
        }
    }
    
    // MARK: - Documentation Generation
    
    func testAPIDocJSON() {
        let json = HandlerRegistry.shared.generateAPIDocJSON()
        XCTAssertGreaterThan(json.count, 0)
        
        // Each entry should have action and category
        for entry in json {
            XCTAssertNotNil(entry["action"])
            XCTAssertNotNil(entry["category"])
        }
    }
    
    func testAPIDocMarkdown() {
        let md = HandlerRegistry.shared.generateAPIDocMarkdown()
        XCTAssertTrue(md.contains("# WebBridgeKit Handler API Reference"))
        XCTAssertTrue(md.contains("camera"))
        XCTAssertTrue(md.contains("## "))
    }
    
    // MARK: - BridgeError
    
    func testBridgeErrorProperties() {
        let error = BridgeError.permissionDenied(action: "camera", permission: "camera")
        
        XCTAssertEqual(error.errorCode, "PERMISSION_DENIED")
        XCTAssertEqual(error.actionName, "camera")
        XCTAssertFalse(error.suggestion.isEmpty)
        XCTAssertFalse(error.debugInfo.isEmpty)
    }
    
    func testBridgeErrorJSDict() {
        let error = BridgeError.timeout(action: "getLocation", seconds: 30)
        let dict = error.jsErrorDict
        
        XCTAssertEqual(dict["success"] as? Bool, false)
        guard let errorDict = dict["error"] as? [String: Any] else {
            XCTFail("Missing error dict")
            return
        }
        XCTAssertEqual(errorDict["code"] as? String, "TIMEOUT")
        XCTAssertNotNil(errorDict["message"])
        XCTAssertNotNil(errorDict["suggestion"])
    }
    
    func testAllBridgeErrorTypes() {
        let errors: [BridgeError] = [
            .permissionDenied(action: "test", permission: "camera"),
            .parameterInvalid(action: "test", param: "mode", reason: "invalid"),
            .hardwareUnavailable(action: "test", reason: "no GPS"),
            .timeout(action: "test", seconds: 10),
            .cancelled(action: "test"),
            .notSupported(action: "test", reason: "old iOS"),
            .executionFailed(action: "test", underlyingError: NSError(domain: "test", code: 1)),
            .notRegistered(action: "unknown")
        ]
        
        for error in errors {
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
            XCTAssertFalse(error.errorCode.isEmpty)
            XCTAssertFalse(error.suggestion.isEmpty)
            XCTAssertFalse(error.debugInfo.isEmpty)
            XCTAssertFalse(error.actionName.isEmpty)
        }
    }
}
