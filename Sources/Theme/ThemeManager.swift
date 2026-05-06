import UIKit

public enum ThemeMode: String, CaseIterable, Sendable {
    case light
    case dark
    case system
}

public actor ThemeManager {
    public static let shared = ThemeManager()

    private var currentMode: ThemeMode
    private var observers: [(@Sendable (ThemeMode) -> Void)] = []

    public init(mode: ThemeMode = .system) {
        self.currentMode = mode
    }

    public func getMode() -> ThemeMode {
        currentMode
    }

    public func getTheme() -> Theme {
        let isDark: Bool
        if currentMode == .dark {
            isDark = true
        } else if currentMode == .system {
            isDark = UIScreen.main.traitCollection.userInterfaceStyle == .dark
        } else {
            isDark = false
        }
        return Theme(name: currentMode.rawValue, isDark: isDark)
    }

    public func apply(_ mode: ThemeMode) {
        currentMode = mode
        notifyObservers()
    }

    public func observe(_ handler: @escaping @Sendable (ThemeMode) -> Void) {
        observers.append(handler)
    }

    @MainActor
    public func applyToWindow(_ window: UIWindow) async {
        let mode = await getMode()
        Self.applyMode(mode, to: window)
    }

    @MainActor
    public static func applyMode(_ mode: ThemeMode, to window: UIWindow) {
        window.tintColor = ThemeColors.current.primary
        switch mode {
        case .light:
            window.overrideUserInterfaceStyle = .light
        case .dark:
            window.overrideUserInterfaceStyle = .dark
        case .system:
            window.overrideUserInterfaceStyle = .unspecified
        }

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = ThemeColors.current.navigationBarBackground
        navAppearance.titleTextAttributes = [.foregroundColor: ThemeColors.current.navigationBarTitle]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: ThemeColors.current.navigationBarTitle]

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = ThemeColors.current.tabBarBackground

        UITabBar.appearance().standardAppearance = tabAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        }
    }

    private func notifyObservers() {
        for observer in observers {
            observer(currentMode)
        }
    }
}

// MARK: - Theme Colors (Dynamic)

public struct ThemeColors: Sendable {
    public let primary: UIColor
    public let secondary: UIColor
    public let background: UIColor
    public let surface: UIColor
    public let text: UIColor
    public let textSecondary: UIColor
    public let border: UIColor
    public let navigationBarBackground: UIColor
    public let navigationBarTitle: UIColor
    public let tabBarBackground: UIColor
    public let success: UIColor
    public let warning: UIColor
    public let error: UIColor
    public let info: UIColor
    public let cardBackground: UIColor
    public let gradientStart: UIColor
    public let gradientEnd: UIColor
    public let badgeBackground: UIColor
    public let badgeText: UIColor
    public let divider: UIColor
    public let fabBackground: UIColor

    public init(
        primary: UIColor = .systemBlue,
        secondary: UIColor = .systemGray,
        background: UIColor = .systemBackground,
        surface: UIColor = .secondarySystemBackground,
        text: UIColor = .label,
        textSecondary: UIColor = .secondaryLabel,
        border: UIColor = .separator,
        navigationBarBackground: UIColor = .systemBackground,
        navigationBarTitle: UIColor = .label,
        tabBarBackground: UIColor = .systemBackground,
        success: UIColor = .systemGreen,
        warning: UIColor = .systemOrange,
        error: UIColor = .systemRed,
        info: UIColor = .systemBlue,
        cardBackground: UIColor? = nil,
        gradientStart: UIColor? = nil,
        gradientEnd: UIColor? = nil,
        badgeBackground: UIColor? = nil,
        badgeText: UIColor? = nil,
        divider: UIColor? = nil,
        fabBackground: UIColor? = nil
    ) {
        self.primary = primary
        self.secondary = secondary
        self.background = background
        self.surface = surface
        self.text = text
        self.textSecondary = textSecondary
        self.border = border
        self.navigationBarBackground = navigationBarBackground
        self.navigationBarTitle = navigationBarTitle
        self.tabBarBackground = tabBarBackground
        self.success = success
        self.warning = warning
        self.error = error
        self.info = info
        self.cardBackground = cardBackground ?? UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1)
                : .white
        }
        self.gradientStart = gradientStart ?? UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.2, green: 0.3, blue: 0.6, alpha: 0.9)
                : UIColor(red: 0.25, green: 0.45, blue: 0.95, alpha: 0.85)
        }
        self.gradientEnd = gradientEnd ?? UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.4, green: 0.2, blue: 0.5, alpha: 0.9)
                : UIColor(red: 0.6, green: 0.3, blue: 0.75, alpha: 0.85)
        }
        self.badgeBackground = badgeBackground ?? UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 1)
                : UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1)
        }
        self.badgeText = badgeText ?? UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? .lightText
                : .darkGray
        }
        self.divider = divider ?? UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(white: 0.25, alpha: 1)
                : UIColor(white: 0.85, alpha: 1)
        }
        self.fabBackground = fabBackground ?? primary
    }

    public static let current = ThemeColors()
    public static let `default` = ThemeColors()
}

