import Foundation

// MARK: - Data Models

public struct FrameworkCapability: Codable, Sendable {
    public let name: String
    public let category: String
    public let description: String
    public let debuggingMethods: [String]
    public let commonIssues: [IssueSolution]
    public let apiEndpoints: [APIEndpoint]
    public let parameters: [Parameter]
    public let tags: [String]
    public let examples: [String]

    public init(
        name: String,
        category: String,
        description: String,
        debuggingMethods: [String],
        commonIssues: [IssueSolution],
        apiEndpoints: [APIEndpoint] = [],
        parameters: [Parameter] = [],
        tags: [String] = [],
        examples: [String] = []
    ) {
        self.name = name
        self.category = category
        self.description = description
        self.debuggingMethods = debuggingMethods
        self.commonIssues = commonIssues
        self.apiEndpoints = apiEndpoints
        self.parameters = parameters
        self.tags = tags
        self.examples = examples
    }
}

public struct Parameter: Codable, Sendable {
    public let name: String
    public let type: String
    public let required: Bool
    public let description: String

    public init(name: String, type: String, required: Bool, description: String) {
        self.name = name
        self.type = type
        self.required = required
        self.description = description
    }
}

public struct IssueSolution: Codable, Sendable {
    public let symptom: String
    public let cause: String
    public let solution: String

    public init(symptom: String, cause: String, solution: String) {
        self.symptom = symptom
        self.cause = cause
        self.solution = solution
    }
}

public struct APIEndpoint: Codable, Sendable {
    public let method: String
    public let path: String
    public let description: String
    public let parameters: [String: String]

    public init(method: String, path: String, description: String, parameters: [String: String] = [:]) {
        self.method = method
        self.path = path
        self.description = description
        self.parameters = parameters
    }
}

// MARK: - Skill Error

public enum SkillError: LocalizedError {
    case duplicateSkill(String)
    case skillNotFound(String)
    case invalidRegistration

    public var errorDescription: String? {
        switch self {
        case .duplicateSkill(let name):
            return "Skill '\(name)' is already registered"
        case .skillNotFound(let name):
            return "Skill '\(name)' not found"
        case .invalidRegistration:
            return "Invalid skill registration"
        }
    }
}
