import UIKit

/// Theme management system for consistent UI styling
public actor ThemeManager {
    public static let shared = ThemeManager()

    private var currentTheme: Theme
    private var observers: [(@Sendable (Theme) -> Void)] = []

    public init(theme: Theme = .default) {
        self.currentTheme = theme
    }

    /// Get current theme
    public func getTheme() -> Theme {
        currentTheme
    }

    /// Apply a new theme
    public func apply(_ theme: Theme) {
        currentTheme = theme
        notifyObservers()
    }

    /// Register for theme changes
    public func observe(_ handler: @escaping @Sendable (Theme) -> Void) {
        observers.append(handler)
    }

    /// Apply theme to UIKit components on main thread
    @MainActor
    public func applyToWindow(_ window: UIWindow) async {
        let theme = await getTheme()
        Self.applyTheme(theme, to: window)
    }

    @MainActor
    public static func applyTheme(_ theme: Theme, to window: UIWindow) {
        window.tintColor = theme.colors.primary
        window.overrideUserInterfaceStyle = theme.isDark ? .dark : .light

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = theme.colors.navigationBarBackground
        navAppearance.titleTextAttributes = [.foregroundColor: theme.colors.navigationBarTitle]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: theme.colors.navigationBarTitle]

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = theme.colors.tabBarBackground

        UITabBar.appearance().standardAppearance = tabAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        }
    }

    private func notifyObservers() {
        for observer in observers {
            observer(currentTheme)
        }
    }
}

// MARK: - Theme

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
        colors: ThemeColors = .default,
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
    public static let dark = Theme(name: "dark", isDark: true, colors: .dark)
}

// MARK: - Theme Colors

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
        info: UIColor = .systemBlue
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
    }

    public static let `default` = ThemeColors()
    public static let dark = ThemeColors(
        primary: .systemBlue,
        background: .systemBackground,
        surface: .secondarySystemBackground,
        navigationBarBackground: UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1),
        tabBarBackground: UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)
    )
}

// MARK: - Theme Fonts

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
