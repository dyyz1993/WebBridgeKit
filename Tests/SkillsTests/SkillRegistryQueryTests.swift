import XCTest
@testable import Skills

extension AgentSchemaTests {

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
