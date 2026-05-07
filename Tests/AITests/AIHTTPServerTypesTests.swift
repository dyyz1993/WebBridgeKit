import XCTest
@testable import WebBridgeKit

final class AIHTTPServerTypesTests: XCTestCase {

    // MARK: - HTTPMethod

    func testHTTPMethodAllCasesExist() {
        let allCases: [HTTPMethod] = [.GET, .POST, .PUT, .DELETE, .OPTIONS, .PATCH]
        XCTAssertEqual(allCases.count, 6)
    }

    func testHTTPMethodRawValues() {
        XCTAssertEqual(HTTPMethod.GET.rawValue, "GET")
        XCTAssertEqual(HTTPMethod.POST.rawValue, "POST")
        XCTAssertEqual(HTTPMethod.PUT.rawValue, "PUT")
        XCTAssertEqual(HTTPMethod.DELETE.rawValue, "DELETE")
        XCTAssertEqual(HTTPMethod.OPTIONS.rawValue, "OPTIONS")
        XCTAssertEqual(HTTPMethod.PATCH.rawValue, "PATCH")
    }

    func testHTTPMethodFromRawValueValid() {
        XCTAssertEqual(HTTPMethod(rawValue: "GET"), .GET)
        XCTAssertEqual(HTTPMethod(rawValue: "POST"), .POST)
        XCTAssertEqual(HTTPMethod(rawValue: "PUT"), .PUT)
        XCTAssertEqual(HTTPMethod(rawValue: "DELETE"), .DELETE)
        XCTAssertEqual(HTTPMethod(rawValue: "OPTIONS"), .OPTIONS)
        XCTAssertEqual(HTTPMethod(rawValue: "PATCH"), .PATCH)
    }

    func testHTTPMethodFromRawValueInvalid() {
        XCTAssertNil(HTTPMethod(rawValue: "INVALID"))
        XCTAssertNil(HTTPMethod(rawValue: ""))
        XCTAssertNil(HTTPMethod(rawValue: "get"))
    }

    // MARK: - AIRequest

    func testAIRequestInit() {
        let request = AIRequest(method: .GET, path: "/api/test", headers: ["Host": "localhost"], body: ["key": "value"])
        XCTAssertEqual(request.method, .GET)
        XCTAssertEqual(request.path, "/api/test")
        XCTAssertEqual(request.headers["Host"], "localhost")
        XCTAssertEqual(request.body["key"] as? String, "value")
    }

    func testAIRequestInitEmpty() {
        let request = AIRequest(method: .GET, path: "/", headers: [:], body: [:])
        XCTAssertEqual(request.method, .GET)
        XCTAssertEqual(request.path, "/")
        XCTAssertTrue(request.headers.isEmpty)
        XCTAssertTrue(request.body.isEmpty)
    }

    func testAIRequestPathComponentsSimple() {
        let request = AIRequest(method: .GET, path: "/api/test", headers: [:], body: [:])
        XCTAssertEqual(request.pathComponents, ["api", "test"])
    }

    func testAIRequestPathComponentsRoot() {
        let request = AIRequest(method: .GET, path: "/", headers: [:], body: [:])
        XCTAssertTrue(request.pathComponents.isEmpty)
    }

    func testAIRequestPathComponentsTrailingSlash() {
        let request = AIRequest(method: .GET, path: "/api/test/", headers: [:], body: [:])
        XCTAssertEqual(request.pathComponents, ["api", "test"])
    }

    func testAIRequestPathComponentsNested() {
        let request = AIRequest(method: .GET, path: "/a/b/c/d", headers: [:], body: [:])
        XCTAssertEqual(request.pathComponents, ["a", "b", "c", "d"])
    }

    func testAIRequestPathComponentsSingleSegment() {
        let request = AIRequest(method: .GET, path: "/health", headers: [:], body: [:])
        XCTAssertEqual(request.pathComponents, ["health"])
    }

    func testAIRequestPathComponentsWithParameter() {
        let request = AIRequest(method: .GET, path: "/tools/:name", headers: [:], body: [:])
        XCTAssertEqual(request.pathComponents, ["tools", ":name"])
    }

    func testAIRequestPathComponentsWithMultipleParameters() {
        let request = AIRequest(method: .GET, path: "/api/:version/users/:id", headers: [:], body: [:])
        XCTAssertEqual(request.pathComponents, ["api", ":version", "users", ":id"])
    }

    func testAIRequestPathComponentsEmptyPath() {
        let request = AIRequest(method: .GET, path: "", headers: [:], body: [:])
        XCTAssertTrue(request.pathComponents.isEmpty)
    }

    func testAIRequestMultipleHeaders() {
        let request = AIRequest(method: .POST, path: "/api", headers: [
            "Content-Type": "application/json",
            "Authorization": "Bearer token",
            "Accept": "application/json"
        ], body: [:])
        XCTAssertEqual(request.headers.count, 3)
        XCTAssertEqual(request.headers["Content-Type"], "application/json")
        XCTAssertEqual(request.headers["Authorization"], "Bearer token")
    }

