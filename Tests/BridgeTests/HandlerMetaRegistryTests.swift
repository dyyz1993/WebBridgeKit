import XCTest
@testable import WebBridgeKit

final class HandlerMetaRegistryTests: XCTestCase {

    override func setUp() {
        super.setUp()
        _ = HandlerMetaRegistry.registerAll
    }

    func testRegisterAllRegistersExpectedHandlerCount() {
        let registry = HandlerRegistry.shared
        let count = registry.count
        XCTAssertGreaterThan(count, 20, "Should register at least 20 handlers")
    }

    func testRegisterAllIncludesCameraHandler() {
        let registry = HandlerRegistry.shared
        let camera = registry.handler(for: "camera")

        XCTAssertNotNil(camera)
        XCTAssertEqual(camera?.category, .hardware)
        XCTAssertEqual(camera?.displayName, "相机")
        XCTAssertTrue(camera?.requiresHardware ?? false)
        XCTAssertTrue(camera?.requiredPermissions.contains("camera") ?? false)
        XCTAssertEqual(camera?.parameters.count, 2)
        XCTAssertEqual(camera?.returns.count, 2)
    }

    func testRegisterAllIncludesBluetoothHandler() {
        let registry = HandlerRegistry.shared
        let bt = registry.handler(for: "bluetooth")

        XCTAssertNotNil(bt)
        XCTAssertEqual(bt?.category, .hardware)
        XCTAssertEqual(bt?.displayName, "蓝牙")
        XCTAssertTrue(bt?.requiredPermissions.contains("bluetooth") ?? false)
    }

    func testRegisterAllIncludesGetLocationHandler() {
        let registry = HandlerRegistry.shared
        let loc = registry.handler(for: "getLocation")

        XCTAssertNotNil(loc)
        XCTAssertEqual(loc?.category, .hardware)
        XCTAssertEqual(loc?.displayName, "定位")
        XCTAssertEqual(loc?.returns.count, 3)
    }

    func testRegisterAllIncludesScanHandler() {
        let registry = HandlerRegistry.shared
        let scan = registry.handler(for: "scan")

        XCTAssertNotNil(scan)
        XCTAssertEqual(scan?.category, .hardware)
        XCTAssertEqual(scan?.displayName, "扫码")
    }

    func testRegisterAllIncludesHapticHandler() {
        let registry = HandlerRegistry.shared
        let haptic = registry.handler(for: "haptic")

        XCTAssertNotNil(haptic)
        XCTAssertEqual(haptic?.category, .feedback)
        XCTAssertEqual(haptic?.displayName, "触感反馈")
        XCTAssertFalse(haptic?.requiresHardware ?? true)
    }

    func testRegisterAllIncludesPhotoHandlerWithMinimumVersion() {
        let registry = HandlerRegistry.shared
        let photo = registry.handler(for: "photo")

        XCTAssertNotNil(photo)
        XCTAssertEqual(photo?.category, .media)
        XCTAssertEqual(photo?.minimumiOSVersion, "14.0")
        XCTAssertTrue(photo?.requiredPermissions.contains("photoLibrary") ?? false)
    }

    func testRegisterAllIncludesClipboardHandlerWithReadWriteOptions() {
        let registry = HandlerRegistry.shared
        let clipboard = registry.handler(for: "clipboard")

        XCTAssertNotNil(clipboard)
        XCTAssertEqual(clipboard?.category, .clipboard)
        let actionParam = clipboard?.parameters.first { $0.name == "action" }
        XCTAssertNotNil(actionParam)
        XCTAssertTrue(actionParam?.required ?? false)
        XCTAssertEqual(actionParam?.options, ["read", "write"])
    }

    func testRegisterAllIncludesRequestPermissionHandler() {
        let registry = HandlerRegistry.shared
        let perm = registry.handler(for: "requestPermission")

        XCTAssertNotNil(perm)
        XCTAssertEqual(perm?.category, .permission)
        XCTAssertEqual(perm?.displayName, "请求权限")
        let permParam = perm?.parameters.first { $0.name == "permission" }
        XCTAssertEqual(permParam?.options?.count, 6)
    }

    func testRegisterAllIncludesNavigationHandlers() {
        let registry = HandlerRegistry.shared
        let navigationActions = ["openPage", "closePage", "goBack", "getHistory", "getPayload", "setModal"]

        for action in navigationActions {
            let handler = registry.handler(for: action)
            XCTAssertNotNil(handler, "Expected \(action) to be registered")
            XCTAssertEqual(handler?.category, .navigation)
        }
    }

    func testRegisterAllIncludesSpeechHandlers() {
        let registry = HandlerRegistry.shared

        let speech = registry.handler(for: "speech")
        XCTAssertNotNil(speech)
        XCTAssertEqual(speech?.category, .speech)
        XCTAssertTrue(speech?.requiresHardware ?? false)

        let tts = registry.handler(for: "tts")
        XCTAssertNotNil(tts)
        XCTAssertEqual(tts?.category, .speech)
        XCTAssertEqual(tts?.parameters.count, 4)
    }

    func testRegisterAllIncludesCacheAndDebugHandlers() {
        let registry = HandlerRegistry.shared

        let page = registry.handler(for: "page")
        XCTAssertNotNil(page)
        XCTAssertEqual(page?.category, .cache)

        let cacheDebug = registry.handler(for: "cacheDebug")
        XCTAssertNotNil(cacheDebug)
        XCTAssertEqual(cacheDebug?.category, .debug)
    }

    func testRegisterAllHandlersHaveValidCategories() {
        let registry = HandlerRegistry.shared
        let allHandlers = registry.allHandlers()

        for handler in allHandlers {
            XCTAssertTrue(HandlerCategory.allCases.contains(handler.category),
                          "\(handler.action) has invalid category: \(handler.category)")
        }
    }

    func testRegisterAllHandlersHaveNonEmptyDescriptions() {
        let registry = HandlerRegistry.shared
        let allHandlers = registry.allHandlers()

        for handler in allHandlers {
            XCTAssertFalse(handler.description.isEmpty,
                           "\(handler.action) should have a non-empty description")
        }
    }

    func testRegisterAllHandlersHaveNonEmptyDisplayNames() {
        let registry = HandlerRegistry.shared
        let allHandlers = registry.allHandlers()

        for handler in allHandlers {
            XCTAssertFalse(handler.displayName.isEmpty,
                           "\(handler.action) should have a non-empty displayName")
        }
    }

    func testCategorySummaryCoversAllRegisteredCategories() {
        let registry = HandlerRegistry.shared
        let summary = registry.categorySummary()
        let summaryCategories = Set(summary.map { $0.0 })

        let registeredCategories = Set(registry.allHandlers().map { $0.category })
        XCTAssertEqual(summaryCategories, registeredCategories,
                       "Category summary should include all registered categories")
    }

    func testRegisterAllIsIdempotent() {
        let registry = HandlerRegistry.shared
        let countBefore = registry.count

        _ = HandlerMetaRegistry.registerAll

        XCTAssertEqual(registry.count, countBefore,
                       "Re-registering should not create duplicate entries")
    }
}
