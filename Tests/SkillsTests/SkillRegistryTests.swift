import XCTest
@testable import Skills

final class AgentSchemaTests: XCTestCase {

    var schema: AgentSchema!

    override func setUp() async throws {
        try await super.setUp()
        await SkillRegistry.shared.clearAll()
        schema = AgentSchema()
    }

    override func tearDown() async throws {
        await SkillRegistry.shared.clearAll()
        try await super.tearDown()
    }

    func makeCapability(
        name: String = "test",
        category: String = "test",
        description: String = "Test capability",
        debuggingMethods: [String] = ["method1"],
        commonIssues: [IssueSolution] = [],
        apiEndpoints: [APIEndpoint] = [],
        parameters: [Parameter] = [],
        tags: [String] = [],
        examples: [String] = []
    ) -> FrameworkCapability {
        FrameworkCapability(
            name: name,
            category: category,
            description: description,
            debuggingMethods: debuggingMethods,
            commonIssues: commonIssues,
            apiEndpoints: apiEndpoints,
            parameters: parameters,
            tags: tags,
            examples: examples
        )
    }

    // MARK: - Registration

    func testBuiltinCapabilitiesLoaded() async {
        try? await BuiltinSkills.registerAllWithRegistry()
        let capabilities = await schema.getFullSchema()
        XCTAssertFalse(capabilities.isEmpty)
    }

