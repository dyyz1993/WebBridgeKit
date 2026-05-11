// SwiftLint Validation Test - This file intentionally violates design token rules.
// DELETE THIS FILE after CI validation.

import UIKit

public class SwiftLintValidation {

    // Violation 1: Hardcoded RGB color
    let badColor1 = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)

    // Violation 2: System color
    let badColor2: UIColor = .systemBlue

    // Violation 3: System background
    let badColor3: UIColor = .systemBackground

    // Violation 4: System label
    let badColor4: UIColor = .secondaryLabel

    // Violation 5: Static color token
    let badColor5 = ThemeTokens.Colors.Light.primary

    // Violation 6: SF Symbol
    let badIcon = UIImage(systemName: "star.fill")

    // Violation 7: Fixed font size
    let badFont = UIFont.systemFont(ofSize: 14)
}
