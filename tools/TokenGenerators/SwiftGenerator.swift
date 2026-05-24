import Foundation

let typographyTextStyleMap: [String: String] = [
    "screenTitle": ".largeTitle",
    "compactTitle": ".title1",
    "sectionTitle": ".headline",
    "rowTitle": ".body",
    "cardTitle": ".subheadline",
    "body": ".body",
    "metadata": ".footnote",
    "caption": ".caption1",
    "badge": ".caption2",
    "tabLabel": ".caption2",
    "button": ".body",
    "buttonMedium": ".body",
]

func textStyleForKey(_ key: String) -> String {
    return typographyTextStyleMap[key] ?? ".body"
}

func generateDynamicColorAlias(_ key: String) -> String {
    "        public static var \(key): UIColor { dynamicColor(light: Colors.Light.\(key), dark: Colors.Dark.\(key)) }"
}

func generateSwift(_ tokens: DesignTokens) -> String {
    var lines: [String] = []
    lines.append("import UIKit")
    lines.append("")
    lines.append(autoGenHeader)
    lines.append("public enum ThemeTokens {")
    lines.append("")

    lines.append("    // DEPRECATED: Use ThemeTokens.Color instead (auto-adapts to Dark Mode)")
    lines.append("    public enum Colors {")
    lines.append("        public enum Light {")
    let lightKeys = tokens.colors.light.keys.sorted()
    for key in lightKeys {
        let val = tokens.colors.light[key]!
        lines.append("            public static let \(key) = \(swiftUIColorExpr(val))")
    }
    lines.append("        }")
    lines.append("")
    lines.append("        public enum Dark {")
    let darkKeys = tokens.colors.dark.keys.sorted()
    for key in darkKeys {
        let val = tokens.colors.dark[key]!
        lines.append("            public static let \(key) = \(swiftUIColorExpr(val))")
    }
    lines.append("        }")
    lines.append("    }")
    lines.append("")

    lines.append("    // === Dynamic Color aliases (the ONE way to get colors) ===")
    lines.append("    /// Dynamic color tokens — auto-adapt to Light/Dark Mode.")
    lines.append("    /// New code must use ThemeTokens.Color.* instead of ThemeTokens.Colors.Light/Dark or hardcoded UIColor values.")
    lines.append("    public enum Color {")
    let colorKeys = lightKeys.filter { tokens.colors.dark[$0] != nil }
    for key in colorKeys {
        lines.append(generateDynamicColorAlias(key))
    }
    lines.append("")

    if let compat = tokens.colors.compatibility {
        lines.append("        // Compatibility aliases used by existing components.")
        let compatKeys = compat.keys.sorted()
        for key in compatKeys {
            let token = compat[key]!
            if let ref = token.ref {
                lines.append("        public static var \(key): UIColor { \(ref) }")
            } else if let light = token.light, let dark = token.dark {
                lines.append("        public static var \(key): UIColor { dynamicColor(light: \(swiftUIColorExpr(light)), dark: \(swiftUIColorExpr(dark))) }")
            }
        }
    }
    lines.append("")
    lines.append("        private static func dynamicColor(light: UIColor, dark: UIColor) -> UIColor {")
    lines.append("            UIColor { trait in")
    lines.append("                trait.userInterfaceStyle == .dark ? dark : light")
    lines.append("            }")
    lines.append("        }")
    lines.append("    }")
    lines.append("")

    lines.append("    public enum Typography {")
    let typoKeys = tokens.typography.keys.sorted()
    for key in typoKeys {
        let t = tokens.typography[key]!
        let w = weightToSwift(t.weight)
        let textStyle = textStyleForKey(key)
        lines.append("        public static let \(key) = UIFontMetrics(forTextStyle: \(textStyle)).scaledFont(for: .systemFont(ofSize: \(Int(t.size)), weight: \(w)))")
    }

    if let monoVariants = tokens.monospaceVariants {
        lines.append("")
        lines.append("        // Monospace variants")
        let monoKeys = monoVariants.keys.sorted()
        for key in monoKeys {
            let t = monoVariants[key]!
            let w = weightToSwift(t.weight)
            lines.append("        public static let \(key) = UIFontMetrics(forTextStyle: .\(t.textStyle)).scaledFont(for: UIFont.monospacedSystemFont(ofSize: \(Int(t.size)), weight: \(w)))")
        }
    }

    if let textStyleAliases = tokens.textStyleAliases {
        lines.append("")
        lines.append("        // Legacy Apple text style aliases")
        let aliasKeys = textStyleAliases.keys.sorted()
        for key in aliasKeys {
            let t = textStyleAliases[key]!
            let w = weightToSwift(t.weight)
            lines.append("        public static let \(key) = UIFontMetrics(forTextStyle: .\(t.textStyle)).scaledFont(for: .systemFont(ofSize: \(Int(t.size)), weight: \(w)))")
        }
    }
    lines.append("    }")
    lines.append("")

    lines.append("    public enum Spacing {")
    let spacingKeys = tokens.spacing.keys.sorted()
    for key in spacingKeys {
        let val = tokens.spacing[key]!
        lines.append("        public static let \(key): CGFloat = \(val)")
    }
    lines.append("    }")
    lines.append("")

    lines.append("    public enum CornerRadius {")
    let radiusKeys = tokens.cornerRadius.keys.sorted()
    for key in radiusKeys {
        let val = tokens.cornerRadius[key]!
        lines.append("        public static let \(key): CGFloat = \(val)")
    }
    lines.append("    }")
    lines.append("    public enum Shadows {")
    let shadowKeys = tokens.shadows.elevation.keys.sorted()
    for key in shadowKeys {
        let s = tokens.shadows.elevation[key]!
        lines.append("        public static let \(key) = ShadowValues(opacity: \(s.opacity.lightValue), offsetX: \(s.offsetX), offsetY: \(s.offsetY), radius: \(s.radius))")
    }
    let legacyShadowKeys = tokens.shadows.legacyAliases.keys.sorted()
    for key in legacyShadowKeys {
        let s = tokens.shadows.legacyAliases[key]!
        lines.append("        public static let \(key) = ShadowValues(opacity: \(s.opacity.lightValue), offsetX: \(s.offsetX), offsetY: \(s.offsetY), radius: \(s.radius))")
    }
    lines.append("    }")
    lines.append("")

    lines.append("    public enum Opacity {")
    let opacityKeys = tokens.opacity.keys.sorted()
    for key in opacityKeys {
        let val = tokens.opacity[key]!
        lines.append("        public static let \(key): CGFloat = \(val)")
    }
    lines.append("    }")
    lines.append("")

    lines.append("    public enum Animation {")
    let animKeys = tokens.animation.keys.sorted()
    for key in animKeys {
        let a = tokens.animation[key]!
        var extras: [String] = []
        if let d = a.damping { extras.append("damping: \(d)") }
        if let v = a.velocity { extras.append("velocity: \(v)") }
        let extraStr = extras.isEmpty ? "" : ", " + extras.joined(separator: ", ")
        lines.append("        public static let \(key) = AnimationValues(duration: \(a.duration)\(extraStr))")
    }
    lines.append("    }")
    lines.append("")

    lines.append("    public enum Icons {")
    lines.append("        public enum Sizes {")
    let iconKeys = tokens.icon.keys.sorted()
    for key in iconKeys {
        let val = tokens.icon[key]!
        lines.append("            public static let \(key): CGFloat = \(val)")
    }
    lines.append("        }")
    lines.append("    }")
    lines.append("")

    if let breakpoints = tokens.breakpoints {
        lines.append("    public enum Breakpoints {")
        let bpKeys = breakpoints.keys.sorted()
        for key in bpKeys {
            let val = breakpoints[key]!
            lines.append("        public static let \(key): CGFloat = \(val)")
        }
        lines.append("    }")
        lines.append("")
    }

    if let contracts = tokens.componentContracts {
        lines.append("    public enum ComponentContract {")
        let contractKeys = contracts.keys.sorted()
        for contractName in contractKeys {
            let pascalName = capitalizeFirst(contractName)
            lines.append("        public enum \(pascalName) {")
            let props = contracts[contractName]!
            let propKeys = props.keys.sorted()
            for propKey in propKeys {
                let val = props[propKey]!
                lines.append("            public static let \(propKey): \(val.swiftType) = \(val.swiftLiteral)")
            }
            lines.append("        }")
        }
        lines.append("    }")
        lines.append("")
    }

    if let gradients = tokens.gradients, !gradients.isEmpty {
        lines.append("    public enum Gradients {")
        let gradientKeys = gradients.keys.sorted()
        for key in gradientKeys {
            let g = gradients[key]!
            let startExpr = swiftUIColorExpr(g.start)
            let endExpr = swiftUIColorExpr(g.end)
            lines.append("        public static let \(key) = GradientValues(start: \(startExpr), end: \(endExpr), angle: \(g.angle))")
        }
        lines.append("    }")
        lines.append("")
    }

    lines.append("}")

    lines.append("")
    lines.append("public struct ShadowValues: Sendable {")
    lines.append("    public let opacity: CGFloat")
    lines.append("    public let offsetX: CGFloat")
    lines.append("    public let offsetY: CGFloat")
    lines.append("    public let radius: CGFloat")
    lines.append("}")
    lines.append("")
    lines.append("public struct AnimationValues: Sendable {")
    lines.append("    public let duration: TimeInterval")
    lines.append("    public let damping: CGFloat")
    lines.append("    public let velocity: CGFloat")
    lines.append("")
    lines.append("    public init(duration: TimeInterval, damping: CGFloat = 1.0, velocity: CGFloat = 0.5) {")
    lines.append("        self.duration = duration")
    lines.append("        self.damping = damping")
    lines.append("        self.velocity = velocity")
    lines.append("    }")
    lines.append("}")
    lines.append("")
    lines.append("public struct GradientValues: Sendable {")
    lines.append("    public let start: UIColor")
    lines.append("    public let end: UIColor")
    lines.append("    public let angle: CGFloat")
    lines.append("}")

    return lines.joined(separator: "\n") + "\n"
}
