import XCTest
@testable import WebBridgeKit

extension BuiltinAIToolsTests {

    // MARK: - Tool Metadata: Read-write Tools

    func testExecuteHandlerMetadata() {
        let tool = BuiltinAITools.executeHandler
        XCTAssertEqual(tool.name, "execute_handler")
        XCTAssertEqual(tool.category, "action")
        XCTAssertFalse(tool.description.isEmpty)
        XCTAssertEqual(tool.parameters.count, 2)
        let nameParam = tool.parameters.first { $0.name == "name" }
        XCTAssertTrue(nameParam?.required ?? false)
        let paramsParam = tool.parameters.first { $0.name == "params" }
        XCTAssertNotNil(paramsParam)
        XCTAssertFalse(paramsParam?.required ?? true)
    }

    func testClearCacheMetadata() {
        let tool = BuiltinAITools.clearCache
        XCTAssertEqual(tool.name, "clear_cache")
        XCTAssertEqual(tool.category, "action")
        XCTAssertFalse(tool.description.isEmpty)
        XCTAssertEqual(tool.parameters.count, 1)
        XCTAssertEqual(tool.parameters[0].name, "prefix")
        XCTAssertFalse(tool.parameters[0].required)
    }

    func testSendTestPushMetadata() {
        let tool = BuiltinAITools.sendTestPush
        XCTAssertEqual(tool.name, "send_test_push")
        XCTAssertEqual(tool.category, "action")
        XCTAssertFalse(tool.description.isEmpty)
        XCTAssertEqual(tool.parameters.count, 4)
        let titleParam = tool.parameters.first { $0.name == "title" }
        let bodyParam = tool.parameters.first { $0.name == "body" }
        XCTAssertTrue(titleParam?.required ?? false)
        XCTAssertTrue(bodyParam?.required ?? false)
        let groupParam = tool.parameters.first { $0.name == "group" }
        XCTAssertFalse(groupParam?.required ?? true)
        let urlParam = tool.parameters.first { $0.name == "url" }
        XCTAssertFalse(urlParam?.required ?? true)
    }

    func testReloadConfigMetadata() {
        let tool = BuiltinAITools.reloadConfig
        XCTAssertEqual(tool.name, "reload_config")
        XCTAssertEqual(tool.category, "action")
        XCTAssertFalse(tool.description.isEmpty)
        XCTAssertEqual(tool.parameters.count, 1)
        XCTAssertTrue(tool.parameters[0].required)
        XCTAssertEqual(tool.parameters[0].name, "type")
    }

    // MARK: - execute_handler Execution

    func testExecuteHandlerMissingNameThrows() async {
        do {
            _ = try await BuiltinAITools.executeHandler.execute(params: [:])
            XCTFail("Should have thrown for missing handler name")
        } catch {
            XCTAssertTrue(error is AIError)
        }
    }

    func testExecuteHandlerNonExistent() async throws {
        let result = try await BuiltinAITools.executeHandler.execute(params: ["name": "nonexistent_xyz"])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(dict["success"] as? Bool, false)
        XCTAssertNotNil(dict["error"] as? String)
        XCTAssertNotNil(dict["availableHandlers"])
    }

    func testExecuteHandlerWithParams() async throws {
        let result = try await BuiltinAITools.executeHandler.execute(params: [
            "name": "getSystemInfo",
            "params": ["detail": true] as [String: Any]
        ])
        let dict = result as? [String: Any]
        XCTAssertNotNil(dict)
    }

    func testExecuteHandlerWithoutParams() async throws {
        let result = try await BuiltinAITools.executeHandler.execute(params: ["name": "vibrate"])
        let dict = result as? [String: Any]
        XCTAssertNotNil(dict)
    }

    func testExecuteHandlerAvailableHandlersIsArray() async throws {
        let result = try await BuiltinAITools.executeHandler.execute(params: ["name": "nonexistent"])
        let dict = try XCTUnwrap(result as? [String: Any])
        let available = dict["availableHandlers"] as? [String]
        XCTAssertNotNil(available)
    }

    // MARK: - clear_cache Execution

    func testClearCacheAll() async throws {
        let result = try await BuiltinAITools.clearCache.execute(params: [:])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(dict["success"] as? Bool, true)
        XCTAssertEqual(dict["action"] as? String, "clearAll")
        XCTAssertNotNil(dict["previousStats"])
    }

