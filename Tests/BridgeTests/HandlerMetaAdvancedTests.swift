import XCTest
@testable import WebBridgeKit

final class HandlerMetaAdvancedTests: XCTestCase {

    func testHandlerMetaCodableRoundTrip() throws {
        let meta = HandlerMeta(
            action: "codableTest",
            category: .media,
            displayName: "Codable Test",
            description: "Test Codable encoding/decoding",
            requiredPermissions: ["camera", "microphone"],
            parameters: [
                ParamDef(name: "mode", type: .string, required: true, defaultValue: "photo", description: "Mode", options: ["photo", "video"]),
                ParamDef(name: "count", type: .int, required: false, description: "Count")
            ],
            returns: [
                ReturnDef(name: "data", type: .string, description: "Result data"),
                ReturnDef(name: "success", type: .bool, description: "Success flag")
            ],
            requiresNetwork: true,
            requiresHardware: true,
            minimumiOSVersion: "16.0"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(meta)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(HandlerMeta.self, from: data)

        XCTAssertEqual(decoded.action, meta.action)
        XCTAssertEqual(decoded.category, meta.category)
        XCTAssertEqual(decoded.displayName, meta.displayName)
        XCTAssertEqual(decoded.description, meta.description)
        XCTAssertEqual(decoded.requiredPermissions, meta.requiredPermissions)
        XCTAssertEqual(decoded.parameters, meta.parameters)
        XCTAssertEqual(decoded.returns, meta.returns)
        XCTAssertEqual(decoded.requiresNetwork, meta.requiresNetwork)
        XCTAssertEqual(decoded.requiresHardware, meta.requiresHardware)
        XCTAssertEqual(decoded.minimumiOSVersion, meta.minimumiOSVersion)
    }

    func testHandlerMetaMinimalCodableRoundTrip() throws {
        let meta = HandlerMeta(
            action: "minimal",
            category: .debug,
            displayName: "Minimal",
            description: "Minimal handler"
        )

        let data = try JSONEncoder().encode(meta)
        let decoded = try JSONDecoder().decode(HandlerMeta.self, from: data)

        XCTAssertEqual(decoded.action, "minimal")
        XCTAssertEqual(decoded.category, .debug)
        XCTAssertEqual(decoded.requiredPermissions, [])
        XCTAssertEqual(decoded.parameters, [])
        XCTAssertEqual(decoded.returns, [])
        XCTAssertFalse(decoded.requiresNetwork)
        XCTAssertFalse(decoded.requiresHardware)
        XCTAssertNil(decoded.minimumiOSVersion)
    }

    func testParamDefCodableRoundTrip() throws {
        let param = ParamDef(
            name: "quality",
            type: .string,
            required: true,
            defaultValue: "high",
            description: "Quality level",
            options: ["high", "medium", "low"]
        )

        let data = try JSONEncoder().encode(param)
        let decoded = try JSONDecoder().decode(ParamDef.self, from: data)

        XCTAssertEqual(decoded, param)
    }

    func testParamDefMinimalCodableRoundTrip() throws {
        let param = ParamDef(name: "flag", type: .bool, description: "A flag")

        let data = try JSONEncoder().encode(param)
        let decoded = try JSONDecoder().decode(ParamDef.self, from: data)

        XCTAssertEqual(decoded, param)
        XCTAssertFalse(decoded.required)
        XCTAssertNil(decoded.defaultValue)
        XCTAssertNil(decoded.options)
    }

    func testReturnDefCodableRoundTrip() throws {
        let ret = ReturnDef(name: "result", type: .array, description: "Result array")

        let data = try JSONEncoder().encode(ret)
        let decoded = try JSONDecoder().decode(ReturnDef.self, from: data)

        XCTAssertEqual(decoded, ret)
    }

    func testParamTypeCodableRoundTrip() throws {
        let allTypes: [ParamType] = [.string, .int, .double, .bool, .array, .object]

        for type in allTypes {
            let data = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(ParamType.self, from: data)
            XCTAssertEqual(decoded, type)
        }
    }

    func testHandlerMetaJsonDictIncludesParametersWithCorrectStructure() {
        let params = [
            ParamDef(name: "url", type: .string, required: true, description: "Target URL"),
            ParamDef(name: "timeout", type: .int, required: false, defaultValue: "30", description: "Timeout seconds", options: ["10", "30", "60"])
        ]
        let meta = HandlerMeta(
            action: "jsonParamTest",
            category: .navigation,
            displayName: "Param Test",
            description: "Test parameter JSON structure",
            parameters: params
        )

        let dict = meta.jsonDict
        guard let paramList = dict["parameters"] as? [[String: Any]] else {
            XCTFail("parameters should be a dictionary array")
            return
        }

        XCTAssertEqual(paramList.count, 2)

        let urlParam = paramList[0]
        XCTAssertEqual(urlParam["name"] as? String, "url")
        XCTAssertEqual(urlParam["type"] as? String, "string")
        XCTAssertEqual(urlParam["required"] as? Bool, true)
        XCTAssertEqual(urlParam["description"] as? String, "Target URL")

        let timeoutParam = paramList[1]
        XCTAssertEqual(timeoutParam["default"] as? String, "30")
        XCTAssertEqual(timeoutParam["options"] as? [String], ["10", "30", "60"])
    }

    func testHandlerMetaJsonDictIncludesReturnsWithCorrectStructure() {
        let returns = [
            ReturnDef(name: "status", type: .bool, description: "Operation status"),
            ReturnDef(name: "data", type: .object, description: "Result data")
        ]
        let meta = HandlerMeta(
            action: "jsonReturnTest",
            category: .system,
            displayName: "Return Test",
            description: "Test return JSON structure",
            returns: returns
        )

        let dict = meta.jsonDict
        guard let returnList = dict["returns"] as? [[String: Any]] else {
            XCTFail("returns should be a dictionary array")
            return
        }

        XCTAssertEqual(returnList.count, 2)
        XCTAssertEqual(returnList[0]["name"] as? String, "status")
        XCTAssertEqual(returnList[0]["type"] as? String, "bool")
        XCTAssertEqual(returnList[1]["name"] as? String, "data")
        XCTAssertEqual(returnList[1]["type"] as? String, "object")
    }

    func testHandlerMetaJsonDictIncludesRequiredPermissions() {
        let meta = HandlerMeta(
            action: "permTest",
            category: .hardware,
            displayName: "Perm Test",
            description: "Test",
            requiredPermissions: ["camera", "location", "microphone"]
        )

        let dict = meta.jsonDict
        guard let perms = dict["requiredPermissions"] as? [String] else {
            XCTFail("requiredPermissions should be present")
            return
        }

        XCTAssertEqual(perms, ["camera", "location", "microphone"])
    }

    func testParamDefEquality() {
        let p1 = ParamDef(name: "x", type: .string, required: true, defaultValue: "a", description: "desc", options: ["a", "b"])
        let p2 = ParamDef(name: "x", type: .string, required: true, defaultValue: "a", description: "desc", options: ["a", "b"])
        let p3 = ParamDef(name: "x", type: .string, required: false, defaultValue: "a", description: "desc", options: ["a", "b"])

        XCTAssertEqual(p1, p2)
        XCTAssertNotEqual(p1, p3)
    }

    func testReturnDefEquality() {
        let r1 = ReturnDef(name: "data", type: .array, description: "data")
        let r2 = ReturnDef(name: "data", type: .array, description: "data")
        let r3 = ReturnDef(name: "data", type: .string, description: "data")

        XCTAssertEqual(r1, r2)
        XCTAssertNotEqual(r1, r3)
    }
}
