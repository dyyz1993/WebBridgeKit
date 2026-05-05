import XCTest
@testable import Skills

final class SkillRegistryTests: XCTestCase {
    
    var registry: SkillRegistry!
    
    override func setUp() async throws {
        try await super.setUp()
        registry = SkillRegistry()
    }
    
    // MARK: - Registration
    
    func testRegisterSkill() async {
        let skill = Skill(name: "test", description: "Test skill", execute: { _ in .success })
        await registry.register(skill)
        
        let retrieved = await registry.get(skill.id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.name, "test")
    }
    
    func testUnregisterSkill() async {
        let skill = Skill(name: "test", description: "Test skill", execute: { _ in .success })
        await registry.register(skill)
        await registry.unregister(skill.id)
        
        let retrieved = await registry.get(skill.id)
        XCTAssertNil(retrieved)
    }
    
    // MARK: - Listing
    
    func testListAll() async {
        let skill1 = Skill(name: "alpha", description: "First", execute: { _ in .success })
        let skill2 = Skill(name: "beta", description: "Second", execute: { _ in .success })
        
        await registry.register(skill1)
        await registry.register(skill2)
        
        let skills = await registry.listAll()
        XCTAssertEqual(skills.count, 2)
        // Should be sorted by name
        XCTAssertEqual(skills[0].name, "alpha")
        XCTAssertEqual(skills[1].name, "beta")
    }
    
    func testListByCategory() async {
        let navSkill = Skill(name: "nav", description: "Nav", category: .navigation, execute: { _ in .success })
        let mediaSkill = Skill(name: "media", description: "Media", category: .media, execute: { _ in .success })
        
        await registry.register(navSkill)
        await registry.register(mediaSkill)
        
        let navSkills = await registry.listByCategory(.navigation)
        XCTAssertEqual(navSkills.count, 1)
        XCTAssertEqual(navSkills[0].name, "nav")
    }
    
    // MARK: - Execution
    
    func testExecuteSkill() async throws {
        let skill = Skill(
            name: "echo",
            description: "Echo",
            execute: { context in
                .success(data: context.parameters["message"] ?? "")
            }
        )
        
        await registry.register(skill)
        
        let result = try await registry.execute(skill.id, context: SkillContext(parameters: ["message": "hello"]))
        
        switch result {
        case .success(let data):
            XCTAssertEqual(data as? String, "hello")
        default:
            XCTFail("Expected success result")
        }
    }
    
    func testExecuteNonExistentSkill() async {
        do {
            _ = try await registry.execute("nonexistent", context: SkillContext())
            XCTFail("Should throw error")
        } catch let error as SkillError {
            if case .notFound(let skillId) = error {
                XCTAssertEqual(skillId, "nonexistent")
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testExecuteDisabledSkill() async throws {
        let skill = Skill(name: "disabled", description: "Disabled", isEnabled: false, execute: { _ in .success })
        
        await registry.register(skill)
        
        do {
            _ = try await registry.execute(skill.id, context: SkillContext())
            XCTFail("Should throw error")
        } catch let error as SkillError {
            if case .disabled(let skillId) = error {
                XCTAssertEqual(skillId, skill.id)
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Enable/Disable
    
    func testEnableDisable() async {
        let skill = Skill(name: "test", description: "Test", execute: { _ in .success })
        
        await registry.register(skill)
        await registry.disable(skill.id)
        
        var retrieved = await registry.get(skill.id)
        XCTAssertFalse(retrieved!.isEnabled)
        
        await registry.enable(skill.id)
        retrieved = await registry.get(skill.id)
        XCTAssertTrue(retrieved!.isEnabled)
    }
    
    // MARK: - Built-in Skills
    
    func testBuiltinSkillsCount() {
        XCTAssertEqual(BuiltinSkills.all.count, 5)
    }
    
    func testBuiltinSkillsCategories() {
        let categories = Set(BuiltinSkills.all.map { $0.category })
        XCTAssertTrue(categories.contains(.navigation))
        XCTAssertTrue(categories.contains(.communication))
        XCTAssertTrue(categories.contains(.media))
        XCTAssertTrue(categories.contains(.device))
        XCTAssertTrue(categories.contains(.data))
    }
}
