//
//  HandlerRegistryTests.swift
//  WebBridgeKitTests
//

import XCTest
@testable import WebBridgeKit

final class HandlerRegistryTests: XCTestCase {

    static let expectedHandlers: [String] = [
        "camera",
        "bluetooth",
        "getLocation",
        "scan",
        "haptic",
        "vibrate",
        "photo",
        "media",
        "share",
        "audioLevel",
        "sensors",
        "speech",
        "tts",
        "clipboard",
        "getSystemInfo",
        "getNetworkInfo",
        "systemExtra",
        "openSettings",
        "contacts",
        "layout",
        "screen",
        "gesture",
        "mirroring",
        "requestPermission",
        "getPermissionStatus",
        "openPage",
        "closePage",
        "goBack",
        "getHistory",
        "getPayload",
        "setModal",
        "file",
        "page",
        "cacheDebug"
    ]

    static let expectedCategories: [String: HandlerCategory] = [
        "camera": .hardware,
        "bluetooth": .hardware,
        "getLocation": .hardware,
        "scan": .hardware,
        "haptic": .feedback,
        "vibrate": .feedback,
        "photo": .media,
        "media": .media,
        "share": .media,
        "audioLevel": .sensor,
        "sensors": .sensor,
        "speech": .speech,
        "tts": .speech,
        "clipboard": .clipboard,
        "getSystemInfo": .system,
        "getNetworkInfo": .system,
        "systemExtra": .system,
        "openSettings": .system,
        "contacts": .system,
        "layout": .system,
        "screen": .system,
        "gesture": .system,
        "mirroring": .system,
        "requestPermission": .permission,
        "getPermissionStatus": .permission,
        "openPage": .navigation,
        "closePage": .navigation,
        "goBack": .navigation,
        "getHistory": .navigation,
        "getPayload": .navigation,
        "setModal": .navigation,
        "file": .file,
        "page": .cache,
        "cacheDebug": .debug
    ]

    static let expectedHandlerTypes: [String: BaseWebNativeHandler.Type] = [
        "share": WebShareHandler.self,
        "getLocation": WebLocationHandler.self,
        "requestPermission": WebPermissionHandler.self,
        "getSystemInfo": WebSystemInfoHandler.self,
        "getNetworkInfo": WebNetworkHandler.self,
        "haptic": WebHapticHandler.self,
        "vibrate": WebVibrateHandler.self,
        "clipboard": WebClipboardHandler.self,
        "scan": WebScanHandler.self,
        "camera": WebCameraHandler.self,
        "speech": WebSpeechHandler.self,
        "audioLevel": WebAudioLevelHandler.self,
        "contacts": WebContactsHandler.self,
        "screen": WebScreenHandler.self,
        "layout": WebLayoutHandler.self,
        "mirroring": WebMirroringHandler.self,
        "sensors": WebSensorsHandler.self,
        "media": WebMediaHandler.self,
        "systemExtra": WebSystemExtraHandler.self,
        "tts": WebSpeechSynthesisHandler.self,
        "bluetooth": WebBluetoothHandler.self,
        "file": WebFileHandler.self,
        "photo": WebPhotoHandler.self,
        "getPermissionStatus": WebPermissionStatusHandler.self,
        "openSettings": WebOpenSettingsHandler.self,
        "openPage": WebOpenPageHandler.self,
        "closePage": WebClosePageHandler.self,
        "getHistory": WebGetHistoryHandler.self,
        "getPayload": WebPayloadHandler.self,
        "goBack": WebGoBackHandler.self,
        "setModal": WebSetModalHandler.self,
        "gesture": WebGestureHandler.self,
        "cacheDebug": WebCacheDebugHandler.self,
        "page": WebPageCacheHandler.self
    ]

    override func setUp() {
        super.setUp()
        _ = HandlerMetaRegistry.registerAll
    }

    // MARK: - Registration Completeness

    func testAllHandlersRegistered() {
        let registry = HandlerRegistry.shared

        for action in Self.expectedHandlers {
            XCTAssertTrue(
                registry.isRegistered(action: action),
                "Handler '\(action)' should be registered"
            )
        }

        XCTAssertEqual(
            registry.count,
            Self.expectedHandlers.count,
            "Total registered handler count should match expected (\(Self.expectedHandlers.count))"
        )
    }

    func testNoDuplicateActions() {
        let all = HandlerRegistry.shared.allHandlers()
        let actions = all.map { $0.action }
        let uniqueActions = Set(actions)

        XCTAssertEqual(
            actions.count,
            uniqueActions.count,
            "No duplicate action names should exist in registry"
        )
    }

    // MARK: - Metadata