    func testRegisterCapability() async {
        let capability = makeCapability(name: "test")
        await schema.register(capability)

        let retrieved = await schema.get("test")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.name, "test")
        XCTAssertEqual(retrieved?.category, "test")
    }

    func testRegisterCapabilityPreservesAllFields() async {
        let issue = IssueSolution(symptom: "sym", cause: "cause", solution: "sol")
        let endpoint = APIEndpoint(method: "POST", path: "/api/test", description: "desc", parameters: ["k": "v"])
        let param = Parameter(name: "p", type: "String", required: true, description: "pd")

        let capability = FrameworkCapability(
            name: "full_test",
            category: "cat",
            description: "desc",
            debuggingMethods: ["d1", "d2"],
            commonIssues: [issue],
            apiEndpoints: [endpoint],
            parameters: [param],
            tags: ["t1", "t2"],
            examples: ["ex1"]
        )
        await schema.register(capability)

        let retrieved = await schema.get("full_test")
        XCTAssertEqual(retrieved?.name, "full_test")
        XCTAssertEqual(retrieved?.category, "cat")
        XCTAssertEqual(retrieved?.description, "desc")
        XCTAssertEqual(retrieved?.debuggingMethods, ["d1", "d2"])
        XCTAssertEqual(retrieved?.commonIssues.count, 1)
        XCTAssertEqual(retrieved?.commonIssues.first?.symptom, "sym")
        XCTAssertEqual(retrieved?.apiEndpoints.count, 1)
        XCTAssertEqual(retrieved?.apiEndpoints.first?.method, "POST")
        XCTAssertEqual(retrieved?.parameters.count, 1)
        XCTAssertEqual(retrieved?.parameters.first?.name, "p")
        XCTAssertEqual(retrieved?.tags, ["t1", "t2"])
        XCTAssertEqual(retrieved?.examples, ["ex1"])
    }

    func testRegisterDuplicateThrows() async {
        let capability = makeCapability(name: "dup_test")
        await schema.register(capability)

        let capability2 = makeCapability(name: "dup_test", description: "different")
        await schema.register(capability2)

        let retrieved = await schema.get("dup_test")
        XCTAssertEqual(retrieved?.description, "Test capability")
    }

    func testRegisterDuplicateViaRegistryThrows() async throws {
        let capability = makeCapability(name: "reg_dup")
        try await SkillRegistry.shared.register(capability)

        do {
            try await SkillRegistry.shared.register(capability)
            XCTFail("Should have thrown duplicateSkill")
        } catch let error as SkillError {
            if case .duplicateSkill(let name) = error {
                XCTAssertEqual(name, "reg_dup")
            } else {
                XCTFail("Expected duplicateSkill error")
            }
            XCTAssertEqual(error.errorDescription, "Skill 'reg_dup' is already registered")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testRegisterAllSuccess() async throws {
        let cap1 = makeCapability(name: "all_1", category: "cat1")
        let cap2 = makeCapability(name: "all_2", category: "cat2")
        let cap3 = makeCapability(name: "all_3", category: "cat3")

        try await SkillRegistry.shared.registerAll([cap1, cap2, cap3])

        let count = await SkillRegistry.shared.count()
        XCTAssertEqual(count, 3)
        let g1 = await SkillRegistry.shared.get("all_1")
        XCTAssertNotNil(g1)
        let g2 = await SkillRegistry.shared.get("all_2")
        XCTAssertNotNil(g2)
        let g3 = await SkillRegistry.shared.get("all_3")
        XCTAssertNotNil(g3)
    }

    func testRegisterAllEmptyArray() async throws {
        try await SkillRegistry.shared.registerAll([])
        let count = await SkillRegistry.shared.count()
        XCTAssertEqual(count, 0)
    }

    func testRegisterAllPartialFailure() async {
        let cap1 = makeCapability(name: "partial_1")
        let cap2 = makeCapability(name: "partial_1", description: "dup")
        let cap3 = makeCapability(name: "partial_2")

        do {
            try await SkillRegistry.shared.registerAll([cap1, cap2, cap3])
            XCTFail("Should have thrown on duplicate")
        } catch let error as SkillError {
            if case .duplicateSkill(let name) = error {
                XCTAssertEqual(name, "partial_1")
            } else {
                XCTFail("Expected duplicateSkill error")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }

        let count = await SkillRegistry.shared.count()
        XCTAssertEqual(count, 1)
        let retrieved = await SkillRegistry.shared.get("partial_1")
        XCTAssertNotNil(retrieved)
    }

    func testUnregisterCapability() async {
        let capability = makeCapability(name: "remove_me")
        await schema.register(capability)
        await schema.unregister("remove_me")

        let retrieved = await schema.get("remove_me")
        XCTAssertNil(retrieved)
    }

    func testUnregisterNonExistentReturnsNil() async {
        let registryResult = await SkillRegistry.shared.unregister("nonexistent")
        XCTAssertNil(registryResult)
        await schema.unregister("nonexistent")
    }

    func testUnregisterCleansCategoryIndex() async {
        let cap = makeCapability(name: "cat_clean", category: "unique_cat")
        await schema.register(cap)

        let beforeCount = await schema.getCapabilities(category: "unique_cat")
        XCTAssertEqual(beforeCount.count, 1)
        await schema.unregister("cat_clean")

        let remaining = await schema.getCapabilities(category: "unique_cat")
        XCTAssertTrue(remaining.isEmpty)
    }

    func testUnregisterCleansTagIndex() async {
        let cap = makeCapability(name: "tag_clean", tags: ["unique_tag"])
        await schema.register(cap)

        let beforeCount = await schema.getByTag("unique_tag")
        XCTAssertEqual(beforeCount.count, 1)
        await schema.unregister("tag_clean")

        let remaining = await schema.getByTag("unique_tag")
        XCTAssertTrue(remaining.isEmpty)
    }

    func testUnregisterMultipleSkillsSameCategory() async {
        let cap1 = makeCapability(name: "multi_1", category: "shared_cat")
        let cap2 = makeCapability(name: "multi_2", category: "shared_cat")
        await schema.register(cap1)
        await schema.register(cap2)

        let beforeCount = await schema.getCapabilities(category: "shared_cat")
        XCTAssertEqual(beforeCount.count, 2)
        await schema.unregister("multi_1")

        let remaining = await schema.getCapabilities(category: "shared_cat")
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.name, "multi_2")
    }

    func testUnregisterReturnsSkill() async {
        let cap = makeCapability(name: "return_test", description: "will return")
        await schema.register(cap)

        let returned = await SkillRegistry.shared.unregister("return_test")
        XCTAssertNotNil(returned)
        XCTAssertEqual(returned?.name, "return_test")
        XCTAssertEqual(returned?.description, "will return")
    }

    func testClearAll() async {
        let cap1 = makeCapability(name: "clear_1", category: "a", tags: ["t1"])
        let cap2 = makeCapability(name: "clear_2", category: "b", tags: ["t2"])
        await schema.register(cap1)
        await schema.register(cap2)

        await SkillRegistry.shared.clearAll()

        let count = await SkillRegistry.shared.count()
        XCTAssertEqual(count, 0)
        let all = await SkillRegistry.shared.getAll()
        XCTAssertTrue(all.isEmpty)
        let cats = await SkillRegistry.shared.getCategories()
        XCTAssertTrue(cats.isEmpty)
        let tags = await SkillRegistry.shared.getTags()
        XCTAssertTrue(tags.isEmpty)
    }

    // MARK: - SkillError

    func testSkillErrorDuplicateSkillDescription() {
        let error = SkillError.duplicateSkill("my_skill")
        XCTAssertEqual(error.errorDescription, "Skill 'my_skill' is already registered")
    }

    func testSkillErrorSkillNotFoundDescription() {
        let error = SkillError.skillNotFound("missing")
        XCTAssertEqual(error.errorDescription, "Skill 'missing' not found")
    }

    func testSkillErrorInvalidRegistrationDescription() {
        let error = SkillError.invalidRegistration
        XCTAssertEqual(error.errorDescription, "Invalid skill registration")
    }

    func testSkillErrorLocalizedErrorConformance() {
        let errors: [SkillError] = [
            .duplicateSkill("a"),
            .skillNotFound("b"),
            .invalidRegistration
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
        }
    }
}
