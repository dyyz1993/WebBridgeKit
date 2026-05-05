//
//  BridgeCoreTests.swift
//  WebBridgeKitTests
//

import XCTest
@testable import WebBridgeKit

final class BridgeCoreTests: XCTestCase {

    // MARK: - HandlerRegistry

    private var registry: HandlerRegistry!

    override func setUp() {
        super.setUp()
        registry = HandlerRegistry.shared
        _ = HandlerMetaRegistry.registerAll
    }

    // MARK: - HandlerRegistry: Register

    func testRegisterSingleHandler() {
        let meta = makeMeta(action: "testAction_unitTest")
        registry.register(meta)

        XCTAssertTrue(registry.isRegistered(action: "testAction_unitTest"))
        XCTAssertEqual(registry.handler(for: "testAction_unitTest")?.displayName, "Test")
    }

    func testRegisterBatchHandlers() {
        let metas = [
            makeMeta(action: "batchA_unitTest"),
            makeMeta(action: "batchB_unitTest")
        ]
        registry.register(metas)

        XCTAssertTrue(registry.isRegistered(action: "batchA_unitTest"))
        XCTAssertTrue(registry.isRegistered(action: "batchB_unitTest"))
    }

    func testRegisterOverwritesExisting() {
        let original = makeMeta(action: "overwrite_unitTest", displayName: "Original")
        let updated = makeMeta(action: "overwrite_unitTest", displayName: "Updated")
        registry.register(original)
        registry.register(updated)

        XCTAssertEqual(registry.handler(for: "overwrite_unitTest")?.displayName, "Updated")
    }

    // MARK: - HandlerRegistry: Query

