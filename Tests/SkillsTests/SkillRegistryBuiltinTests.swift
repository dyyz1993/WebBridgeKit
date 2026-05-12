import XCTest
@testable import Skills

extension AgentSchemaTests {

    // MARK: - Builtin Skills

    func testBuiltinSkillsCount() async {
        XCTAssertEqual(BuiltinSkills.all.count, 7)
    }

    func testBuiltinSkillsContainExpectedCapabilities() {
        let names = Set(BuiltinSkills.all.map { $0.name })
        XCTAssertTrue(names.contains("Bridge"))
        XCTAssertTrue(names.contains("Cache"))
        XCTAssertTrue(names.contains("Message"))
    }

    func testBuiltinSkillsAllNames() {
        let names = Set(BuiltinSkills.all.map { $0.name })
        XCTAssertTrue(names.contains("Bridge"))
        XCTAssertTrue(names.contains("Cache"))
        XCTAssertTrue(names.contains("Message"))
        XCTAssertTrue(names.contains("AI Debug"))
        XCTAssertTrue(names.contains("Theme"))
        XCTAssertTrue(names.contains("CommandParser"))
        XCTAssertTrue(names.contains("Infrastructure"))
    }

    func testBuiltinBridgeCategory() {
        XCTAssertEqual(BuiltinSkills.bridge.category, "core")
    }

    func testBuiltinCacheCategory() {
        XCTAssertEqual(BuiltinSkills.cache.category, "core")
    }

    func testBuiltinMessageCategory() {
        XCTAssertEqual(BuiltinSkills.message.category, "core")
    }

    func testBuiltinAIDebugCategory() {
        XCTAssertEqual(BuiltinSkills.aiDebug.category, "debug")
    }

    func testBuiltinThemeCategory() {
        XCTAssertEqual(BuiltinSkills.theme.category, "ui")
    }

    func testBuiltinCommandParserCategory() {
        XCTAssertEqual(BuiltinSkills.commandParser.category, "core")
    }

    func testBuiltinInfrastructureCategory() {
        XCTAssertEqual(BuiltinSkills.infrastructure.category, "infrastructure")
    }

    func testBuiltinBridgeHasDebuggingMethods() {
        XCTAssertFalse(BuiltinSkills.bridge.debuggingMethods.isEmpty)
    }

    func testBuiltinCacheHasDebuggingMethods() {
        XCTAssertFalse(BuiltinSkills.cache.debuggingMethods.isEmpty)
    }

    func testBuiltinMessageHasDebuggingMethods() {
        XCTAssertFalse(BuiltinSkills.message.debuggingMethods.isEmpty)
    }

    func testBuiltinAIDebugHasDebuggingMethods() {
        XCTAssertFalse(BuiltinSkills.aiDebug.debuggingMethods.isEmpty)
    }

    func testBuiltinThemeHasDebuggingMethods() {
        XCTAssertFalse(BuiltinSkills.theme.debuggingMethods.isEmpty)
    }

    func testBuiltinCommandParserHasDebuggingMethods() {
        XCTAssertFalse(BuiltinSkills.commandParser.debuggingMethods.isEmpty)
    }

    func testBuiltinInfrastructureHasDebuggingMethods() {
        XCTAssertFalse(BuiltinSkills.infrastructure.debuggingMethods.isEmpty)
    }

    func testBuiltinAllHaveNonEmptyCommonIssues() {
        for skill in BuiltinSkills.all {
            XCTAssertFalse(skill.commonIssues.isEmpty, "\(skill.name) should have commonIssues")
        }
    }

    func testBuiltinAllHaveNonEmptyDescriptions() {
        for skill in BuiltinSkills.all {
            XCTAssertFalse(skill.description.isEmpty, "\(skill.name) should have a description")
        }
    }

    func testBuiltinBridgeHasEndpoints() {
        XCTAssertFalse(BuiltinSkills.bridge.apiEndpoints.isEmpty)
        XCTAssertEqual(BuiltinSkills.bridge.apiEndpoints.count, 3)
    }