    // MARK: - AIResponse

    func testAIResponseDefaultInit() {
        let response = AIResponse()
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertTrue(response.body.isEmpty)
    }

    func testAIResponseCustomStatusCode() {
        let response = AIResponse(statusCode: 201, body: ["created": true])
        XCTAssertEqual(response.statusCode, 201)
        XCTAssertEqual(response.body["created"] as? Bool, true)
    }

    func testAIResponseInitWithEmptyBody() {
        let response = AIResponse(statusCode: 204, body: [:])
        XCTAssertEqual(response.statusCode, 204)
        XCTAssertTrue(response.body.isEmpty)
    }

    func testAIResponseOkWithBody() {
        let response = AIResponse.ok(["data": "test"])
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.body["data"] as? String, "test")
    }

    func testAIResponseOkEmptyBody() {
        let response = AIResponse.ok()
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertTrue(response.body.isEmpty)
    }

    func testAIResponseOkWithComplexBody() {
        let response = AIResponse.ok([
            "items": [1, 2, 3],
            "nested": ["key": "value"] as [String: Any],
            "flag": true
        ] as [String: Any])
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.body["flag"] as? Bool, true)
    }

    func testAIResponseErrorDefaultCode() {
        let response = AIResponse.error("bad request")
        XCTAssertEqual(response.statusCode, 400)
        XCTAssertEqual(response.body["error"] as? String, "bad request")
    }

    func testAIResponseErrorCustomCode() {
        let response = AIResponse.error("unauthorized", code: 401)
        XCTAssertEqual(response.statusCode, 401)
        XCTAssertEqual(response.body["error"] as? String, "unauthorized")
    }

    func testAIResponseErrorServerError() {
        let response = AIResponse.error("internal error", code: 500)
        XCTAssertEqual(response.statusCode, 500)
    }

    func testAIResponseNotFoundDefault() {
        let response = AIResponse.notFound()
        XCTAssertEqual(response.statusCode, 404)
        XCTAssertEqual(response.body["error"] as? String, "Not found")
    }

    func testAIResponseNotFoundCustomMessage() {
        let response = AIResponse.notFound("resource missing")
        XCTAssertEqual(response.statusCode, 404)
        XCTAssertEqual(response.body["error"] as? String, "resource missing")
    }

    // MARK: - AIError

    func testAIErrorServerStartFailedDescription() {
        let error = AIError.serverStartFailed(reason: "port in use")
        XCTAssertEqual(error.errorDescription, "Server start failed: port in use")
    }

    func testAIErrorServerStartFailedEmptyReason() {
        let error = AIError.serverStartFailed(reason: "")
        XCTAssertEqual(error.errorDescription, "Server start failed: ")
    }

    func testAIErrorRouteNotFoundDescription() {
        let error = AIError.routeNotFound(path: "/api/test")
        XCTAssertEqual(error.errorDescription, "Route not found: /api/test")
    }

    func testAIErrorRouteNotFoundEmptyPath() {
        let error = AIError.routeNotFound(path: "")
        XCTAssertEqual(error.errorDescription, "Route not found: ")
    }

    func testAIErrorInvalidRequestDescription() {
        let error = AIError.invalidRequest(reason: "missing body")
        XCTAssertEqual(error.errorDescription, "Invalid request: missing body")
    }

    func testAIErrorUnauthorizedDescription() {
        let error = AIError.unauthorized
        XCTAssertEqual(error.errorDescription, "Unauthorized - check API key")
    }

    func testAIErrorToolExecutionFailedDescription() {
        let error = AIError.toolExecutionFailed(tool: "test_tool", reason: "timeout")
        XCTAssertEqual(error.errorDescription, "Tool 'test_tool' execution failed: timeout")
    }

    func testAIErrorToolExecutionFailedEmptyFields() {
        let error = AIError.toolExecutionFailed(tool: "", reason: "")
        XCTAssertEqual(error.errorDescription, "Tool '' execution failed: ")
    }

    func testAIErrorConformsToLocalizedError() {
        let errors: [LocalizedError] = [
            AIError.serverStartFailed(reason: "test"),
            AIError.routeNotFound(path: "/test"),
            AIError.invalidRequest(reason: "test"),
            AIError.unauthorized,
            AIError.toolExecutionFailed(tool: "t", reason: "r")
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
        }
    }

    func testAIErrorConformsToError() {
        let errors: [Error] = [
            AIError.serverStartFailed(reason: "test"),
            AIError.routeNotFound(path: "/test"),
            AIError.invalidRequest(reason: "test"),
            AIError.unauthorized,
            AIError.toolExecutionFailed(tool: "t", reason: "r")
        ]
        for error in errors {
            XCTAssertNotNil(error as? LocalizedError)
        }
    }

    // MARK: - AIServerConfiguration

    func testAIServerConfigurationDefault() {
        let config = AIServerConfiguration.default
        XCTAssertEqual(config.maxConnections, 10)
        XCTAssertEqual(config.requestTimeout, 30)
        XCTAssertTrue(config.enableCORS)
        XCTAssertNil(config.apiKey)
    }

    func testAIServerConfigurationCustomAllParams() {
        let config = AIServerConfiguration(
            maxConnections: 5,
            requestTimeout: 60,
            enableCORS: false,
            apiKey: "test-key"
        )
        XCTAssertEqual(config.maxConnections, 5)
        XCTAssertEqual(config.requestTimeout, 60)
        XCTAssertFalse(config.enableCORS)
        XCTAssertEqual(config.apiKey, "test-key")
    }

    func testAIServerConfigurationWithApiKey() {
        let config = AIServerConfiguration(apiKey: "secret")
        XCTAssertNotNil(config.apiKey)
        XCTAssertEqual(config.apiKey, "secret")
        XCTAssertTrue(config.enableCORS)
        XCTAssertEqual(config.maxConnections, 10)
    }

    func testAIServerConfigurationZeroConnections() {
        let config = AIServerConfiguration(maxConnections: 0)
        XCTAssertEqual(config.maxConnections, 0)
    }

    func testAIServerConfigurationZeroTimeout() {
        let config = AIServerConfiguration(requestTimeout: 0)
        XCTAssertEqual(config.requestTimeout, 0)
    }

    // MARK: - AIServerEvent

    func testAIServerEventStarted() {
        let event: AIServerEvent = .started(port: 8765)
        if case .started(let port) = event {
            XCTAssertEqual(port, 8765)
        } else {
            XCTFail("Expected started event")
        }
    }

    func testAIServerEventStartedPortZero() {
        let event: AIServerEvent = .started(port: 0)
        if case .started(let port) = event {
            XCTAssertEqual(port, 0)
        } else {
            XCTFail("Expected started event")
        }
    }

    func testAIServerEventStopped() {
        let event: AIServerEvent = .stopped
        if case .stopped = event {
        } else {
            XCTFail("Expected stopped event")
        }
    }

    func testAIServerEventRequestReceived() {
        let event: AIServerEvent = .requestReceived(path: "/api/test")
        if case .requestReceived(let path) = event {
            XCTAssertEqual(path, "/api/test")
        } else {
            XCTFail("Expected requestReceived event")
        }
    }

    func testAIServerEventRequestReceivedEmptyPath() {
        let event: AIServerEvent = .requestReceived(path: "")
        if case .requestReceived(let path) = event {
            XCTAssertEqual(path, "")
        } else {
            XCTFail("Expected requestReceived event")
        }
    }

    func testAIServerEventError() {
        let testError = AIError.serverStartFailed(reason: "test")
        let event: AIServerEvent = .error(testError)
        if case .error(let err) = event {
            let aiError = try? XCTUnwrap(err as? AIError)
            XCTAssertEqual(aiError?.errorDescription, "Server start failed: test")
        } else {
            XCTFail("Expected error event")
        }
    }

    func testAIServerEventErrorWithDifferentTypes() {
        let errors: [AIServerEvent] = [
            .error(AIError.serverStartFailed(reason: "a")),
            .error(AIError.routeNotFound(path: "/b")),
            .error(AIError.invalidRequest(reason: "c")),
            .error(AIError.unauthorized),
            .error(AIError.toolExecutionFailed(tool: "d", reason: "e"))
        ]
        for event in errors {
            if case .error = event {
            } else {
                XCTFail("Expected error event")
            }
        }
    }

    // MARK: - AIHTTPServer Initialization

    func testDefaultPort() {
        XCTAssertEqual(AIHTTPServer.defaultPort, 8765)
    }

    func testServerInitDefaultPort() async {
        let server = AIHTTPServer()
        await server.stop()
    }

    func testServerInitCustomPort() async {
        let server = AIHTTPServer(port: 9999)
        await server.stop()
    }

    func testServerInitWithCustomConfiguration() async {
        let config = AIServerConfiguration(maxConnections: 5, apiKey: "test")
        let server = AIHTTPServer(port: 8080, configuration: config)
        await server.stop()
    }

    func testServerInitDefaultConfiguration() async {
        let server = AIHTTPServer(port: 12345, configuration: .default)
        await server.stop()
    }

    func testServerIsRunningInitiallyFalse() async {
        let server = AIHTTPServer(port: 0)
        let running = await server.isRunning
        XCTAssertFalse(running)
        await server.stop()
    }

    func testServerStopWhenNotRunning() async {
        let server = AIHTTPServer(port: 0)
        await server.stop()
        let running = await server.isRunning
        XCTAssertFalse(running)
    }
}
