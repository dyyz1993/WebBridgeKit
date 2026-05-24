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

// MARK: - Theme Animation

@available(*, deprecated, message: "Use ThemeTokens.Animation")
public enum ThemeAnimation {
    @available(*, deprecated, message: "Use ThemeTokens.Animation.normal.duration")
    public static let standardDuration: TimeInterval = 0.25
    @available(*, deprecated, message: "Use ThemeTokens.Animation.spring.duration")
    public static let springDuration: TimeInterval = 0.3
    @available(*, deprecated, message: "Use ThemeTokens.Animation.slow.duration")
    public static let slowDuration: TimeInterval = 0.5
    @available(*, deprecated, message: "Use ThemeTokens.Animation.spring.damping")
    public static let springDamping: CGFloat = 0.8

    @available(*, deprecated, message: "Use UIView.animate(withDuration: ThemeTokens.Animation.normal.duration, ...)")
    public static func standard(animations: @escaping () -> Void, completion: ((Bool) -> Void)? = nil) {
        UIView.animate(withDuration: standardDuration, animations: animations, completion: completion)
    }

    @available(*, deprecated, message: "Use UIView.animate(withDuration: ThemeTokens.Animation.spring.duration, usingSpringWithDamping: ThemeTokens.Animation.spring.damping, ...)")
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

    @available(*, deprecated, message: "Use UIView.animate(withDuration: ThemeTokens.Animation.slow.duration, ...)")
    public static func slow(animations: @escaping () -> Void, completion: ((Bool) -> Void)? = nil) {
        UIView.animate(withDuration: slowDuration, animations: animations, completion: completion)
    }
}

// MARK: - Legacy Theme

public struct Theme: Sendable {
    public let name: String
    public let isDark: Bool

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
