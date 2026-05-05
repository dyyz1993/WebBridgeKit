import Foundation

/// Skill registration and management system
/// Skills are modular capabilities that can be discovered and executed
public actor SkillRegistry {
    public static let shared = SkillRegistry()
    
    private var skills: [String: Skill] = [:]
    
    public init() {}
    
    /// Register a skill
    public func register(_ skill: Skill) {
        skills[skill.id] = skill
    }
    
    /// Unregister a skill by ID
    public func unregister(_ skillId: String) {
        skills.removeValue(forKey: skillId)
    }
    
    /// Get skill by ID
    public func get(_ skillId: String) -> Skill? {
        skills[skillId]
    }
    
    /// List all skills
    public func listAll() -> [Skill] {
        Array(skills.values).sorted { $0.name < $1.name }
    }
    
    /// List skills by category
    public func listByCategory(_ category: SkillCategory) -> [Skill] {
        skills.values.filter { $0.category == category }.sorted { $0.name < $1.name }
    }
    
    /// Execute a skill
    public func execute(_ skillId: String, context: SkillContext) async throws -> SkillResult {
        guard let skill = skills[skillId] else {
            throw SkillError.notFound(skillId: skillId)
        }
        
        guard skill.isEnabled else {
            throw SkillError.disabled(skillId: skillId)
        }
        
        return try await skill.execute(context: context)
    }
    
    /// Enable a skill
    public func enable(_ skillId: String) {
        skills[skillId]?.isEnabled = true
    }
    
    /// Disable a skill
    public func disable(_ skillId: String) {
        skills[skillId]?.isEnabled = false
    }
}

// MARK: - Skill

public class Skill: Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let category: SkillCategory
    public let icon: String?
    public var isEnabled: Bool
    public let version: String
    
    private let executeHandler: @Sendable (SkillContext) async throws -> SkillResult
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        description: String,
        category: SkillCategory = .general,
        icon: String? = nil,
        isEnabled: Bool = true,
        version: String = "1.0.0",
        execute: @escaping @Sendable (SkillContext) async throws -> SkillResult
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.icon = icon
        self.isEnabled = isEnabled
        self.version = version
        self.executeHandler = execute
    }
    
    public func execute(context: SkillContext) async throws -> SkillResult {
        try await executeHandler(context)
    }
}

// MARK: - Skill Category

public enum SkillCategory: String, CaseIterable, Sendable {
    case general
    case navigation
    case media
    case data
    case communication
    case device
    case network
    case debug
    
    public var displayName: String {
        switch self {
        case .general: return "通用"
        case .navigation: return "导航"
        case .media: return "媒体"
        case .data: return "数据"
        case .communication: return "通信"
        case .device: return "设备"
        case .network: return "网络"
        case .debug: return "调试"
        }
    }
}

// MARK: - Skill Context

public struct SkillContext: Sendable {
    public let parameters: [String: Any]
    public let sender: String?
    public let environment: [String: String]
    
    public init(
        parameters: [String: Any] = [:],
        sender: String? = nil,
        environment: [String: String] = [:]
    ) {
        self.parameters = parameters
        self.sender = sender
        self.environment = environment
    }
}

// MARK: - Skill Result

public enum SkillResult: Sendable {
    case success(data: Any?)
    case error(message: String)
    case pending(taskId: String)
    
    public static let success: SkillResult = .success(data: nil)
}

// MARK: - Skill Error

public enum SkillError: Error, LocalizedError {
    case notFound(skillId: String)
    case disabled(skillId: String)
    case executionFailed(skillId: String, reason: String)
    case invalidParameters(skillId: String, expected: String)
    
    public var errorDescription: String? {
        switch self {
        case .notFound(let id):
            return "Skill '\(id)' not found"
        case .disabled(let id):
            return "Skill '\(id)' is disabled"
        case .executionFailed(let id, let reason):
            return "Skill '\(id)' execution failed: \(reason)"
        case .invalidParameters(let id, let expected):
            return "Skill '\(id)' invalid parameters: expected \(expected)"
        }
    }
}
