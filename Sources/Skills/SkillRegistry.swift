import Foundation

// MARK: - SkillRegistry

/// Central registry for all framework capabilities (skills)
/// Provides unified interface for registration, discovery, and querying
public actor SkillRegistry {
    /// Shared singleton
    public static let shared = SkillRegistry()

    /// All registered skills
    private var skills: [String: FrameworkCapability] = [:]

    /// Skills by category
    private var categoryIndex: [String: [FrameworkCapability]] = [:]

    /// Skills by tag
    private var tagIndex: [String: [FrameworkCapability]] = [:]

    private init() {}

    // MARK: - Registration

    /// Register a skill capability
    /// - Parameter skill: The skill to register
    /// - Throws: If a skill with the same name already exists
    public func register(_ skill: FrameworkCapability) throws {
        if skills[skill.name] != nil {
            throw SkillError.duplicateSkill(skill.name)
        }

        skills[skill.name] = skill

        // Update category index
        categoryIndex[skill.category, default: []].append(skill)

        // Update tag index
        for tag in skill.tags {
            tagIndex[tag, default: []].append(skill)
        }
    }

    /// Register multiple skills at once
    /// - Parameter skills: Array of skills to register
    /// - Throws: If any registration fails
    public func registerAll(_ skills: [FrameworkCapability]) throws {
        for skill in skills {
            try register(skill)
        }
    }

    /// Unregister a skill
    /// - Parameter name: Name of the skill to unregister
    /// - Returns: The unregistered skill if found
    @discardableResult
    public func unregister(_ name: String) -> FrameworkCapability? {
        guard let skill = skills.removeValue(forKey: name) else {
            return nil
        }

        // Update category index
        categoryIndex[skill.category]?.removeAll { $0.name == name }

        // Update tag index
        for tag in skill.tags {
            tagIndex[tag]?.removeAll { $0.name == name }
        }

        return skill
    }

    /// Clear all registered skills
    public func clearAll() {
        skills.removeAll()
        categoryIndex.removeAll()
        tagIndex.removeAll()
    }

    // MARK: - Query

    /// Get a specific skill by name
    /// - Parameter name: Skill name
    /// - Returns: The skill if found
    public func get(_ name: String) -> FrameworkCapability? {
        skills[name]
    }

    /// Get all registered skills
    /// - Returns: Array of all skills
    public func getAll() -> [FrameworkCapability] {
        Array(skills.values).sorted { $0.name < $1.name }
    }

    /// Get skills by category
    /// - Parameter category: Category name
    /// - Returns: Array of skills in the category
    public func getByCategory(_ category: String) -> [FrameworkCapability] {
        categoryIndex[category] ?? []
    }

    /// Get skills by tag
    /// - Parameter tag: Tag name
    /// - Returns: Array of skills with the tag
    public func getByTag(_ tag: String) -> [FrameworkCapability] {
        tagIndex[tag] ?? []
    }

    /// Search skills by name or description
    /// - Parameter query: Search query
    /// - Returns: Array of matching skills
    public func search(_ query: String) -> [FrameworkCapability] {
        let lowerQuery = query.lowercased()
        return getAll().filter { skill in
            skill.name.lowercased().contains(lowerQuery) ||
            skill.description.lowercased().contains(lowerQuery)
        }
    }

    // MARK: - Statistics

    /// Get count of registered skills
    /// - Returns: Number of skills
    public func count() -> Int {
        skills.count
    }

    /// Get all categories
    /// - Returns: Array of category names
    public func getCategories() -> [String] {
        Array(categoryIndex.keys).sorted()
    }

    /// Get all tags
    /// - Returns: Array of tag names
    public func getTags() -> [String] {
        Array(tagIndex.keys).sorted()
    }

    // MARK: - Export

    /// Export all skills as structured data for AI agents
    /// - Returns: Structured skill data
    public func exportForAI() -> [[String: Any]] {
        getAll().map { skill in
            [
                "name": skill.name,
                "category": skill.category,
                "description": skill.description,
                "parameters": skill.parameters.map { param in
                    [
                        "name": param.name,
                        "type": param.type,
                        "required": param.required,
                        "description": param.description
                    ]
                },
                "tags": skill.tags,
                "examples": skill.examples
            ]
        }
    }

    /// Export skills as JSON string
    /// - Returns: JSON string
    public func exportAsJSON() throws -> String {
        let data = try JSONSerialization.data(withJSONObject: exportForAI())
        return String(data: data, encoding: .utf8) ?? ""
    }
}
