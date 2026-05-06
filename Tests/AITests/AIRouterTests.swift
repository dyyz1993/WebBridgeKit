//
//  AIRouterTests.swift
//  AITests
//

import XCTest
@testable import WebBridgeKit

final class AIRouterTests: XCTestCase {

    private var router: AIRouter!

    override func setUp() {
        super.setUp()
        router = AIRouter()
    }

    override func tearDown() {
        router = nil
        super.tearDown()
    }

    // MARK: - Route Registration & Matching

    func testExactRouteMatch() async {
        await router.register(method: .GET, path: "/api/test") { _ in
            AIResponse.ok(["matched": true])
        }

        let request = AIRequest(method: .GET, path: "/api/test", headers: [:], body: [:])
        let response = await router.route(request)
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.body["matched"] as? Bool, true)
    }

    func testExactRouteNoMatch() async {
        await router.register(method: .GET, path: "/api/test") { _ in
            AIResponse.ok(["matched": true])
        }

        let request = AIRequest(method: .GET, path: "/api/other", headers: [:], body: [:])
        let response = await router.route(request)
        XCTAssertEqual(response.statusCode, 404)
    }

    func testMethodMismatchReturns404() async {
        await router.register(method: .GET, path: "/api/test") { _ in
            AIResponse.ok()
        }

        let request = AIRequest(method: .POST, path: "/api/test", headers: [:], body: [:])
        let response = await router.route(request)
        XCTAssertEqual(response.statusCode, 404)
    }

    func testParameterizedRouteMatch() async {
        await router.register(method: .GET, path: "/api/users/:id") { _ in
            AIResponse.ok(["user": true])
        }

        let request = AIRequest(method: .GET, path: "/api/users/123", headers: [:], body: [:])
        let response = await router.route(request)
        XCTAssertEqual(response.statusCode, 200)
    }

    func testParameterizedRouteNoMatchDifferentLength() async {
        await router.register(method: .GET, path: "/api/users/:id") { _ in
            AIResponse.ok()
        }

        let request = AIRequest(method: .GET, path: "/api/users/123/posts", headers: [:], body: [:])
        let response = await router.route(request)
        XCTAssertEqual(response.statusCode, 404)
    }

    func testNoRoutesRegisteredReturns404() async {
        let request = AIRequest(method: .GET, path: "/anything", headers: [:], body: [:])
        let response = await router.route(request)
        XCTAssertEqual(response.statusCode, 404)
    }

    func testMultipleRoutesRegistered() async {
        await router.register(method: .GET, path: "/a") { _ in AIResponse.ok(["route": "a"]) }
        await router.register(method: .GET, path: "/b") { _ in AIResponse.ok(["route": "b"]) }

        let responseA = await router.route(AIRequest(method: .GET, path: "/a", headers: [:], body: [:]))
        let responseB = await router.route(AIRequest(method: .GET, path: "/b", headers: [:], body: [:]))

        XCTAssertEqual(responseA.body["route"] as? String, "a")
        XCTAssertEqual(responseB.body["route"] as? String, "b")
    }

    // MARK: - Tool Registration & Execution

    func testRegisterAndExecuteTool() async {
        let tool = AITool(name: "echo", description: "Echo tool", parameters: []) { params in
            return params["message"] ?? "nil"
        }
        await router.registerTool(tool)

        let response = await router.executeTool(name: "echo", params: ["message": "hello"])
        XCTAssertEqual(response.statusCode, 200)
    }

    func testExecuteUnknownToolReturns404() async {
        let response = await router.executeTool(name: "unknown", params: [:])
        XCTAssertEqual(response.statusCode, 404)
    }

    func testToolExecutionFailureReturns500() async {
        let tool = AITool(name: "fail", description: "Always fails") { _ in
            throw AIError.toolExecutionFailed(tool: "fail", reason: "broken")
        }
        await router.registerTool(tool)

        let response = await router.executeTool(name: "fail", params: [:])
        XCTAssertEqual(response.statusCode, 500)
    }

    func testListTools() async {
        let tool = AITool(name: "tool1", description: "First tool", category: "test") { _ in return "ok" }
        await router.registerTool(tool)

        let tools = await router.listTools()
        XCTAssertEqual(tools.count, 1)
        XCTAssertEqual(tools[0]["name"], "tool1")
        XCTAssertEqual(tools[0]["category"], "test")
    }

    func testListToolsEmpty() async {
        let tools = await router.listTools()
        XCTAssertTrue(tools.isEmpty)
    }

    // MARK: - MCP Protocol

    func testMCPInitialize() async {
        let request = AIRequest(method: .POST, path: "/mcp", headers: [:], body: [
            "method": "initialize"
        ])
        let response = await router.handleMCP(request)
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.body["protocolVersion"] as? String, "2024-11-05")
    }

    func testMCPToolsList() async {
        let tool = AITool(name: "test", description: "Test tool") { _ in return "ok" }
        await router.registerTool(tool)

        let request = AIRequest(method: .POST, path: "/mcp", headers: [:], body: [
            "method": "tools/list"
        ])
        let response = await router.handleMCP(request)
        XCTAssertEqual(response.statusCode, 200)

        let tools = response.body["tools"] as? [[String: Any]]
        XCTAssertEqual(tools?.count, 1)
    }

    func testMCPToolsCall() async {
        let tool = AITool(name: "add", description: "Add numbers") { params in
            let a = params["a"] as? Int ?? 0
            let b = params["b"] as? Int ?? 0
            return a + b
        }
        await router.registerTool(tool)

        let request = AIRequest(method: .POST, path: "/mcp", headers: [:], body: [
            "method": "tools/call",
            "params": ["name": "add", "arguments": ["a": 3, "b": 4]] as [String: Any]
        ])
        let response = await router.handleMCP(request)
        XCTAssertEqual(response.statusCode, 200)
    }

    func testMCPMissingMethod() async {
        let request = AIRequest(method: .POST, path: "/mcp", headers: [:], body: [:])
        let response = await router.handleMCP(request)
        XCTAssertNotEqual(response.statusCode, 200)
    }

    func testMCPUnknownMethod() async {
        let request = AIRequest(method: .POST, path: "/mcp", headers: [:], body: [
            "method": "unknown/method"
        ])
        let response = await router.handleMCP(request)
        XCTAssertNotEqual(response.statusCode, 200)
    }

    // MARK: - AITool

    func testAIToolToMCPToolDefinition() {
        let tool = AITool(
            name: "search",
            description: "Search things",
            parameters: [
                AIParameter(name: "query", type: "string", description: "Search query", required: true),
                AIParameter(name: "limit", type: "integer", description: "Max results")
            ]
        ) { _ in return "ok" }

        let def = tool.toMCPToolDefinition()
        XCTAssertEqual(def["name"] as? String, "search")
        XCTAssertEqual(def["description"] as? String, "Search things")

        let schema = def["inputSchema"] as? [String: Any]
        XCTAssertNotNil(schema)
        XCTAssertEqual(schema?["type"] as? String, "object")

        let required = schema?["required"] as? [String]
        XCTAssertEqual(required, ["query"])
    }

    func testAIParameterInit() {
        let param = AIParameter(name: "test", type: "number", description: "A param", required: true, defaultValue: "0")
        XCTAssertEqual(param.name, "test")
        XCTAssertEqual(param.type, "number")
        XCTAssertTrue(param.required)
        XCTAssertEqual(param.defaultValue, "0")
    }

    // MARK: - AIResponse

    func testAIResponseOk() {
        let response = AIResponse.ok(["key": "value"])
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.body["key"] as? String, "value")
    }

    func testAIResponseError() {
        let response = AIResponse.error("bad request", code: 400)
        XCTAssertEqual(response.statusCode, 400)
        XCTAssertEqual(response.body["error"] as? String, "bad request")
    }

    func testAIResponseNotFound() {
        let response = AIResponse.notFound("missing")
        XCTAssertEqual(response.statusCode, 404)
        XCTAssertEqual(response.body["error"] as? String, "missing")
    }

    func testAIResponseDefaultInit() {
        let response = AIResponse()
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertTrue(response.body.isEmpty)
    }
}
