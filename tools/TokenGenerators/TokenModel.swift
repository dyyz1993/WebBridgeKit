import Foundation

struct DesignTokens: Codable {
    let version: String
    let colors: ColorsSection
    let typography: [String: TypographyToken]
    let monospaceVariants: [String: StyledTypographyToken]?
    let textStyleAliases: [String: StyledTypographyToken]?
    let spacing: [String: Double]
    let cornerRadius: [String: Double]
    let shadows: ShadowsSection
    let opacity: [String: Double]
    let animation: [String: AnimationToken]
    let icon: [String: Double]
    let componentContracts: [String: [String: ContractValue]]?
    let gradients: [String: GradientToken]?
    let breakpoints: [String: Double]?

    struct ColorsSection: Codable {
        let light: [String: String]
        let dark: [String: String]
        let compatibility: [String: CompatColorToken]?
    }

    struct TypographyToken: Codable {
        let size: Double
        let weight: String
        let tracking: Double?
        let maxLines: Int?
    }

    struct StyledTypographyToken: Codable {
        let size: Double
        let weight: String
        let textStyle: String
    }

    struct ShadowToken: Codable {
        let color: String?
        let opacity: ShadowOpacity
        let offsetX: Double
        let offsetY: Double
        let radius: Double
    }

    enum ShadowOpacity: Codable {
        case unified(Double)
        case split(light: Double, dark: Double)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let d = try? container.decode(Double.self) {
                self = .unified(d)
            } else {
                let obj = try container.decode(SplitOpacity.self)
                self = .split(light: obj.light, dark: obj.dark)
            }
        }

        var lightValue: Double {
            switch self {
            case .unified(let d): return d
            case .split(let l, _): return l
            }
        }

        var darkValue: Double {
            switch self {
            case .unified(let d): return d
            case .split(_, let d): return d
            }
        }

        struct SplitOpacity: Codable {
            let light: Double
            let dark: Double
        }
    }

    struct AnimationToken: Codable {
        let duration: Double
        let curve: String
        let damping: Double?
        let velocity: Double?
    }

    struct GradientToken: Codable {
        let start: String
        let end: String
        let angle: Double
    }
}

struct ShadowsSection: Codable {
    let elevation: [String: DesignTokens.ShadowToken]
    let legacyAliases: [String: DesignTokens.ShadowToken]

    private struct DynamicCodingKey: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        var elev: [String: DesignTokens.ShadowToken] = [:]
        var legacy: [String: DesignTokens.ShadowToken] = [:]

        for key in container.allKeys {
            if key.stringValue == "legacyAliases" {
                legacy = try container.decode([String: DesignTokens.ShadowToken].self, forKey: key)
            } else {
                elev[key.stringValue] = try container.decode(DesignTokens.ShadowToken.self, forKey: key)
            }
        }

        elevation = elev
        legacyAliases = legacy
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        for (key, value) in elevation {
            if let codingKey = DynamicCodingKey(stringValue: key) {
                try container.encode(value, forKey: codingKey)
            }
        }
        if let codingKey = DynamicCodingKey(stringValue: "legacyAliases") {
            try container.encode(legacyAliases, forKey: codingKey)
        }
    }
}

struct CompatColorToken: Codable {
    let ref: String?
    let light: String?
    let dark: String?

    var isRef: Bool { ref != nil }
    var hasColors: Bool { light != nil && dark != nil }
}

enum ContractValue: Codable, Equatable {
    case doubleValue(Double)
    case boolValue(Bool)
    case intValue(Int)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let b = try? container.decode(Bool.self) {
            self = .boolValue(b)
        } else if let d = try? container.decode(Double.self) {
            self = .doubleValue(d)
        } else if let i = try? container.decode(Int.self) {
            self = .intValue(i)
        } else {
            self = .doubleValue(0)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .doubleValue(let v): try container.encode(v)
        case .boolValue(let v): try container.encode(v)
        case .intValue(let v): try container.encode(v)
        }
    }

    var swiftLiteral: String {
        switch self {
        case .doubleValue(let v): return String(v)
        case .boolValue(let v): return v ? "true" : "false"
        case .intValue(let v): return String(v)
        }
    }

    var swiftType: String {
        switch self {
        case .boolValue: return "Bool"
        default: return "CGFloat"
        }
    }

    var cssLiteral: String {
        switch self {
        case .doubleValue(let v): return "\(Int(v))px"
        case .boolValue: return ""
        case .intValue(let v): return "\(v)px"
        }
    }
}

