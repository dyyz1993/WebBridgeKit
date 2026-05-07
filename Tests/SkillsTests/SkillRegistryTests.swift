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

    // MARK: - Helper

    private func makeCapability(
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

    // MARK: - Query by Category

    func testGetCapabilitiesByCategory() async {
        let cap1 = makeCapability(name: "cap_a", category: "core")
        let cap2 = makeCapability(name: "cap_b", category: "debug")

        await schema.register(cap1)
        await schema.register(cap2)

        let coreCaps = await schema.getCapabilities(category: "core")
        XCTAssertTrue(coreCaps.contains { $0.name == "cap_a" })
        XCTAssertFalse(coreCaps.contains { $0.name == "cap_b" })
    }

    func testGetCapabilitiesByNonExistentCategory() async {
        let result = await schema.getCapabilities(category: "nonexistent")
        XCTAssertTrue(result.isEmpty)
    }

    func testGetCapabilitiesMultipleInSameCategory() async {
        let cap1 = makeCapability(name: "same_a", category: "same_cat")
        let cap2 = makeCapability(name: "same_b", category: "same_cat")
        let cap3 = makeCapability(name: "same_c", category: "same_cat")

        await schema.register(cap1)
        await schema.register(cap2)
        await schema.register(cap3)

        let result = await schema.getCapabilities(category: "same_cat")
        XCTAssertEqual(result.count, 3)
    }

    // MARK: - Query by Tag

    func testGetByTag() async {
        let cap = makeCapability(name: "tagged", tags: ["search", "index"])
        await schema.register(cap)

        let results = await schema.getByTag("search")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "tagged")
    }

    func testGetByTagNonExistent() async {
        let results = await schema.getByTag("nonexistent_tag")
        XCTAssertTrue(results.isEmpty)
    }

    func testGetByTagMultipleSkills() async {
        let cap1 = makeCapability(name: "tag_a", tags: ["shared_tag"])
        let cap2 = makeCapability(name: "tag_b", tags: ["shared_tag", "other"])
        await schema.register(cap1)
        await schema.register(cap2)

        let results = await schema.getByTag("shared_tag")
        XCTAssertEqual(results.count, 2)
    }

    func testGetByTagViaRegistry() async throws {
        let cap = makeCapability(name: "reg_tag", tags: ["registry_tag"])
        try await SkillRegistry.shared.register(cap)

        let results = await SkillRegistry.shared.getByTag("registry_tag")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "reg_tag")
    }

    // MARK: - Get

    func testGetFound() async {
        let cap = makeCapability(name: "find_me")
        await schema.register(cap)

        let result = await schema.get("find_me")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "find_me")
    }

    func testGetNotFound() async {
        let result = await schema.get("ghost")
        XCTAssertNil(result)
    }

    func testGetViaRegistry() async throws {
        let cap = makeCapability(name: "reg_get")
        try await SkillRegistry.shared.register(cap)

        let result = await SkillRegistry.shared.get("reg_get")
        XCTAssertNotNil(result)
    }

    // MARK: - GetAll

    func testGetAllSortedByName() async throws {
        let capC = makeCapability(name: "charlie")
        let capA = makeCapability(name: "alpha")
        let capB = makeCapability(name: "bravo")

        try await SkillRegistry.shared.registerAll([capC, capA, capB])

        let all = await SkillRegistry.shared.getAll()
        XCTAssertEqual(all.count, 3)
        XCTAssertEqual(all[0].name, "alpha")
        XCTAssertEqual(all[1].name, "bravo")
        XCTAssertEqual(all[2].name, "charlie")
    }

    func testGetAllEmpty() async {
        let all = await SkillRegistry.shared.getAll()
        XCTAssertTrue(all.isEmpty)
    }

    // MARK: - Search

    func testSearchByName() async {
        let cap = makeCapability(name: "SearchableSkill", description: "Some description")
        await schema.register(cap)

        let results = await schema.search("Searchable")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "SearchableSkill")
    }

    func testSearchByDescription() async {
        let cap = makeCapability(name: "foo", description: "缓存命中率低")
        await schema.register(cap)

        let results = await schema.search("缓存命中率")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "foo")
    }

    func testSearchCaseInsensitive() async {
        let cap = makeCapability(name: "UPPER_CASE", description: "desc")
        await schema.register(cap)

        let results = await schema.search("upper_case")
        XCTAssertEqual(results.count, 1)
    }

    func testSearchNoMatch() async {
        let cap = makeCapability(name: "something", description: "else")
        await schema.register(cap)

        let results = await schema.search("zzz_nonexistent")
        XCTAssertTrue(results.isEmpty)
    }

    func testSearchEmptyQuery() async {
        let cap = makeCapability(name: "test", description: "test desc")
        await schema.register(cap)

        let results = await schema.search("")
        XCTAssertTrue(results.isEmpty)
    }

    func testSearchViaRegistry() async throws {
        let cap = makeCapability(name: "RegSearch", description: "findable")
        try await SkillRegistry.shared.register(cap)

        let results = await SkillRegistry.shared.search("RegSearch")
        XCTAssertEqual(results.count, 1)
    }

    func testSearchMatchesBothNameAndDescription() async {
        let cap1 = makeCapability(name: "MatchName", description: "other text")
        let cap2 = makeCapability(name: "OtherName", description: "match text")
        await schema.register(cap1)
        await schema.register(cap2)

        let results = await schema.search("match")
        XCTAssertEqual(results.count, 2)
    }

    // MARK: - Count

    func testCountAfterRegister() async {
        let c0 = await SkillRegistry.shared.count()
        XCTAssertEqual(c0, 0)

        await schema.register(makeCapability(name: "c1"))
        let c1 = await SkillRegistry.shared.count()
        XCTAssertEqual(c1, 1)

        await schema.register(makeCapability(name: "c2"))
        let c2 = await SkillRegistry.shared.count()
        XCTAssertEqual(c2, 2)
    }

    func testCountAfterUnregister() async {
        await schema.register(makeCapability(name: "c1"))
        await schema.register(makeCapability(name: "c2"))
        let c = await SkillRegistry.shared.count()
        XCTAssertEqual(c, 2)

        await schema.unregister("c1")
        let c1 = await SkillRegistry.shared.count()
        XCTAssertEqual(c1, 1)
    }

    func testCountAfterClear() async {
        await schema.register(makeCapability(name: "c1"))
        await schema.register(makeCapability(name: "c2"))

        await SkillRegistry.shared.clearAll()
        let c = await SkillRegistry.shared.count()
        XCTAssertEqual(c, 0)
    }

    // MARK: - Categories

    func testGetCategories() async {
        let cap1 = makeCapability(name: "cat_a", category: "alpha")
        let cap2 = makeCapability(name: "cat_b", category: "beta")
        let cap3 = makeCapability(name: "cat_c", category: "alpha")
        await schema.register(cap1)
        await schema.register(cap2)
        await schema.register(cap3)

        let categories = await schema.getCategories()
        XCTAssertEqual(categories, ["alpha", "beta"])
    }

    func testGetCategoriesEmpty() async {
        let categories = await schema.getCategories()
        XCTAssertTrue(categories.isEmpty)
    }

    // MARK: - Tags

    func testGetTags() async {
        let cap1 = makeCapability(name: "t1", tags: ["swift", "ios"])
        let cap2 = makeCapability(name: "t2", tags: ["android", "ios"])
        await schema.register(cap1)
        await schema.register(cap2)

        let tags = await schema.getTags()
        XCTAssertEqual(tags, ["android", "ios", "swift"])
    }

    func testGetTagsEmpty() async {
        let tags = await schema.getTags()
        XCTAssertTrue(tags.isEmpty)
    }

    // MARK: - Troubleshooting

    func testGetTroubleshootingGuide() async {
        let capability = makeCapability(
            name: "troubleshoot_test",
            commonIssues: [
                IssueSolution(symptom: "JS 调用不响应", cause: "Handler 未注册", solution: "检查 list_handlers"),
                IssueSolution(symptom: "缓存命中率低", cause: "容量过小", solution: "调整配置")
            ]
        )
        await schema.register(capability)

        let results = await schema.getTroubleshootingGuide(issue: "不响应")
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.any { $0.symptom.contains("不响应") })
    }

    func testGetTroubleshootingGuideByCause() async {
        let capability = makeCapability(
            name: "cause_test",
            commonIssues: [
                IssueSolution(symptom: "symptom", cause: "端口被占用", solution: "重启")
            ]
        )
        await schema.register(capability)

        let results = await schema.getTroubleshootingGuide(issue: "端口")
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.any { $0.cause.contains("端口") })
    }

    func testGetTroubleshootingGuideCaseInsensitive() async {
        let capability = makeCapability(
            name: "case_test",
            commonIssues: [
                IssueSolution(symptom: "Port Busy", cause: "Port in use", solution: "restart")
            ]
        )
        await schema.register(capability)

        let results = await schema.getTroubleshootingGuide(issue: "port busy")
        XCTAssertFalse(results.isEmpty)
    }

    func testGetTroubleshootingGuideNoMatch() async {
        let capability = makeCapability(
            name: "no_match_test",
            commonIssues: [
                IssueSolution(symptom: "symptom1", cause: "cause1", solution: "sol1")
            ]
        )
        await schema.register(capability)

        let results = await schema.getTroubleshootingGuide(issue: "zzz_no_match")
        XCTAssertTrue(results.isEmpty)
    }

    func testGetTroubleshootingGuideAcrossMultipleCapabilities() async {
        let cap1 = makeCapability(
            name: "trouble_a",
            commonIssues: [IssueSolution(symptom: "Error A", cause: "Root A", solution: "Fix A")]
        )
        let cap2 = makeCapability(
            name: "trouble_b",
            commonIssues: [IssueSolution(symptom: "Error B", cause: "Root A", solution: "Fix B")]
        )
        await schema.register(cap1)
        await schema.register(cap2)

        let results = await schema.getTroubleshootingGuide(issue: "Root A")
        XCTAssertEqual(results.count, 2)
    }

    // MARK: - API Guide

    func testGetAPIGuide() async {
        let guide = await schema.getAPIGuide()
        XCTAssertFalse(guide.isEmpty)

        let healthEndpoint = guide.first { $0.path == "/health" }
        XCTAssertNotNil(healthEndpoint)
        XCTAssertEqual(healthEndpoint?.method, "GET")
    }

    func testGetAPIGuideSortedByPath() async {
        let guide = await schema.getAPIGuide()

        for i in 0..<(guide.count - 1) {
            XCTAssertLessThanOrEqual(guide[i].path, guide[i + 1].path)
        }
    }

    func testGetAPIGuideWithRegisteredEndpoints() async {
        let endpoint = APIEndpoint(method: "DELETE", path: "/custom/api", description: "custom")
        let cap = makeCapability(name: "api_test", apiEndpoints: [endpoint])
        await schema.register(cap)

        let guide = await schema.getAPIGuide()
        let customEndpoint = guide.first { $0.path == "/custom/api" }
        XCTAssertNotNil(customEndpoint)
        XCTAssertEqual(customEndpoint?.method, "DELETE")
    }

    // MARK: - Export

    func testExportForAI() async throws {
        let cap = FrameworkCapability(
            name: "export_test",
            category: "cat",
            description: "desc",
            debuggingMethods: ["d1"],
            commonIssues: [],
            apiEndpoints: [],
            parameters: [Parameter(name: "p1", type: "String", required: true, description: "pd")],
            tags: ["tag1"],
            examples: ["ex1"]
        )
        try await SkillRegistry.shared.register(cap)

        let exported = await SkillRegistry.shared.exportForAI()
        XCTAssertEqual(exported.count, 1)

        let item = exported.first
        XCTAssertEqual(item?["name"] as? String, "export_test")
        XCTAssertEqual(item?["category"] as? String, "cat")
        XCTAssertEqual(item?["description"] as? String, "desc")
        XCTAssertEqual(item?["tags"] as? [String], ["tag1"])
        XCTAssertEqual(item?["examples"] as? [String], ["ex1"])

        let params = item?["parameters"] as? [[String: Any]]
        XCTAssertEqual(params?.count, 1)
        XCTAssertEqual(params?.first?["name"] as? String, "p1")
        XCTAssertEqual(params?.first?["type"] as? String, "String")
        XCTAssertEqual(params?.first?["required"] as? Bool, true)
    }

    func testExportForAIEmpty() async {
        let exported = await SkillRegistry.shared.exportForAI()
        XCTAssertTrue(exported.isEmpty)
    }

    func testExportAsJSON() async throws {
        let cap = makeCapability(name: "json_test")
        try await SkillRegistry.shared.register(cap)

        let json = try await SkillRegistry.shared.exportAsJSON()
        XCTAssertFalse(json.isEmpty)

        let data = json.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.count, 1)
    }

    func testExportAsJSONEmpty() async throws {
        let json = try await SkillRegistry.shared.exportAsJSON()
        XCTAssertEqual(json, "[]")
    }

    func testExportAsJSONViaAgentSchema() async throws {
        let cap = makeCapability(name: "schema_json")
        await schema.register(cap)

        let json = try await schema.exportAsJSON()
        XCTAssertFalse(json.isEmpty)

        XCTAssertTrue(json.contains("schema_json"))
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

    // MARK: - AgentSchema Convenience Methods

    func testAgentSchemaGetCategories() async {
        await schema.register(makeCapability(name: "a", category: "z"))
        await schema.register(makeCapability(name: "b", category: "a"))

        let categories = await schema.getCategories()
        XCTAssertEqual(categories, ["a", "z"])
    }

    func testAgentSchemaGetTags() async {
        await schema.register(makeCapability(name: "a", tags: ["beta"]))
        await schema.register(makeCapability(name: "b", tags: ["alpha"]))

        let tags = await schema.getTags()
        XCTAssertEqual(tags, ["alpha", "beta"])
    }

    func testAgentSchemaSearch() async {
        await schema.register(makeCapability(name: "FindMe", description: "Searchable desc"))

        let results = await schema.search("FindMe")
        XCTAssertEqual(results.count, 1)
    }

    func testAgentSchemaMultipleInstances() async {
        let schema1 = AgentSchema()
        let schema2 = AgentSchema()

        await schema1.register(makeCapability(name: "shared_test"))

        let fromSchema2 = await schema2.get("shared_test")
        XCTAssertNotNil(fromSchema2)
    }

    func testAgentSchemaRegisterDuplicateSilentlyIgnored() async {
        let cap = makeCapability(name: "silent_dup")
        await schema.register(cap)
        await schema.register(cap)

        let count = await SkillRegistry.shared.count()
        XCTAssertEqual(count, 1)
    }

    // MARK: - Edge Cases

    func testRegisterSkillWithEmptyName() async {
        let cap = makeCapability(name: "")
        await schema.register(cap)

        let retrieved = await schema.get("")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.name, "")
    }

    func testRegisterSkillWithNoOptionalFields() async {
        let cap = FrameworkCapability(
            name: "bare",
            category: "bare_cat",
            description: "bare desc",
            debuggingMethods: [],
            commonIssues: []
        )
        await schema.register(cap)

        let retrieved = await schema.get("bare")
        XCTAssertNotNil(retrieved)
        XCTAssertTrue(retrieved!.tags.isEmpty)
        XCTAssertTrue(retrieved!.parameters.isEmpty)
        XCTAssertTrue(retrieved!.examples.isEmpty)
        XCTAssertTrue(retrieved!.apiEndpoints.isEmpty)

        let tagResult = await schema.getByTag("anything")
        XCTAssertEqual(tagResult.count, 0)
    }

    func testSearchWithSpecialCharacters() async {
        let cap = makeCapability(name: "test-123_api", description: "Special: chars <>&\"'")
        await schema.register(cap)

        let results = await schema.search("test-123_api")
        XCTAssertEqual(results.count, 1)
    }

    func testLargeNumberOfSkills() async throws {
        var caps: [FrameworkCapability] = []
        for i in 0..<50 {
            caps.append(makeCapability(name: "bulk_\(i)", category: "bulk_cat"))
        }

        try await SkillRegistry.shared.registerAll(caps)
        let count = await SkillRegistry.shared.count()
        XCTAssertEqual(count, 50)

        let all = await SkillRegistry.shared.getAll()
        XCTAssertEqual(all.count, 50)

        let byCategory = await SkillRegistry.shared.getByCategory("bulk_cat")
        XCTAssertEqual(byCategory.count, 50)
    }

    func testUnregisterAllFromCategoryOneByOne() async {
        let cap1 = makeCapability(name: "u1", category: "empty_cat")
        let cap2 = makeCapability(name: "u2", category: "empty_cat")
        await schema.register(cap1)
        await schema.register(cap2)

        await schema.unregister("u1")
        await schema.unregister("u2")

        let remaining = await schema.getCapabilities(category: "empty_cat")
        XCTAssertTrue(remaining.isEmpty)
    }

    func testRegisterAllWithBuiltinFailsOnDuplicate() async throws {
        try await BuiltinSkills.registerAllWithRegistry()

        do {
            try await BuiltinSkills.registerAllWithRegistry()
            XCTFail("Should throw on duplicate registration")
        } catch {
            XCTAssertTrue(String(describing: error).contains("already registered") || (error as? SkillError).map { _ in true } ?? false)
        }
    }

    func testAPIEndpointParameters() {
        let endpoint = APIEndpoint(method: "POST", path: "/test", description: "d", parameters: ["a": "1", "b": "2"])
        XCTAssertEqual(endpoint.parameters.count, 2)
        XCTAssertEqual(endpoint.parameters["a"], "1")
    }

    func testIssueSolutionFieldsNotEmpty() {
        let issue = IssueSolution(symptom: "s", cause: "c", solution: "sol")
        XCTAssertFalse(issue.symptom.isEmpty)
        XCTAssertFalse(issue.cause.isEmpty)
        XCTAssertFalse(issue.solution.isEmpty)
    }
}

private extension Array {
    func any(_ predicate: (Element) throws -> Bool) -> Bool {
        (try? contains(where: predicate)) ?? false
    }
}
