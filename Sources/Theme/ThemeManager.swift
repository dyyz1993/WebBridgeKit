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

    public func getTheme() async -> Theme {
        let isDark: Bool
        if currentMode == .dark {
            isDark = true
        } else if currentMode == .system {
            isDark = await MainActor.run { UIScreen.main.traitCollection.userInterfaceStyle == .dark }
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
        window.tintColor = ThemeTokens.Color.primary
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
        navAppearance.backgroundColor = ThemeTokens.Color.navigationBarBackground
        navAppearance.titleTextAttributes = [.foregroundColor: ThemeTokens.Color.text]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: ThemeTokens.Color.text]

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = ThemeTokens.Color.tabBarBackground

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

// MARK: - Theme Colors (Deprecated — delegates to ThemeTokens.Color)

@available(*, deprecated, message: "Use ThemeTokens.Color.* instead. ThemeColors is kept for backward compatibility and now delegates to ThemeTokens.Color.")
public struct ThemeColors: Sendable {
    public var primary: UIColor { ThemeTokens.Color.primary }
    public var secondary: UIColor { ThemeTokens.Color.secondary }
    public var background: UIColor { ThemeTokens.Color.background }
    public var surface: UIColor { ThemeTokens.Color.surface }
    public var text: UIColor { ThemeTokens.Color.text }
    public var textSecondary: UIColor { ThemeTokens.Color.textSecondary }
    public var border: UIColor { ThemeTokens.Color.border }
    public var navigationBarBackground: UIColor { ThemeTokens.Color.navigationBarBackground }
    public var navigationBarTitle: UIColor { ThemeTokens.Color.navigationBarTitle }
    public var tabBarBackground: UIColor { ThemeTokens.Color.tabBarBackground }
    public var success: UIColor { ThemeTokens.Color.success }
    public var warning: UIColor { ThemeTokens.Color.warning }
    public var error: UIColor { ThemeTokens.Color.error }
    public var info: UIColor { ThemeTokens.Color.info }
    public var cardBackground: UIColor { ThemeTokens.Color.cardBackground }
    public var gradientStart: UIColor { ThemeTokens.Color.gradientStart }
    public var gradientEnd: UIColor { ThemeTokens.Color.gradientEnd }
    public var badgeBackground: UIColor { ThemeTokens.Color.badgeBackground }
    public var badgeText: UIColor { ThemeTokens.Color.badgeText }
    public var divider: UIColor { ThemeTokens.Color.divider }
    public var fabBackground: UIColor { ThemeTokens.Color.fabBackground }

    public init() {}

    @available(*, deprecated, message: "Use ThemeTokens.Color.current (singleton) instead")
    public static let current = ThemeColors()

    @available(*, deprecated, message: "Use ThemeTokens.Color.current (singleton) instead")
    public static let `default` = ThemeColors()
}

// MARK: - Theme Typography (Deprecated — delegates to ThemeTokens.Typography)

@available(*, deprecated, message: "Use ThemeTokens.Typography.* instead")
public struct ThemeTypography: Sendable {
    public var largeTitle: UIFont { ThemeTokens.Typography.largeTitle }
    public var title1: UIFont { ThemeTokens.Typography.title1 }
    public var title2: UIFont { ThemeTokens.Typography.title3 }
    public var headline: UIFont { ThemeTokens.Typography.headline }
    public var body: UIFont { ThemeTokens.Typography.body }
    public var caption1: UIFont { ThemeTokens.Typography.caption1 }
    public var caption2: UIFont { ThemeTokens.Typography.caption2 }

    public init() {}

    @available(*, deprecated, message: "Use ThemeTokens.Typography.* instead")
    public static let current = ThemeTypography()
}

// MARK: - Legacy Theme Fonts (Deprecated — delegates to ThemeTokens.Typography)

@available(*, deprecated, message: "Use ThemeTokens.Typography.* instead")
public struct ThemeFonts: Sendable {
    public var title: UIFont { ThemeTokens.Typography.largeTitle }
    public var headline: UIFont { ThemeTokens.Typography.headline }
    public var body: UIFont { ThemeTokens.Typography.body }
    public var caption: UIFont { ThemeTokens.Typography.caption1 }
    public var button: UIFont { ThemeTokens.Typography.callout }

    public init() {}

    @available(*, deprecated, message: "Use ThemeTokens.Typography.* instead")
    public static let `default` = ThemeFonts()
}

// MARK: - Theme Spacing (Deprecated — delegates to ThemeTokens.Spacing)

@available(*, deprecated, message: "Use ThemeTokens.Spacing.* instead")
public struct ThemeSpacing: Sendable {
    public var xs: CGFloat { ThemeTokens.Spacing.xs }
    public var sm: CGFloat { ThemeTokens.Spacing.sm }
    public var md: CGFloat { ThemeTokens.Spacing.md }
    public var lg: CGFloat { ThemeTokens.Spacing.lg }
    public var xl: CGFloat { ThemeTokens.Spacing.xl }

    public init() {}

    @available(*, deprecated, message: "Use ThemeTokens.Spacing.* instead")
    public static let `default` = ThemeSpacing()
}

// MARK: - Theme CornerRadius (Deprecated — delegates to ThemeTokens.CornerRadius)

@available(*, deprecated, message: "Use ThemeTokens.CornerRadius.* instead")
public struct ThemeCornerRadius: Sendable {
    public var sm: CGFloat { ThemeTokens.CornerRadius.sm }
    public var md: CGFloat { ThemeTokens.CornerRadius.md }
    public var lg: CGFloat { ThemeTokens.CornerRadius.lg }
    public var full: CGFloat { ThemeTokens.CornerRadius.full }

    public init() {}

    @available(*, deprecated, message: "Use ThemeTokens.CornerRadius.* instead")
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

    @available(*, deprecated, message: "Use ThemeTokens.Color.* instead")
    public var colors: ThemeColors { ThemeColors() }

    @available(*, deprecated, message: "Use ThemeTokens.Typography.* instead")
    public var fonts: ThemeFonts { ThemeFonts() }

    @available(*, deprecated, message: "Use ThemeTokens.Spacing.* instead")
    public var spacing: ThemeSpacing { ThemeSpacing() }

    @available(*, deprecated, message: "Use ThemeTokens.CornerRadius.* instead")
    public var cornerRadius: ThemeCornerRadius { ThemeCornerRadius() }

    public init(
        name: String,
        isDark: Bool = false
    ) {
        self.name = name
        self.isDark = isDark
    }

    public static let `default` = Theme(name: "default")
    public static let dark = Theme(name: "dark", isDark: true)
}