    func testClearCacheWithPrefix() async throws {
        let result = try await BuiltinAITools.clearCache.execute(params: ["prefix": "test_prefix"])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(dict["success"] as? Bool, true)
        XCTAssertEqual(dict["action"] as? String, "partial")
        XCTAssertEqual(dict["clearedKey"] as? String, "test_prefix")
    }

    func testClearCacheWithEmptyPrefixClearsAll() async throws {
        let result = try await BuiltinAITools.clearCache.execute(params: ["prefix": ""])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(dict["success"] as? Bool, true)
        XCTAssertEqual(dict["action"] as? String, "clearAll")
    }

    func testClearCachePreviousStatsStructure() async throws {
        let result = try await BuiltinAITools.clearCache.execute(params: [:])
        let dict = try XCTUnwrap(result as? [String: Any])
        let stats = try XCTUnwrap(dict["previousStats"] as? [String: Any])
        XCTAssertNotNil(stats["totalRequests"])
        XCTAssertNotNil(stats["entries"])
        XCTAssertNotNil(stats["size"])
    }

    // MARK: - send_test_push Execution

    func testSendTestPushMissingTitleThrows() async {
        do {
            _ = try await BuiltinAITools.sendTestPush.execute(params: ["body": "test"])
            XCTFail("Should have thrown for missing title")
        } catch {
            XCTAssertTrue(error is AIError)
        }
    }

    func testSendTestPushMissingBodyThrows() async {
        do {
            _ = try await BuiltinAITools.sendTestPush.execute(params: ["title": "test"])
            XCTFail("Should have thrown for missing body")
        } catch {
            XCTAssertTrue(error is AIError)
        }
    }

    func testSendTestPushMissingBothThrows() async {
        do {
            _ = try await BuiltinAITools.sendTestPush.execute(params: [:])
            XCTFail("Should have thrown for missing title and body")
        } catch {
            XCTAssertTrue(error is AIError)
        }
    }

    func testSendTestPushNoBarkChannel() async throws {
        let result = try await BuiltinAITools.sendTestPush.execute(params: [
            "title": "Test Title",
            "body": "Test Body"
        ])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(dict["success"] as? Bool, false)
        XCTAssertNotNil(dict["error"] as? String)
        XCTAssertNotNil(dict["availableChannels"])
    }

    func testSendTestPushWithOptionalParams() async throws {
        let result = try await BuiltinAITools.sendTestPush.execute(params: [
            "title": "Title",
            "body": "Body",
            "group": "test_group",
            "url": "https://example.com"
        ])
        let dict = result as? [String: Any]
        XCTAssertNotNil(dict)
    }

    // MARK: - reload_config Execution

    func testReloadConfigLogging() async throws {
        let result = try await BuiltinAITools.reloadConfig.execute(params: ["type": "logging"])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(dict["success"] as? Bool, true)
        let reloaded = try XCTUnwrap(dict["reloaded"] as? [String])
        XCTAssertTrue(reloaded.contains("logging (buffer cleared)"))
        XCTAssertNotNil(dict["newState"])
    }

    func testReloadConfigLoggingNewState() async throws {
        let result = try await BuiltinAITools.reloadConfig.execute(params: ["type": "logging"])
        let dict = try XCTUnwrap(result as? [String: Any])
        let newState = try XCTUnwrap(dict["newState"] as? [String: Any])
        XCTAssertNotNil(newState["bufferEntries"])
        XCTAssertNotNil(newState["minLevel"])
        XCTAssertNotNil(newState["sessionId"])
    }

    func testReloadConfigCacheStats() async throws {
        let result = try await BuiltinAITools.reloadConfig.execute(params: ["type": "cache_stats"])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(dict["success"] as? Bool, true)
        let reloaded = try XCTUnwrap(dict["reloaded"] as? [String])
        XCTAssertTrue(reloaded.contains("cache_stats"))
    }

    func testReloadConfigCacheStatsNewState() async throws {
        let result = try await BuiltinAITools.reloadConfig.execute(params: ["type": "cache_stats"])
        let dict = try XCTUnwrap(result as? [String: Any])
        let newState = try XCTUnwrap(dict["newState"] as? [String: Any])
        XCTAssertNotNil(newState["totalRequests"])
        XCTAssertNotNil(newState["hitRate"])
        XCTAssertNotNil(newState["entries"])
    }

    func testReloadConfigAll() async throws {
        let result = try await BuiltinAITools.reloadConfig.execute(params: ["type": "all"])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(dict["success"] as? Bool, true)
        let reloaded = try XCTUnwrap(dict["reloaded"] as? [String])
        XCTAssertTrue(reloaded.contains("logging"))
        XCTAssertTrue(reloaded.contains("cache_stats"))
    }