// MARK: - Theme Typography

public struct ThemeTypography: Sendable {
    public let largeTitle: UIFont
    public let title1: UIFont
    public let title2: UIFont
    public let headline: UIFont
    public let body: UIFont
    public let caption1: UIFont
    public let caption2: UIFont

    public init(
        largeTitle: UIFont? = nil,
        title1: UIFont? = nil,
        title2: UIFont? = nil,
        headline: UIFont? = nil,
        body: UIFont? = nil,
        caption1: UIFont? = nil,
        caption2: UIFont? = nil
    ) {
        self.largeTitle = largeTitle ?? UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 28, weight: .bold))
        self.title1 = title1 ?? UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 22, weight: .bold))
        self.title2 = title2 ?? UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 20, weight: .semibold))
        self.headline = headline ?? UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 17, weight: .semibold))
        self.body = body ?? UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 15, weight: .regular))
        self.caption1 = caption1 ?? UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 13, weight: .regular))
        self.caption2 = caption2 ?? UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 11, weight: .regular))
    }

    public static let current = ThemeTypography()
}

// MARK: - Legacy Theme Fonts

public struct ThemeFonts: Sendable {
    public let title: UIFont
    public let headline: UIFont
    public let body: UIFont
    public let caption: UIFont
    public let button: UIFont

    public init(
        title: UIFont = .systemFont(ofSize: 28, weight: .bold),
        headline: UIFont = .systemFont(ofSize: 17, weight: .semibold),
        body: UIFont = .systemFont(ofSize: 15, weight: .regular),
        caption: UIFont = .systemFont(ofSize: 12, weight: .regular),
        button: UIFont = .systemFont(ofSize: 16, weight: .medium)
    ) {
        self.title = title
        self.headline = headline
        self.body = body
        self.caption = caption
        self.button = button
    }

    public static let `default` = ThemeFonts()
}

// MARK: - Theme Spacing

public struct ThemeSpacing: Sendable {
    public let xs: CGFloat
    public let sm: CGFloat
    public let md: CGFloat
    public let lg: CGFloat
    public let xl: CGFloat

    public init(
        xs: CGFloat = 4,
        sm: CGFloat = 8,
        md: CGFloat = 16,
        lg: CGFloat = 24,
        xl: CGFloat = 32
    ) {
        self.xs = xs
        self.sm = sm
        self.md = md
        self.lg = lg
        self.xl = xl
    }

    public static let `default` = ThemeSpacing()
}

// MARK: - Theme CornerRadius

public struct ThemeCornerRadius: Sendable {
    public let sm: CGFloat
    public let md: CGFloat
    public let lg: CGFloat
    public let full: CGFloat

    public init(
        sm: CGFloat = 4,
        md: CGFloat = 8,
        lg: CGFloat = 16,
        full: CGFloat = 999
    ) {
        self.sm = sm
        self.md = md
        self.lg = lg
        self.full = full
    }

    public static let `default` = ThemeCornerRadius()
}

// MARK: - Theme Animation

public enum ThemeAnimation {
    public static let standardDuration: TimeInterval = 0.25
    public static let springDuration: TimeInterval = 0.3
    public static let slowDuration: TimeInterval = 0.5
    public static let springDamping: CGFloat = 0.8

    public static func standard(animations: @escaping () -> Void, completion: ((Bool) -> Void)? = nil) {
        UIView.animate(withDuration: standardDuration, animations: animations, completion: completion)
    }

    public static func spring(animations: @escaping () -> Void, completion: ((Bool) -> Void)? = nil) {
        UIView.animate(
            withDuration: springDuration,
            delay: 0,
            usingSpringWithDamping: springDamping,
            initialSpringVelocity: 0,
            options: [],
            animations: animations,
            completion: completion
        )
    }

    public static func slow(animations: @escaping () -> Void, completion: ((Bool) -> Void)? = nil) {
        UIView.animate(withDuration: slowDuration, animations: animations, completion: completion)
    }
}

// MARK: - Legacy Theme

public struct Theme: Sendable {
    public let name: String
    public let isDark: Bool
    public let colors: ThemeColors
    public let fonts: ThemeFonts
    public let spacing: ThemeSpacing
    public let cornerRadius: ThemeCornerRadius

    public init(
        name: String,
        isDark: Bool = false,
        colors: ThemeColors = .current,
        fonts: ThemeFonts = .default,
        spacing: ThemeSpacing = .default,
        cornerRadius: ThemeCornerRadius = .default
    ) {
        self.name = name
        self.isDark = isDark
        self.colors = colors
        self.fonts = fonts
        self.spacing = spacing
        self.cornerRadius = cornerRadius
    }

    public static let `default` = Theme(name: "default")
    public static let dark = Theme(name: "dark", isDark: true)
}
