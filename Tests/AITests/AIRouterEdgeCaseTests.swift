import XCTest
@testable import WebBridgeKit

final class AIRouterEdgeCaseTests: XCTestCase {

    private var router: AIRouter!

    override func setUp() {
        super.setUp()
        router = AIRouter()
    }

    override func tearDown() {
        router = nil
        super.tearDown()
    }

    // MARK: - Parameterized Route Edge Cases

    func testParameterizedRouteMultipleParams() async {
        await router.register(method: .GET, path: "/api/:version/users/:id") { _ in
            AIResponse.ok(["matched": true])
        }

        let request = AIRequest(method: .GET, path: "/api/v2/users/42", headers: [:], body: [:])
        let response = await router.route(request)
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.body["matched"] as? Bool, true)
    }

    func testParameterizedRouteAllParams() async {
        await router.register(method: .GET, path: "/:a/:b/:c") { _ in
            AIResponse.ok(["matched": true])
        }

        let request = AIRequest(method: .GET, path: "/x/y/z", headers: [:], body: [:])
        let response = await router.route(request)
        XCTAssertEqual(response.statusCode, 200)
    }

    func testParameterizedRouteSingleSegment() async {
        await router.register(method: .GET, path: "/:id") { _ in
            AIResponse.ok(["matched": true])
        }

        let request = AIRequest(method: .GET, path: "/42", headers: [:], body: [:])
        let response = await router.route(request)
        XCTAssertEqual(response.statusCode, 200)
    }

    func testParameterizedRouteStaticMismatch() async {
        await router.register(method: .GET, path: "/api/:id") { _ in
            AIResponse.ok()
        }

        let request = AIRequest(method: .GET, path: "/other/123", headers: [:], body: [:])
        let response = await router.route(request)
        XCTAssertEqual(response.statusCode, 404)
    }

    func testParameterizedRoutePartialStaticMismatch() async {
        await router.register(method: .GET, path: "/api/:id/items") { _ in
            AIResponse.ok()
        }

        let request = AIRequest(method: .GET, path: "/api/123/posts", headers: [:], body: [:])
        let response = await router.route(request)
        XCTAssertEqual(response.statusCode, 404)
    }

    func testParameterizedRouteExactMatchTakesPriority() async {
        await router.register(method: .GET, path: "/api/test") { _ in
            AIResponse.ok(["type": "exact"])
        }
        await router.register(method: .GET, path: "/api/:param") { _ in
            AIResponse.ok(["type": "param"])
        }

        let request = AIRequest(method: .GET, path: "/api/test", headers: [:], body: [:])
        let response = await router.route(request)
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.body["type"] as? String, "exact")
    }

    // MARK: - Route Registration Edge Cases

    func testRouteOverwrite() async {
        await router.register(method: .GET, path: "/test") { _ in
            AIResponse.ok(["v": 1])
        }
        await router.register(method: .GET, path: "/test") { _ in
            AIResponse.ok(["v": 2])
        }

        let request = AIRequest(method: .GET, path: "/test", headers: [:], body: [:])
        let response = await router.route(request)
        XCTAssertEqual(response.body["v"] as? Int, 2)
    }

    func testSamePathDifferentMethods() async {
        await router.register(method: .GET, path: "/resource") { _ in
            AIResponse.ok(["method": "GET"])
        }
        await router.register(method: .POST, path: "/resource") { _ in
            AIResponse(statusCode: 201, body: ["method": "POST"])
        }

        let getResponse = await router.route(AIRequest(method: .GET, path: "/resource", headers: [:], body: [:]))
        let postResponse = await router.route(AIRequest(method: .POST, path: "/resource", headers: [:], body: [:]))

        XCTAssertEqual(getResponse.statusCode, 200)
        XCTAssertEqual(getResponse.body["method"] as? String, "GET")
        XCTAssertEqual(postResponse.statusCode, 201)
        XCTAssertEqual(postResponse.body["method"] as? String, "POST")
    }

    func testMultipleRegistrationsSamePathLastWins() async {
        for i in 1...5 {
            await router.register(method: .GET, path: "/counter") { _ in
                AIResponse.ok(["value": i])
            }
        }

        let request = AIRequest(method: .GET, path: "/counter", headers: [:], body: [:])
        let response = await router.route(request)
        XCTAssertEqual(response.body["value"] as? Int, 5)
    }

    // MARK: - Different HTTP Methods

    func testPOSTRoute() async {
        await router.register(method: .POST, path: "/create") { _ in
            AIResponse(statusCode: 201, body: ["created": true])
        }

        let request = AIRequest(method: .POST, path: "/create", headers: [:], body: [:])
        let response = await router.route(request)
        XCTAssertEqual(response.statusCode, 201)
    }

    func testDELETERoute() async {
        await router.register(method: .DELETE, path: "/items/1") { _ in
            AIResponse(statusCode: 204, body: [:])
        }

        let request = AIRequest(method: .DELETE, path: "/items/1", headers: [:], body: [:])
        let response = await router.route(request)
        XCTAssertEqual(response.statusCode, 204)
    }

    func testPUTRoute() async {
        await router.register(method: .PUT, path: "/items/1") { _ in
            AIResponse.ok(["updated": true])
        }

        let request = AIRequest(method: .PUT, path: "/items/1", headers: [:], body: [:])
        let response = await router.route(request)
        XCTAssertEqual(response.statusCode, 200)
    }

    func testPATCHRoute() async {
        await router.register(method: .PATCH, path: "/items/1") { _ in
            AIResponse.ok(["patched": true])
        }

        let request = AIRequest(method: .PATCH, path: "/items/1", headers: [:], body: [:])
        let response = await router.route(request)
        XCTAssertEqual(response.statusCode, 200)
    }

    func testOPTIONSRoute() async {
        await router.register(method: .OPTIONS, path: "/api") { _ in
            AIResponse.ok()
        }

        let request = AIRequest(method: .OPTIONS, path: "/api", headers: [:], body: [:])
        let response = await router.route(request)
        XCTAssertEqual(response.statusCode, 200)
    }

    // MARK: - Route Not Found Messages

    func testRouteNotFoundContainsPath() async {
        let request = AIRequest(method: .GET, path: "/nonexistent", headers: [:], body: [:])
        let response = await router.route(request)
        XCTAssertEqual(response.statusCode, 404)
        let errorMsg = response.body["error"] as? String
        XCTAssertTrue(errorMsg?.contains("/nonexistent") ?? false)
    }

    func testRouteNotFoundContainsMethod() async {
        let request = AIRequest(method: .POST, path: "/missing", headers: [:], body: [:])
        let response = await router.route(request)
        XCTAssertEqual(response.statusCode, 404)
        let errorMsg = response.body["error"] as? String
        XCTAssertTrue(errorMsg?.contains("POST") ?? false)
    }

    func testRouteNotFoundForUnregisteredMethod() async {
        await router.register(method: .GET, path: "/api") { _ in AIResponse.ok() }
        let request = AIRequest(method: .DELETE, path: "/api", headers: [:], body: [:])
        let response = await router.route(request)
        XCTAssertEqual(response.statusCode, 404)
    }

    // MARK: - Tool Overwrite

    func testToolOverwrite() async {
        let tool1 = AITool(name: "tool", description: "First") { _ in return "v1" }
        let tool2 = AITool(name: "tool", description: "Second") { _ in return "v2" }

        await router.registerTool(tool1)
        await router.registerTool(tool2)

        let response = await router.executeTool(name: "tool", params: [:])
        XCTAssertEqual(response.statusCode, 200)
    }

    func testToolOverwriteUpdatesDescription() async {
        let tool1 = AITool(name: "tool", description: "First") { _ in return "v1" }
        let tool2 = AITool(name: "tool", description: "Second") { _ in return "v2" }

        await router.registerTool(tool1)
        await router.registerTool(tool2)

        let tools = await router.listTools()
        XCTAssertEqual(tools.count, 1)
        XCTAssertEqual(tools[0]["description"], "Second")
    }

    // MARK: - Tool Execution Edge Cases

    func testExecuteToolWithEmptyParams() async {
        let tool = AITool(name: "noparams", description: "No params") { _ in return "ok" }
        await router.registerTool(tool)

        let response = await router.executeTool(name: "noparams", params: [:])
        XCTAssertEqual(response.statusCode, 200)
    }

    func testExecuteToolReturnsResultInBody() async {
        let tool = AITool(name: "add", description: "Add") { params in
            let a = params["a"] as? Int ?? 0
            let b = params["b"] as? Int ?? 0
            return a + b
        }
        await router.registerTool(tool)

        let response = await router.executeTool(name: "add", params: ["a": 10, "b": 20])
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.body["result"] as? Int, 30)
    }

    func testExecuteToolReturnsComplexResult() async {
        let tool = AITool(name: "complex", description: "Complex") { _ in
            return ["nested": ["key": "value"], "count": 42] as [String: Any]
        }
        await router.registerTool(tool)

        let response = await router.executeTool(name: "complex", params: [:])
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertNotNil(response.body["result"])
    }

    func testExecuteToolReturnsStringResult() async {
        let tool = AITool(name: "stringer", description: "Returns string") { _ in return "hello" }
        await router.registerTool(tool)

        let response = await router.executeTool(name: "stringer", params: [:])
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.body["result"] as? String, "hello")
    }

    func testExecuteToolReturnsIntResult() async {
        let tool = AITool(name: "counter", description: "Returns int") { _ in return 42 }
        await router.registerTool(tool)

        let response = await router.executeTool(name: "counter", params: [:])
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.body["result"] as? Int, 42)
    }

    func testExecuteToolReturnsBoolResult() async {
        let tool = AITool(name: "checker", description: "Returns bool") { _ in return true }
        await router.registerTool(tool)

        let response = await router.executeTool(name: "checker", params: [:])
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.body["result"] as? Bool, true)
    }

    func testExecuteToolReturnsArrayResult() async {
        let tool = AITool(name: "lister", description: "Returns array") { _ in return [1, 2, 3] }
        await router.registerTool(tool)

        let response = await router.executeTool(name: "lister", params: [:])
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertNotNil(response.body["result"])
    }

    func testExecuteMultipleToolsIndependently() async {
        let tool1 = AITool(name: "t1", description: "Tool 1") { _ in return 1 }
        let tool2 = AITool(name: "t2", description: "Tool 2") { _ in return 2 }
        let tool3 = AITool(name: "t3", description: "Tool 3") { _ in return 3 }

        await router.registerTool(tool1)
        await router.registerTool(tool2)
        await router.registerTool(tool3)

        let tools = await router.listTools()
        XCTAssertEqual(tools.count, 3)

        let r1 = await router.executeTool(name: "t1", params: [:])
        let r2 = await router.executeTool(name: "t2", params: [:])
        let r3 = await router.executeTool(name: "t3", params: [:])

        XCTAssertEqual(r1.statusCode, 200)
        XCTAssertEqual(r2.statusCode, 200)
        XCTAssertEqual(r3.statusCode, 200)
    }

    func testExecuteToolWithNilParamValues() async {
        let tool = AITool(name: "optional", description: "Optional params") { params in
            return params["key"] ?? "default"
        }
        await router.registerTool(tool)

        let response = await router.executeTool(name: "optional", params: [:])
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.body["result"] as? String, "default")
    }

    // MARK: - MCP Edge Cases

    func testMCPToolsCallMissingToolName() async {
        let request = AIRequest(method: .POST, path: "/mcp", headers: [:], body: [
            "method": "tools/call",
            "params": [:] as [String: Any]
        ])
        let response = await router.handleMCP(request)
        XCTAssertNotEqual(response.statusCode, 200)
        XCTAssertNotNil(response.body["error"] as? String)
    }

    func testMCPToolsCallUnknownTool() async {
        let request = AIRequest(method: .POST, path: "/mcp", headers: [:], body: [
            "method": "tools/call",
            "params": ["name": "nonexistent", "arguments": [:]] as [String: Any]
        ])
        let response = await router.handleMCP(request)
        XCTAssertEqual(response.statusCode, 404)
    }

    func testMCPToolsCallToolThatThrows() async {
        let tool = AITool(name: "exploder", description: "Explodes") { _ in
            throw AIError.toolExecutionFailed(tool: "exploder", reason: "boom")
        }
        await router.registerTool(tool)

        let request = AIRequest(method: .POST, path: "/mcp", headers: [:], body: [
            "method": "tools/call",
            "params": ["name": "exploder", "arguments": [:]] as [String: Any]
        ])
        let response = await router.handleMCP(request)
        XCTAssertEqual(response.statusCode, 500)
    }

    func testMCPToolsCallWithNoArguments() async {
        let tool = AITool(name: "noargs", description: "No args tool") { _ in return "ok" }
        await router.registerTool(tool)

        let request = AIRequest(method: .POST, path: "/mcp", headers: [:], body: [
            "method": "tools/call",
            "params": ["name": "noargs"] as [String: Any]
        ])
        let response = await router.handleMCP(request)
        XCTAssertEqual(response.statusCode, 200)
    }

    func testMCPToolsCallWithArguments() async {
        let tool = AITool(name: "multiply", description: "Multiply") { params in
            let a = params["a"] as? Int ?? 0
            let b = params["b"] as? Int ?? 0
            return a * b
        }
        await router.registerTool(tool)

        let request = AIRequest(method: .POST, path: "/mcp", headers: [:], body: [
            "method": "tools/call",
            "params": ["name": "multiply", "arguments": ["a": 6, "b": 7]] as [String: Any]
        ])
        let response = await router.handleMCP(request)
        XCTAssertEqual(response.statusCode, 200)
    }

    func testMCPToolsListEmpty() async {
        let request = AIRequest(method: .POST, path: "/mcp", headers: [:], body: [
            "method": "tools/list"
        ])
        let response = await router.handleMCP(request)
        XCTAssertEqual(response.statusCode, 200)
        let tools = response.body["tools"] as? [[String: Any]]
        XCTAssertTrue(tools?.isEmpty ?? false)
    }

    func testMCPToolsListMultipleTools() async {
        let tool1 = AITool(name: "a", description: "Tool A") { _ in return "a" }
        let tool2 = AITool(name: "b", description: "Tool B") { _ in return "b" }
        await router.registerTool(tool1)
        await router.registerTool(tool2)

        let request = AIRequest(method: .POST, path: "/mcp", headers: [:], body: [
            "method": "tools/list"
        ])
        let response = await router.handleMCP(request)
        XCTAssertEqual(response.statusCode, 200)
        let tools = response.body["tools"] as? [[String: Any]]
        XCTAssertEqual(tools?.count, 2)
    }

    func testMCPInitializeResponseStructure() async {
        let request = AIRequest(method: .POST, path: "/mcp", headers: [:], body: [
            "method": "initialize"
        ])
        let response = await router.handleMCP(request)
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.body["protocolVersion"] as? String, "2024-11-05")

        let capabilities = response.body["capabilities"] as? [String: Any]
        XCTAssertNotNil(capabilities)

        let serverInfo = response.body["serverInfo"] as? [String: Any]
        XCTAssertEqual(serverInfo?["name"] as? String, "WebBridgeKit-AI")
        XCTAssertEqual(serverInfo?["version"] as? String, "1.0.0")
    }

    func testMCPToolsCallWithExtraParams() async {
        let tool = AITool(name: "flexible", description: "Flexible") { params in
            return params
        }
        await router.registerTool(tool)

        let request = AIRequest(method: .POST, path: "/mcp", headers: [:], body: [
            "method": "tools/call",
            "params": [
                "name": "flexible",
                "arguments": ["a": 1, "b": 2, "c": 3, "extra": true]
            ] as [String: Any]
        ])
        let response = await router.handleMCP(request)
        XCTAssertEqual(response.statusCode, 200)
    }

    func testMCPToolsCallToolReturningDict() async {
        let tool = AITool(name: "dict_tool", description: "Returns dict") { _ in
            return ["key": "value", "num": 42] as [String: Any]
        }
        await router.registerTool(tool)

        let request = AIRequest(method: .POST, path: "/mcp", headers: [:], body: [
            "method": "tools/call",
            "params": ["name": "dict_tool", "arguments": [:]] as [String: Any]
        ])
        let response = await router.handleMCP(request)
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertNotNil(response.body["result"])
    }

    func testMCPMissingMethodBody() async {
        let request = AIRequest(method: .POST, path: "/mcp", headers: [:], body: [
            "not_method": "tools/list"
        ])
        let response = await router.handleMCP(request)
        XCTAssertNotEqual(response.statusCode, 200)
    }

    func testMCPToolsCallEmptyParams() async {
        let request = AIRequest(method: .POST, path: "/mcp", headers: [:], body: [
            "method": "tools/call"
        ])
        let response = await router.handleMCP(request)
        XCTAssertNotEqual(response.statusCode, 200)
    }
}