    func testReloadConfigAllNewState() async throws {
        let result = try await BuiltinAITools.reloadConfig.execute(params: ["type": "all"])
        let dict = try XCTUnwrap(result as? [String: Any])
        let newState = try XCTUnwrap(dict["newState"] as? [String: Any])
        XCTAssertNotNil(newState["logging"])
        XCTAssertNotNil(newState["cache"])
    }

    func testReloadConfigUnknownType() async throws {
        let result = try await BuiltinAITools.reloadConfig.execute(params: ["type": "unknown_type_xyz"])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(dict["success"] as? Bool, false)
        XCTAssertNotNil(dict["error"] as? String)
    }

    func testReloadConfigMissingTypeThrows() async {
        do {
            _ = try await BuiltinAITools.reloadConfig.execute(params: [:])
            XCTFail("Should have thrown for missing type")
        } catch {
            XCTAssertTrue(error is AIError)
        }
    }

    func testReloadConfigCaseInsensitive() async throws {
        let result = try await BuiltinAITools.reloadConfig.execute(params: ["type": "LOGGING"])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(dict["success"] as? Bool, true)
    }

    func testReloadConfigMixedCase() async throws {
        let result = try await BuiltinAITools.reloadConfig.execute(params: ["type": "Cache_Stats"])
        let dict = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(dict["success"] as? Bool, true)
    }

    // MARK: - MCP Tool Definitions for All Builtin Tools

    func testAllToolsHaveMCPDefinitions() {
        for tool in BuiltinAITools.all {
            let def = tool.toMCPToolDefinition()
            XCTAssertEqual(def["name"] as? String, tool.name, "Tool \(tool.name) MCP name mismatch")
            XCTAssertEqual(def["description"] as? String, tool.description, "Tool \(tool.name) MCP description mismatch")
            let schema = def["inputSchema"] as? [String: Any]
            XCTAssertNotNil(schema, "Tool \(tool.name) should have inputSchema")
            XCTAssertEqual(schema?["type"] as? String, "object", "Tool \(tool.name) inputSchema type should be object")
        }
    }

    func testAllToolsMCPDefinitionsIncludeRequiredParams() {
        for tool in BuiltinAITools.all {
            let def = tool.toMCPToolDefinition()
            let schema = def["inputSchema"] as? [String: Any]
            let required = schema?["required"] as? [String] ?? []
            let expectedRequired = tool.parameters.filter { $0.required }.map { $0.name }
            XCTAssertEqual(required.sorted(), expectedRequired.sorted(), "Tool \(tool.name) required params mismatch")
        }
    }

    func testAllToolsMCPDefinitionsIncludeAllProperties() {
        for tool in BuiltinAITools.all {
            let def = tool.toMCPToolDefinition()
            let schema = def["inputSchema"] as? [String: Any]
            let properties = schema?["properties"] as? [String: Any]
            XCTAssertNotNil(properties, "Tool \(tool.name) should have properties in inputSchema")
            for param in tool.parameters {
                let prop = properties?[param.name] as? [String: Any]
                XCTAssertNotNil(prop, "Tool \(tool.name) should have property for \(param.name)")
                XCTAssertEqual(prop?["type"] as? String, param.type, "Tool \(tool.name) param \(param.name) type mismatch")
                XCTAssertEqual(prop?["description"] as? String, param.description, "Tool \(tool.name) param \(param.name) description mismatch")
            }
        }
    }

    func testToolWithNoParamsHasEmptyProperties() {
        let tool = AITool(name: "noparams", description: "No params", parameters: []) { _ in return "ok" }
        let def = tool.toMCPToolDefinition()
        let schema = def["inputSchema"] as? [String: Any]
        let properties = schema?["properties"] as? [String: Any]
        XCTAssertTrue(properties?.isEmpty ?? false)
        XCTAssertNil(schema?["required"])
    }

    func testToolWithOnlyOptionalParamsHasNoRequired() {
        let tool = AITool(
            name: "optional_only",
            description: "All optional",
            parameters: [
                AIParameter(name: "a", type: "string", description: "Optional A"),
                AIParameter(name: "b", type: "integer", description: "Optional B")
            ]
        ) { _ in return "ok" }
        let def = tool.toMCPToolDefinition()
        let schema = def["inputSchema"] as? [String: Any]
        XCTAssertNil(schema?["required"])
    }
}
