import XCTest
@testable import Skills

extension AgentSchemaTests {

    // MARK: - Data Models

    func testParameterInit() {
        let param = Parameter(name: "timeout", type: "Int", required: false, description: "Request timeout")
        XCTAssertEqual(param.name, "timeout")
        XCTAssertEqual(param.type, "Int")
        XCTAssertEqual(param.required, false)
        XCTAssertEqual(param.description, "Request timeout")
    }

    func testParameterRequired() {
        let param = Parameter(name: "id", type: "String", required: true, description: "User ID")
        XCTAssertTrue(param.required)
    }

    func testIssueSolutionInit() {
        let issue = IssueSolution(symptom: "Crash", cause: "Null pointer", solution: "Add nil check")
        XCTAssertEqual(issue.symptom, "Crash")
        XCTAssertEqual(issue.cause, "Null pointer")
        XCTAssertEqual(issue.solution, "Add nil check")
    }

    func testAPIEndpointInitWithParams() {
        let endpoint = APIEndpoint(method: "POST", path: "/users", description: "Create user", parameters: ["name": "required"])
        XCTAssertEqual(endpoint.method, "POST")
        XCTAssertEqual(endpoint.path, "/users")
        XCTAssertEqual(endpoint.description, "Create user")
        XCTAssertEqual(endpoint.parameters["name"], "required")
    }

    func testAPIEndpointInitDefaultParams() {
        let endpoint = APIEndpoint(method: "GET", path: "/ping", description: "Health check")
        XCTAssertTrue(endpoint.parameters.isEmpty)
    }

    func testFrameworkCapabilityMinimalInit() {
        let cap = FrameworkCapability(
            name: "minimal",
            category: "cat",
            description: "desc",
            debuggingMethods: [],
            commonIssues: []
        )
        XCTAssertEqual(cap.name, "minimal")
        XCTAssertEqual(cap.apiEndpoints.isEmpty, true)
        XCTAssertEqual(cap.parameters.isEmpty, true)
        XCTAssertEqual(cap.tags.isEmpty, true)
        XCTAssertEqual(cap.examples.isEmpty, true)
    }

    func testFrameworkCapabilityFullInit() {
        let cap = FrameworkCapability(
            name: "full",
            category: "cat",
            description: "desc",
            debuggingMethods: ["d"],
            commonIssues: [IssueSolution(symptom: "s", cause: "c", solution: "x")],
            apiEndpoints: [APIEndpoint(method: "GET", path: "/", description: "d")],
            parameters: [Parameter(name: "p", type: "T", required: true, description: "d")],
            tags: ["t"],
            examples: ["e"]
        )
        XCTAssertEqual(cap.name, "full")
        XCTAssertEqual(cap.debuggingMethods.count, 1)
        XCTAssertEqual(cap.commonIssues.count, 1)
        XCTAssertEqual(cap.apiEndpoints.count, 1)
        XCTAssertEqual(cap.parameters.count, 1)
        XCTAssertEqual(cap.tags.count, 1)
        XCTAssertEqual(cap.examples.count, 1)
    }

    // MARK: - Codable Round-Trip

    func testParameterCodableRoundTrip() throws {
        let param = Parameter(name: "key", type: "String", required: true, description: "API key")
        let data = try JSONEncoder().encode(param)
        let decoded = try JSONDecoder().decode(Parameter.self, from: data)
        XCTAssertEqual(decoded.name, param.name)
        XCTAssertEqual(decoded.type, param.type)
        XCTAssertEqual(decoded.required, param.required)
        XCTAssertEqual(decoded.description, param.description)
    }

    func testIssueSolutionCodableRoundTrip() throws {
        let issue = IssueSolution(symptom: "Memory leak", cause: "Retain cycle", solution: "Use [weak self]")
        let data = try JSONEncoder().encode(issue)
        let decoded = try JSONDecoder().decode(IssueSolution.self, from: data)
        XCTAssertEqual(decoded.symptom, issue.symptom)
        XCTAssertEqual(decoded.cause, issue.cause)
        XCTAssertEqual(decoded.solution, issue.solution)
    }

