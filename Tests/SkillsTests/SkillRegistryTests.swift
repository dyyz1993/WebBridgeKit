import XCTest
@testable import Skills

final class AgentSchemaTests: XCTestCase {

    var schema: AgentSchema!

    override func setUp() async throws {
        try await super.setUp()
        schema = AgentSchema()
    }

    // MARK: - Registration

    func testBuiltinCapabilitiesLoaded() async {
        let capabilities = await schema.getFullSchema()
        XCTAssertFalse(capabilities.isEmpty)
    }

    func testRegisterCapability() async {
        let capability = AgentSchema.FrameworkCapability(
            name: "test",
            category: "test",
            description: "Test capability",
            debuggingMethods: ["method1"],
            commonIssues: [],
            apiEndpoints: []
        )
        await schema.register(capability)

        let retrieved = await schema.get("test")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.name, "test")
        XCTAssertEqual(retrieved?.category, "test")
    }

    func testUnregisterCapability() async {
        let capability = AgentSchema.FrameworkCapability(
            name: "remove_me",
            category: "test",
            description: "To be removed",
            debuggingMethods: [],
            commonIssues: [],
            apiEndpoints: []
        )
        await schema.register(capability)
        await schema.unregister("remove_me")

        let retrieved = await schema.get("remove_me")
        XCTAssertNil(retrieved)
    }

    // MARK: - Query by Category

    func testGetCapabilitiesByCategory() async {
        let cap1 = AgentSchema.FrameworkCapability(
            name: "cap_a",
            category: "core",
            description: "Core A",
            debuggingMethods: [],
            commonIssues: [],
            apiEndpoints: []
        )
        let cap2 = AgentSchema.FrameworkCapability(
            name: "cap_b",
            category: "debug",
            description: "Debug B",
            debuggingMethods: [],
            commonIssues: [],
            apiEndpoints: []
        )

        await schema.register(cap1)
        await schema.register(cap2)

        let coreCaps = await schema.getCapabilities(category: "core")
        XCTAssertTrue(coreCaps.contains { $0.name == "cap_a" })
        XCTAssertFalse(coreCaps.contains { $0.name == "cap_b" })
    }

    // MARK: - Troubleshooting

    func testGetTroubleshootingGuide() async {
        let capability = AgentSchema.FrameworkCapability(
            name: "troubleshoot_test",
            category: "test",
            description: "Test",
            debuggingMethods: [],
            commonIssues: [
                AgentSchema.IssueSolution(
                    symptom: "JS 调用不响应",
                    cause: "Handler 未注册",
                    solution: "检查 list_handlers"
                ),
                AgentSchema.IssueSolution(
                    symptom: "缓存命中率低",
                    cause: "容量过小",
                    solution: "调整配置"
                )
            ],
            apiEndpoints: []
        )
        await schema.register(capability)

        let results = await schema.getTroubleshootingGuide(issue: "不响应")
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.any { $0.symptom.contains("不响应") })
    }

    // MARK: - API Guide

    func testGetAPIGuide() async {
        let guide = await schema.getAPIGuide()
        XCTAssertFalse(guide.isEmpty)

        let healthEndpoint = guide.first { $0.path == "/health" }
        XCTAssertNotNil(healthEndpoint)
        XCTAssertEqual(healthEndpoint?.method, "GET")
    }

    // MARK: - Builtin Skills

    func testBuiltinSkillsCount() async {
        XCTAssertEqual(BuiltinSkills.all.count, 3)
    }

    func testBuiltinSkillsContainExpectedCapabilities() {
        let names = Set(BuiltinSkills.all.map { $0.name })
        XCTAssertTrue(names.contains("Bridge"))
        XCTAssertTrue(names.contains("Cache"))
        XCTAssertTrue(names.contains("Message"))
    }

    // MARK: - Codable Conformance

    func testFrameworkCapabilityCodable() throws {
        let capability = AgentSchema.FrameworkCapability(
            name: "codable_test",
            category: "test",
            description: "Codable test",
            debuggingMethods: ["method1", "method2"],
            commonIssues: [
                AgentSchema.IssueSolution(symptom: "s1", cause: "c1", solution: "sol1")
            ],
            apiEndpoints: [
                AgentSchema.APIEndpoint(method: "GET", path: "/test", description: "Test endpoint", parameters: ["key": "value"])
            ]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(capability)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AgentSchema.FrameworkCapability.self, from: data)

        XCTAssertEqual(decoded.name, "codable_test")
        XCTAssertEqual(decoded.debuggingMethods.count, 2)
        XCTAssertEqual(decoded.commonIssues.count, 1)
        XCTAssertEqual(decoded.apiEndpoints.count, 1)
    }
}

private extension Array {
    func any(_ predicate: (Element) throws -> Bool) -> Bool {
        (try? contains(where: predicate)) ?? false
    }
}