    func testBuiltinCacheHasEndpoints() {
        XCTAssertEqual(BuiltinSkills.cache.apiEndpoints.count, 3)
    }

    func testBuiltinMessageHasEndpoints() {
        XCTAssertEqual(BuiltinSkills.message.apiEndpoints.count, 2)
    }

    func testBuiltinAIDebugHasEndpoints() {
        XCTAssertEqual(BuiltinSkills.aiDebug.apiEndpoints.count, 4)
    }

    func testBuiltinThemeHasNoEndpoints() {
        XCTAssertTrue(BuiltinSkills.theme.apiEndpoints.isEmpty)
    }

    func testBuiltinCommandParserHasNoEndpoints() {
        XCTAssertTrue(BuiltinSkills.commandParser.apiEndpoints.isEmpty)
    }

    func testBuiltinInfrastructureHasEndpoints() {
        XCTAssertEqual(BuiltinSkills.infrastructure.apiEndpoints.count, 2)
    }

    func testBuiltinBridgeHasTags() {
        XCTAssertTrue(BuiltinSkills.bridge.tags.contains("bridge"))
        XCTAssertTrue(BuiltinSkills.bridge.tags.contains("js-native"))
    }

    func testBuiltinCacheHasParameters() {
        XCTAssertFalse(BuiltinSkills.cache.parameters.isEmpty)
    }

    func testBuiltinMessageHasParameters() {
        XCTAssertFalse(BuiltinSkills.message.parameters.isEmpty)
        XCTAssertTrue(BuiltinSkills.message.parameters.contains { $0.required })
    }

    func testBuiltinMessageHasExamples() {
        XCTAssertFalse(BuiltinSkills.message.examples.isEmpty)
    }

    func testBuiltinAIDebugHasParameters() {
        XCTAssertFalse(BuiltinSkills.aiDebug.parameters.isEmpty)
    }

    func testBuiltinCommandParserHasSecurityTag() {
        XCTAssertTrue(BuiltinSkills.commandParser.tags.contains("security"))
    }

    func testBuiltinInfrastructureHasLoggingTag() {
        XCTAssertTrue(BuiltinSkills.infrastructure.tags.contains("logging"))
    }

    func testBuiltinRegisterAllWithRegistry() async throws {
        try await BuiltinSkills.registerAllWithRegistry()

        let all = await schema.getFullSchema()
        XCTAssertEqual(all.count, 7)

        let bridge = await schema.get("Bridge")
        XCTAssertNotNil(bridge)
    }

    func testBuiltinRegisterAllWithRegistryCategories() async throws {
        try await BuiltinSkills.registerAllWithRegistry()

        let categories = await schema.getCategories()
        XCTAssertTrue(categories.contains("core"))
        XCTAssertTrue(categories.contains("debug"))
        XCTAssertTrue(categories.contains("ui"))
        XCTAssertTrue(categories.contains("infrastructure"))
    }

    func testBuiltinBridgeCommonIssuesCount() {
        XCTAssertEqual(BuiltinSkills.bridge.commonIssues.count, 4)
    }

    func testBuiltinCacheCommonIssuesCount() {
        XCTAssertEqual(BuiltinSkills.cache.commonIssues.count, 4)
    }

    func testBuiltinMessageCommonIssuesCount() {
        XCTAssertEqual(BuiltinSkills.message.commonIssues.count, 4)
    }

    func testBuiltinAIDebugCommonIssuesCount() {
        XCTAssertEqual(BuiltinSkills.aiDebug.commonIssues.count, 3)
    }

    func testBuiltinThemeCommonIssuesCount() {
        XCTAssertEqual(BuiltinSkills.theme.commonIssues.count, 3)
    }

    func testBuiltinCommandParserCommonIssuesCount() {
        XCTAssertEqual(BuiltinSkills.commandParser.commonIssues.count, 3)
    }

    func testBuiltinInfrastructureCommonIssuesCount() {
        XCTAssertEqual(BuiltinSkills.infrastructure.commonIssues.count, 3)
    }
}