    func testAPIEndpointCodableRoundTrip() throws {
        let endpoint = APIEndpoint(method: "PUT", path: "/users/:id", description: "Update user", parameters: ["id": "required"])
        let data = try JSONEncoder().encode(endpoint)
        let decoded = try JSONDecoder().decode(APIEndpoint.self, from: data)
        XCTAssertEqual(decoded.method, endpoint.method)
        XCTAssertEqual(decoded.path, endpoint.path)
        XCTAssertEqual(decoded.description, endpoint.description)
        XCTAssertEqual(decoded.parameters, endpoint.parameters)
    }

    func testAPIEndpointCodableRoundTripEmptyParams() throws {
        let endpoint = APIEndpoint(method: "DELETE", path: "/users/:id", description: "Delete user")
        let data = try JSONEncoder().encode(endpoint)
        let decoded = try JSONDecoder().decode(APIEndpoint.self, from: data)
        XCTAssertTrue(decoded.parameters.isEmpty)
    }

    func testFrameworkCapabilityCodable() throws {
        let capability = FrameworkCapability(
            name: "codable_test",
            category: "test",
            description: "Codable test",
            debuggingMethods: ["method1", "method2"],
            commonIssues: [
                IssueSolution(symptom: "s1", cause: "c1", solution: "sol1")
            ],
            apiEndpoints: [
                APIEndpoint(method: "GET", path: "/test", description: "Test endpoint", parameters: ["key": "value"])
            ]
        )

        let data = try JSONEncoder().encode(capability)
        let decoded = try JSONDecoder().decode(FrameworkCapability.self, from: data)

        XCTAssertEqual(decoded.name, "codable_test")
        XCTAssertEqual(decoded.debuggingMethods.count, 2)
        XCTAssertEqual(decoded.commonIssues.count, 1)
        XCTAssertEqual(decoded.apiEndpoints.count, 1)
    }

    func testFrameworkCapabilityFullCodableRoundTrip() throws {
        let capability = FrameworkCapability(
            name: "full_codable",
            category: "cat",
            description: "desc",
            debuggingMethods: ["d1"],
            commonIssues: [IssueSolution(symptom: "s", cause: "c", solution: "x")],
            apiEndpoints: [APIEndpoint(method: "POST", path: "/api", description: "api", parameters: ["k": "v"])],
            parameters: [Parameter(name: "p", type: "Int", required: false, description: "pd")],
            tags: ["t1", "t2"],
            examples: ["ex1", "ex2"]
        )

        let data = try JSONEncoder().encode(capability)
        let decoded = try JSONDecoder().decode(FrameworkCapability.self, from: data)

        XCTAssertEqual(decoded.name, "full_codable")
        XCTAssertEqual(decoded.category, "cat")
        XCTAssertEqual(decoded.description, "desc")
        XCTAssertEqual(decoded.debuggingMethods, ["d1"])
        XCTAssertEqual(decoded.commonIssues.count, 1)
        XCTAssertEqual(decoded.apiEndpoints.count, 1)
        XCTAssertEqual(decoded.parameters.count, 1)
        XCTAssertEqual(decoded.tags, ["t1", "t2"])
        XCTAssertEqual(decoded.examples, ["ex1", "ex2"])
    }

    func testFrameworkCapabilityMinimalCodableRoundTrip() throws {
        let capability = FrameworkCapability(
            name: "min_codable",
            category: "cat",
            description: "desc",
            debuggingMethods: [],
            commonIssues: []
        )

        let data = try JSONEncoder().encode(capability)
        let decoded = try JSONDecoder().decode(FrameworkCapability.self, from: data)

        XCTAssertEqual(decoded.name, "min_codable")
        XCTAssertTrue(decoded.apiEndpoints.isEmpty)
        XCTAssertTrue(decoded.parameters.isEmpty)
        XCTAssertTrue(decoded.tags.isEmpty)
        XCTAssertTrue(decoded.examples.isEmpty)
    }
}
