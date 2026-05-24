import Foundation

func printValidationReport(_ tokens: DesignTokens) {
    print("")
    print("===========================================================")
    print("  Design Token Validation Report")
    print("===========================================================")
    print("")

    let colorCount = tokens.colors.light.count + tokens.colors.dark.count
    let compatCount = tokens.colors.compatibility?.count ?? 0
    let typoCount = tokens.typography.count
    let monoCount = tokens.monospaceVariants?.count ?? 0
    let textStyleAliasCount = tokens.textStyleAliases?.count ?? 0
    let spacingCount = tokens.spacing.count
    let radiusCount = tokens.cornerRadius.count
    let shadowCount = tokens.shadows.elevation.count
    let legacyShadowCount = tokens.shadows.legacyAliases.count
    let opacityCount = tokens.opacity.count
    let animCount = tokens.animation.count
    let iconSizeCount = tokens.icon.count
    let contractCount = tokens.componentContracts?.reduce(0) { $0 + $1.value.count } ?? 0
    let gradientCount = tokens.gradients?.count ?? 0
    let breakpointCount = tokens.breakpoints?.count ?? 0
    let total = colorCount + compatCount + typoCount + monoCount + textStyleAliasCount + spacingCount + radiusCount + shadowCount + legacyShadowCount + opacityCount + animCount + iconSizeCount + contractCount + gradientCount + breakpointCount

    print("  Tokens by category:")
    print("    Colors:          \(colorCount) (\(tokens.colors.light.count) light + \(tokens.colors.dark.count) dark)")
    print("    Color Compat:    \(compatCount)")
    print("    Typography:      \(typoCount)")
    print("    Monospace:       \(monoCount)")
    print("    TextStyle Alias: \(textStyleAliasCount)")
    print("    Spacing:         \(spacingCount)")
    print("    CornerRadius:    \(radiusCount)")
    print("    Shadows:         \(shadowCount) + \(legacyShadowCount) legacy")
    print("    Opacity:         \(opacityCount)")
    print("    Animation:       \(animCount)")
    print("    Icon sizes:      \(iconSizeCount)")
    print("    Contracts:       \(contractCount)")
    print("    Gradients:       \(gradientCount)")
    print("    Breakpoints:     \(breakpointCount)")
    print("    ------------------------")
    print("    TOTAL:           \(total)")
    print("")

    let lightSet = Set(tokens.colors.light.keys)
    let darkSet = Set(tokens.colors.dark.keys)
    let missingDark = lightSet.subtracting(darkSet)
    let missingLight = darkSet.subtracting(lightSet)

    if missingDark.isEmpty && missingLight.isEmpty {
        print("  OK Color parity: light and dark palettes have identical keys")
    } else {
        if !missingDark.isEmpty {
            print("  WARN  Missing from dark: \(missingDark.sorted().joined(separator: ", "))")
        }
        if !missingLight.isEmpty {
            print("  WARN  Missing from light: \(missingLight.sorted().joined(separator: ", "))")
        }
    }

    var parseErrors: [(String, String)] = []
    for (key, hex) in tokens.colors.light {
        if parseHex(hex) == nil {
            parseErrors.append(("light.\(key)", hex))
        }
    }
    for (key, hex) in tokens.colors.dark {
        if parseHex(hex) == nil {
            parseErrors.append(("dark.\(key)", hex))
        }
    }
    if parseErrors.isEmpty {
        print("  OK Color values: all parseable")
    } else {
        for (path, val) in parseErrors {
            print("  ERROR Unparseable color: \(path) = \(val)")
        }
    }
    print("")
}