func parseHex(_ hex: String) -> (r: Double, g: Double, b: Double, a: Double)? {
    let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: "#", with: "")

    if cleaned.hasPrefix("rgba") || cleaned.hasPrefix("rgb") {
        let nums = cleaned
            .replacingOccurrences(of: "rgba", with: "")
            .replacingOccurrences(of: "rgb", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: " ", with: "")
            .split(separator: ",")
            .compactMap { Double($0) }
        if nums.count >= 3 {
            let a = nums.count >= 4 ? nums[3] : 1.0
            return (r: nums[0] / 255.0, g: nums[1] / 255.0, b: nums[2] / 255.0, a: a)
        }
        return nil
    }

    var r: UInt64 = 0, g: UInt64 = 0, b: UInt64 = 0, a: UInt64 = 255
    switch cleaned.count {
    case 6:
        Scanner(string: String(cleaned.prefix(2))).scanHexInt64(&r)
        Scanner(string: String(cleaned.dropFirst(2).prefix(2))).scanHexInt64(&g)
        Scanner(string: String(cleaned.dropFirst(4).prefix(2))).scanHexInt64(&b)
    case 8:
        Scanner(string: String(cleaned.prefix(2))).scanHexInt64(&r)
        Scanner(string: String(cleaned.dropFirst(2).prefix(2))).scanHexInt64(&g)
        Scanner(string: String(cleaned.dropFirst(4).prefix(2))).scanHexInt64(&b)
        Scanner(string: String(cleaned.dropFirst(6).prefix(2))).scanHexInt64(&a)
    case 3:
        Scanner(string: String(repeating: String(cleaned.prefix(1)), count: 2)).scanHexInt64(&r)
        Scanner(string: String(repeating: String(cleaned.dropFirst(1).prefix(1)), count: 2)).scanHexInt64(&g)
        Scanner(string: String(repeating: String(cleaned.dropFirst(2).prefix(1)), count: 2)).scanHexInt64(&b)
    default:
        return nil
    }
    return (r: Double(r) / 255.0, g: Double(g) / 255.0, b: Double(b) / 255.0, a: Double(a) / 255.0)
}

func swiftUIColorExpr(_ hex: String) -> String {
    guard let c = parseHex(hex) else { return "UIColor(red: 0, green: 0, blue: 0, alpha: 1) /* PARSE ERROR: \(hex) */" }
    if c.a < 1.0 {
        return "UIColor(red: \(c.r), green: \(c.g), blue: \(c.b), alpha: \(c.a))"
    }
    return "UIColor(red: \(c.r), green: \(c.g), blue: \(c.b), alpha: 1)"
}

func cssColor(_ hex: String) -> String {
    guard let c = parseHex(hex) else { return hex }
    if c.a < 1.0 {
        return "rgba(\(Int(c.r * 255)), \(Int(c.g * 255)), \(Int(c.b * 255)), \(c.a))"
    }
    return "rgb(\(Int(c.r * 255)), \(Int(c.g * 255)), \(Int(c.b * 255)))"
}

func weightToSwift(_ w: String) -> String {
    switch w {
    case "ultralight": return ".ultraLight"
    case "light": return ".light"
    case "regular": return ".regular"
    case "medium": return ".medium"
    case "semibold": return ".semibold"
    case "bold": return ".bold"
    case "heavy": return ".heavy"
    default: return ".regular"
    }
}

func capitalizeFirst(_ s: String) -> String {
    guard let first = s.first else { return s }
    return String(first).uppercased() + s.dropFirst()
}

func loadTokens(from path: String) -> DesignTokens? {
    guard let data = FileManager.default.contents(atPath: path) else {
        print("ERROR: Cannot read \(path)")
        return nil
    }
    do {
        return try JSONDecoder().decode(DesignTokens.self, from: data)
    } catch {
        print("ERROR: Failed to parse design-tokens.json: \(error)")
        return nil
    }
}

let autoGenHeader = """
// ============================================================
// AUTO-GENERATED by tools/sync-design-tokens.swift
// DO NOT EDIT — changes will be overwritten on next sync.
// Source: docs/design-tokens.json
// Generated: \(ISO8601DateFormatter().string(from: Date()))
// ============================================================

"""