    func testHandlerMetadataExists() {
        let registry = HandlerRegistry.shared

        for action in Self.expectedHandlers {
            let meta = registry.handler(for: action)
            XCTAssertNotNil(meta, "Metadata for '\(action)' should exist")
            XCTAssertEqual(meta?.action, action)
            XCTAssertFalse(
                meta?.displayName.isEmpty ?? true,
                "'\(action)' should have a non-empty displayName"
            )
            XCTAssertFalse(
                meta?.description.isEmpty ?? true,
                "'\(action)' should have a non-empty description"
            )
        }
    }

    func testHandlerActionMatchesKey() {
        let registry = HandlerRegistry.shared

        for action in Self.expectedHandlers {
            let meta = registry.handler(for: action)
            XCTAssertEqual(
                meta?.action,
                action,
                "Handler meta.action should match the lookup key '\(action)'"
            )
        }
    }

    // MARK: - Categories

    func testHandlerCategories() {
        let registry = HandlerRegistry.shared

        for (action, expectedCategory) in Self.expectedCategories {
            let meta = registry.handler(for: action)
            XCTAssertNotNil(meta, "Handler '\(action)' should exist")
            XCTAssertEqual(
                meta?.category,
                expectedCategory,
                "'\(action)' should be in category \(expectedCategory.rawValue)"
            )
        }
    }

    func testCategorySummaryCoversAllHandlers() {
        let summary = HandlerRegistry.shared.categorySummary()
        let totalCount = summary.reduce(0) { $0 + $1.1 }

        XCTAssertEqual(
            totalCount,
            Self.expectedHandlers.count,
            "Category summary total should equal expected handler count"
        )
    }

    func testAllCategoriesHaveHandlers() {
        let registry = HandlerRegistry.shared

        for category in HandlerCategory.allCases {
            let handlers = registry.handlers(category: category)
            let expectedInCategory = Self.expectedCategories.values.filter { $0 == category }
            if !expectedInCategory.isEmpty {
                XCTAssertGreaterThan(
                    handlers.count,
                    0,
                    "Category \(category.rawValue) should have at least one handler"
                )
            }
        }
    }

    // MARK: - Handler Instantiation

    func testHandlerInstantiation() {
        let registry = HandlerRegistry.shared
        for action in Self.expectedHandlers {
            guard let meta = registry.handler(for: action) else {
                continue
            }
            XCTAssertNotNil(
                meta,
                "Handler meta for action '\(action)' should be registered"
            )
        }
    }

    func testHandlerConformsToWebNativeAPI() {
        let bridge = WebJavaScriptBridge()
        for action in Self.expectedHandlers {
            guard let handler = bridge.getHandler(for: action) else {
                continue
            }
            XCTAssertTrue(
                handler is WebNativeAPI,
                "Handler for '\(action)' should conform to WebNativeAPI"
            )
        }
    }

    // MARK: - Handle Returns Response

    func testHandleReturnsResponse() {
        let bridge = WebJavaScriptBridge()
        let skipActions: Set<String> = [
            "getLocation", "camera", "bluetooth", "audioLevel",
            "speech", "sensors", "media", "photo", "scan",
            "mirroring", "contacts", "openSettings", "screen",
            "page", "cacheDebug", "file", "tts", "gesture",
            "videoStream"
        ]
        for action in Self.expectedHandlers {
            if skipActions.contains(action) { continue }
            guard let handler = bridge.getHandler(for: action) else {
                continue
            }
            let expectation = XCTestExpectation(description: "Handler '\(action)' calls completion")

            handler.handle(body: [:]) { result in
                if let dict = result as? [String: Any] {
                    XCTAssertTrue(
                        dict["success"] != nil,
                        "'\(action)' response should contain 'success' key"
                    )
                } else {
                    XCTFail("'\(action)' should return a dictionary")
                }
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 2.0)
        }
    }

    // MARK: - Documentation Generation

    func testAPIDocJSONCoversAllHandlers() {
        let json = HandlerRegistry.shared.generateAPIDocJSON()

        XCTAssertEqual(
            json.count,
            Self.expectedHandlers.count,
            "API doc JSON should cover all handlers"
        )

        let docActions = Set(json.compactMap { $0["action"] as? String })
        for action in Self.expectedHandlers {
            XCTAssertTrue(
                docActions.contains(action),
                "API doc should include '\(action)'"
            )
        }
    }

    func testAPIDocJSONHasRequiredFields() {
        let json = HandlerRegistry.shared.generateAPIDocJSON()

        for entry in json {
            XCTAssertNotNil(entry["action"], "Each entry should have 'action'")
            XCTAssertNotNil(entry["category"], "Each entry should have 'category'")
            XCTAssertNotNil(entry["displayName"], "Each entry should have 'displayName'")
            XCTAssertNotNil(entry["description"], "Each entry should have 'description'")
        }
    }
}