    func testHandlerForExistingAction() {
        let meta = makeMeta(action: "queryExist_unitTest")
        registry.register(meta)

        let result = registry.handler(for: "queryExist_unitTest")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.action, "queryExist_unitTest")
    }

    func testHandlerForNonExistentReturnsNil() {
        let result = registry.handler(for: "nonExistent_action_xyz")
        XCTAssertNil(result)
    }

    func testAllHandlersSortedByAction() {
        let metas = [
            makeMeta(action: "zzz_last_unitTest"),
            makeMeta(action: "aaa_first_unitTest"),
            makeMeta(action: "mmm_middle_unitTest")
        ]
        for meta in metas { registry.register(meta) }

        let all = registry.allHandlers()
        let unitTestHandlers = all.filter { $0.action.hasSuffix("_unitTest") && $0.action.hasPrefix("zzz_") || $0.action.hasPrefix("aaa_") || $0.action.hasPrefix("mmm_") }
            .sorted { $0.action < $1.action }

        XCTAssertGreaterThanOrEqual(unitTestHandlers.count, 3)
        if unitTestHandlers.count >= 3 {
            XCTAssertEqual(unitTestHandlers[0].action, "aaa_first_unitTest")
            XCTAssertEqual(unitTestHandlers[2].action, "zzz_last_unitTest")
        }
    }

    func testHandlersByCategory() {
        let hardwareMeta = makeMeta(action: "catHardware_unitTest", category: .hardware)
        let systemMeta = makeMeta(action: "catSystem_unitTest", category: .system)
        registry.register(hardwareMeta)
        registry.register(systemMeta)

        let hardwareHandlers = registry.handlers(category: .hardware)
        let systemHandlers = registry.handlers(category: .system)

        XCTAssertTrue(hardwareHandlers.contains { $0.action == "catHardware_unitTest" })
        XCTAssertTrue(systemHandlers.contains { $0.action == "catSystem_unitTest" })
        XCTAssertFalse(hardwareHandlers.contains { $0.action == "catSystem_unitTest" })
    }

    func testIsRegistered() {
        XCTAssertFalse(registry.isRegistered(action: "notRegistered_unitTest"))
        registry.register(makeMeta(action: "notRegistered_unitTest"))
        XCTAssertTrue(registry.isRegistered(action: "notRegistered_unitTest"))
    }

    func testCountReflectsRegistrations() {
        let initialCount = registry.count
        registry.register(makeMeta(action: "countA_unitTest"))
        registry.register(makeMeta(action: "countB_unitTest"))
        XCTAssertEqual(registry.count, initialCount + 2)
    }

    func testCategorySummary() {
        registry.register(makeMeta(action: "summaryHw_unitTest", category: .hardware))
        registry.register(makeMeta(action: "summaryHw2_unitTest", category: .hardware))
        registry.register(makeMeta(action: "summarySys_unitTest", category: .system))

        let summary = registry.categorySummary()
        let hardwareEntry = summary.first { $0.0 == .hardware }
        let systemEntry = summary.first { $0.0 == .system }

        XCTAssertGreaterThanOrEqual(hardwareEntry?.1 ?? 0, 2)
        XCTAssertGreaterThanOrEqual(systemEntry?.1 ?? 0, 1)
    }

    func testEmptyCategoryNotInSummary() {
        let summary = registry.categorySummary()
        let categories = summary.map { $0.0 }
        for (category, count) in summary {
            XCTAssertGreaterThan(count, 0, "Category \(category.rawValue) should have count > 0")
        }
    }

    // MARK: - HandlerRegistry: Documentation

    func testGenerateAPIDocJSON() {
        let json = registry.generateAPIDocJSON()
        XCTAssertGreaterThan(json.count, 0)

        for entry in json {
            XCTAssertNotNil(entry["action"])
            XCTAssertNotNil(entry["category"])
        }
    }

    func testGenerateAPIDocMarkdown() {
        let md = registry.generateAPIDocMarkdown()
        XCTAssertTrue(md.contains("# WebBridgeKit Handler API Reference"))
        XCTAssertTrue(md.contains("Total:"))
    }

    // MARK: - HandlerMeta

    func testHandlerMetaCreation() {
        let params = [
            ParamDef(name: "mode", type: .string, required: true, description: "Mode"),
            ParamDef(name: "count", type: .int, required: false, defaultValue: "5", description: "Count")
        ]
        let returns = [ReturnDef(name: "data", type: .string, description: "Result data")]

        let meta = HandlerMeta(
            action: "metaTest",
            category: .media,
            displayName: "Meta Test",
            description: "A test handler",
            requiredPermissions: ["camera"],
            parameters: params,
            returns: returns,
            requiresNetwork: true,
            requiresHardware: true,
            minimumiOSVersion: "15.0"
        )

        XCTAssertEqual(meta.action, "metaTest")
        XCTAssertEqual(meta.category, .media)
        XCTAssertEqual(meta.displayName, "Meta Test")
        XCTAssertEqual(meta.description, "A test handler")
        XCTAssertEqual(meta.requiredPermissions, ["camera"])
        XCTAssertEqual(meta.parameters.count, 2)
        XCTAssertEqual(meta.returns.count, 1)
        XCTAssertTrue(meta.requiresNetwork)
        XCTAssertTrue(meta.requiresHardware)
        XCTAssertEqual(meta.minimumiOSVersion, "15.0")
    }

    func testHandlerMetaDefaultValues() {
        let meta = HandlerMeta(
            action: "defaultsTest",
            category: .debug,
            displayName: "Defaults",
            description: "Test defaults"
        )

        XCTAssertEqual(meta.requiredPermissions, [])
        XCTAssertEqual(meta.parameters, [])
        XCTAssertEqual(meta.returns, [])
        XCTAssertFalse(meta.requiresNetwork)
        XCTAssertFalse(meta.requiresHardware)
        XCTAssertNil(meta.minimumiOSVersion)
    }

    func testHandlerMetaJsonDict() {
        let meta = HandlerMeta(
            action: "jsonTest",
            category: .system,
            displayName: "JSON Test",
            description: "Test JSON output",
            requiredPermissions: ["location"],
            parameters: [ParamDef(name: "accuracy", type: .string, required: false, defaultValue: "high", description: "Accuracy")],
            returns: [ReturnDef(name: "lat", type: .double, description: "Latitude")],
            minimumiOSVersion: "14.0"
        )

        let dict = meta.jsonDict
        XCTAssertEqual(dict["action"] as? String, "jsonTest")
        XCTAssertEqual(dict["category"] as? String, "system")
        XCTAssertEqual(dict["displayName"] as? String, "JSON Test")
        XCTAssertEqual(dict["requiresNetwork"] as? Bool, false)
        XCTAssertEqual(dict["requiresHardware"] as? Bool, false)
        XCTAssertNotNil(dict["requiredPermissions"])
        XCTAssertNotNil(dict["parameters"])
        XCTAssertNotNil(dict["returns"])
        XCTAssertEqual(dict["minimumiOSVersion"] as? String, "14.0")
    }

    func testHandlerMetaJsonDictOmitsEmptyFields() {
        let meta = HandlerMeta(
            action: "minimalJson",
            category: .cache,
            displayName: "Minimal",
            description: "Minimal meta"
        )

        let dict = meta.jsonDict
        XCTAssertNil(dict["requiredPermissions"])
        XCTAssertNil(dict["parameters"])
        XCTAssertNil(dict["returns"])
        XCTAssertNil(dict["minimumiOSVersion"])
    }

    // MARK: - ParamDef & ReturnDef

    func testParamDefCreation() {
        let param = ParamDef(name: "quality", type: .string, required: true, defaultValue: "high", description: "Quality level", options: ["high", "medium", "low"])
        XCTAssertEqual(param.name, "quality")
        XCTAssertEqual(param.type, .string)
        XCTAssertTrue(param.required)
        XCTAssertEqual(param.defaultValue, "high")
        XCTAssertEqual(param.description, "Quality level")
        XCTAssertEqual(param.options, ["high", "medium", "low"])
    }

    func testParamDefDefaults() {
        let param = ParamDef(name: "test", type: .bool, description: "desc")
        XCTAssertFalse(param.required)
        XCTAssertNil(param.defaultValue)
        XCTAssertNil(param.options)
    }

    func testReturnDefCreation() {
        let ret = ReturnDef(name: "result", type: .array, description: "Result list")
        XCTAssertEqual(ret.name, "result")
        XCTAssertEqual(ret.type, .array)
        XCTAssertEqual(ret.description, "Result list")
    }

    // MARK: - ParamType

    func testParamTypeRawValues() {
        XCTAssertEqual(ParamType.string.rawValue, "string")
        XCTAssertEqual(ParamType.int.rawValue, "int")
        XCTAssertEqual(ParamType.double.rawValue, "double")
        XCTAssertEqual(ParamType.bool.rawValue, "bool")
        XCTAssertEqual(ParamType.array.rawValue, "array")
        XCTAssertEqual(ParamType.object.rawValue, "object")
    }

    // MARK: - HandlerCategory

    func testAllHandlerCategories() {
        let allCases = HandlerCategory.allCases
        XCTAssertTrue(allCases.contains(.hardware))
        XCTAssertTrue(allCases.contains(.media))
        XCTAssertTrue(allCases.contains(.navigation))
        XCTAssertTrue(allCases.contains(.system))
        XCTAssertTrue(allCases.contains(.feedback))
        XCTAssertTrue(allCases.contains(.sensor))
        XCTAssertTrue(allCases.contains(.clipboard))
        XCTAssertTrue(allCases.contains(.permission))
        XCTAssertTrue(allCases.contains(.debug))
        XCTAssertTrue(allCases.contains(.cache))
        XCTAssertTrue(allCases.contains(.file))
        XCTAssertTrue(allCases.contains(.speech))
        XCTAssertEqual(allCases.count, 12)
    }

    func testHandlerCategoryDisplayNames() {
        XCTAssertEqual(HandlerCategory.hardware.displayName, "硬件")
        XCTAssertEqual(HandlerCategory.media.displayName, "媒体")
        XCTAssertEqual(HandlerCategory.navigation.displayName, "导航")
        XCTAssertEqual(HandlerCategory.system.displayName, "系统")
        XCTAssertEqual(HandlerCategory.feedback.displayName, "反馈")
        XCTAssertEqual(HandlerCategory.sensor.displayName, "传感器")
        XCTAssertEqual(HandlerCategory.clipboard.displayName, "剪贴板")
        XCTAssertEqual(HandlerCategory.permission.displayName, "权限")
        XCTAssertEqual(HandlerCategory.debug.displayName, "调试")
        XCTAssertEqual(HandlerCategory.cache.displayName, "缓存")
        XCTAssertEqual(HandlerCategory.file.displayName, "文件")
        XCTAssertEqual(HandlerCategory.speech.displayName, "语音")
    }

    func testHandlerCategoryEmoji() {
        for category in HandlerCategory.allCases {
            XCTAssertFalse(category.emoji.isEmpty, "\(category.rawValue) emoji should not be empty")
        }
    }

    func testHandlerCategoryRawValues() {
        XCTAssertEqual(HandlerCategory.hardware.rawValue, "hardware")
        XCTAssertEqual(HandlerCategory.media.rawValue, "media")
        XCTAssertEqual(HandlerCategory.navigation.rawValue, "navigation")
        XCTAssertEqual(HandlerCategory.system.rawValue, "system")
    }

    func testHandlerCategoryCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for category in HandlerCategory.allCases {
            let data = try encoder.encode(category)
            let decoded = try decoder.decode(HandlerCategory.self, from: data)
            XCTAssertEqual(decoded, category)
        }
    }

    // MARK: - BridgeError

    func testPermissionDeniedError() {
        let error = BridgeError.permissionDenied(action: "camera", permission: "camera")
        XCTAssertEqual(error.errorDescription, "[camera] Permission denied: camera")
        XCTAssertEqual(error.errorCode, "PERMISSION_DENIED")
        XCTAssertEqual(error.actionName, "camera")
        XCTAssertTrue(error.suggestion.contains("camera"))
    }

    func testParameterInvalidError() {
        let error = BridgeError.parameterInvalid(action: "scan", param: "format", reason: "unsupported")
        XCTAssertEqual(error.errorDescription, "[scan] Invalid parameter 'format': unsupported")
        XCTAssertEqual(error.errorCode, "PARAMETER_INVALID")
        XCTAssertEqual(error.actionName, "scan")
        XCTAssertTrue(error.suggestion.contains("format"))
    }

    func testHardwareUnavailableError() {
        let error = BridgeError.hardwareUnavailable(action: "bluetooth", reason: "not found")
        XCTAssertEqual(error.errorDescription, "[bluetooth] Hardware unavailable: not found")
        XCTAssertEqual(error.errorCode, "HARDWARE_UNAVAILABLE")
        XCTAssertEqual(error.actionName, "bluetooth")
    }

    func testTimeoutError() {
        let error = BridgeError.timeout(action: "getLocation", seconds: 30.0)
        XCTAssertTrue(error.errorDescription?.contains("Timeout after 30.0s") ?? false)
        XCTAssertEqual(error.errorCode, "TIMEOUT")
        XCTAssertEqual(error.actionName, "getLocation")
    }

    func testCancelledError() {
        let error = BridgeError.cancelled(action: "speech")
        XCTAssertEqual(error.errorDescription, "[speech] Cancelled by user")
        XCTAssertEqual(error.errorCode, "CANCELLED")
        XCTAssertEqual(error.actionName, "speech")
    }

    func testNotSupportedError() {
        let error = BridgeError.notSupported(action: "file", reason: "iOS 14 required")
        XCTAssertEqual(error.errorDescription, "[file] Not supported: iOS 14 required")
        XCTAssertEqual(error.errorCode, "NOT_SUPPORTED")
        XCTAssertEqual(error.actionName, "file")
    }

    func testExecutionFailedError() {
        let underlying = NSError(domain: "test", code: 42, userInfo: [NSLocalizedDescriptionKey: "inner error"])
        let error = BridgeError.executionFailed(action: "media", underlyingError: underlying)
        XCTAssertTrue(error.errorDescription?.contains("Execution failed") ?? false)
        XCTAssertEqual(error.errorCode, "EXECUTION_FAILED")
        XCTAssertEqual(error.actionName, "media")
        XCTAssertTrue(error.suggestion.contains("inner error"))
    }

    func testNotRegisteredError() {
        let error = BridgeError.notRegistered(action: "unknownAction")
        XCTAssertEqual(error.errorDescription, "[unknownAction] Handler not registered")
        XCTAssertEqual(error.errorCode, "NOT_REGISTERED")
        XCTAssertEqual(error.actionName, "unknownAction")
    }

    func testAllErrorCodes() {
        XCTAssertEqual(BridgeError.permissionDenied(action: "a", permission: "p").errorCode, "PERMISSION_DENIED")
        XCTAssertEqual(BridgeError.parameterInvalid(action: "a", param: "p", reason: "r").errorCode, "PARAMETER_INVALID")
        XCTAssertEqual(BridgeError.hardwareUnavailable(action: "a", reason: "r").errorCode, "HARDWARE_UNAVAILABLE")
        XCTAssertEqual(BridgeError.timeout(action: "a", seconds: 1).errorCode, "TIMEOUT")
        XCTAssertEqual(BridgeError.cancelled(action: "a").errorCode, "CANCELLED")
        XCTAssertEqual(BridgeError.notSupported(action: "a", reason: "r").errorCode, "NOT_SUPPORTED")
        XCTAssertEqual(BridgeError.executionFailed(action: "a", underlyingError: NSError(domain: "", code: 0)).errorCode, "EXECUTION_FAILED")
        XCTAssertEqual(BridgeError.notRegistered(action: "a").errorCode, "NOT_REGISTERED")
    }

    func testErrorDebugInfo() {
        let error = BridgeError.permissionDenied(action: "camera", permission: "camera")
        let debug = error.debugInfo
        XCTAssertTrue(debug.contains("PERMISSION_DENIED"))
        XCTAssertTrue(debug.contains("camera"))
    }

    func testJSErrorDict() {
        let error = BridgeError.timeout(action: "getLocation", seconds: 10)
        let dict = error.jsErrorDict

        XCTAssertEqual(dict["success"] as? Bool, false)
        guard let errorDict = dict["error"] as? [String: Any] else {
            XCTFail("error dict should exist")
            return
        }
        XCTAssertEqual(errorDict["code"] as? String, "TIMEOUT")
        XCTAssertEqual(errorDict["action"] as? String, "getLocation")
        XCTAssertNotNil(errorDict["message"])
        XCTAssertNotNil(errorDict["suggestion"])
    }

    func testAllErrorsHaveNonEmptyDescriptions() {
        let errors: [BridgeError] = [
            .permissionDenied(action: "a", permission: "p"),
            .parameterInvalid(action: "a", param: "p", reason: "r"),
            .hardwareUnavailable(action: "a", reason: "r"),
            .timeout(action: "a", seconds: 5),
            .cancelled(action: "a"),
            .notSupported(action: "a", reason: "r"),
            .executionFailed(action: "a", underlyingError: NSError(domain: "t", code: 1)),
            .notRegistered(action: "a")
        ]
        for error in errors {
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true, "\(error.errorCode) should have non-empty description")
        }
    }

    func testAllErrorsHaveActionName() {
        let errors: [BridgeError] = [
            .permissionDenied(action: "camera", permission: "p"),
            .parameterInvalid(action: "scan", param: "p", reason: "r"),
            .hardwareUnavailable(action: "bt", reason: "r"),
            .timeout(action: "loc", seconds: 5),
            .cancelled(action: "sp"),
            .notSupported(action: "file", reason: "r"),
            .executionFailed(action: "media", underlyingError: NSError(domain: "t", code: 1)),
            .notRegistered(action: "unknown")
        ]
        let expectedActions = ["camera", "scan", "bt", "loc", "sp", "file", "media", "unknown"]
        for (error, expected) in zip(errors, expectedActions) {
            XCTAssertEqual(error.actionName, expected)
        }
    }

    // MARK: - Helpers

    private func makeMeta(
        action: String,
        category: HandlerCategory = .debug,
        displayName: String = "Test"
    ) -> HandlerMeta {
        HandlerMeta(
            action: action,
            category: category,
            displayName: displayName,
            description: "Unit test handler"
        )
    }
}
