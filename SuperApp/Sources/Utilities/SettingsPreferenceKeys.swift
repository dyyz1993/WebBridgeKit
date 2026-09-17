import Foundation

enum SettingsPreferenceKeys {
    static let defaultStartupAppID = "settings.defaultStartupAppID"
    static let appearanceMode = "settings.appearanceMode"

    private static let startupAppMigrationCompleted = "settings.defaultStartupAppMigrationCompleted"
    private static let previousRememberLastApp = "settings.rememberLastApp"
    private static let previousLastOpenedURL = "settings.lastOpenedURL"
    private static let legacyRememberLastApp = "EnableLastAppMemory"
    private static let legacyLastOpenedURL = "LastOpenedURL"

    /// Drel used to retain the complete URL of the last web page. That could
    /// preserve transient routes or query parameters, so it is intentionally
    /// not migrated. The replacement stores only a trusted manifest app ID.
    static func removeLegacyLastURLPreferencesIfNeeded(defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: startupAppMigrationCompleted) else { return }
        [previousRememberLastApp, previousLastOpenedURL, legacyRememberLastApp, legacyLastOpenedURL]
            .forEach(defaults.removeObject(forKey:))
        defaults.set(true, forKey: startupAppMigrationCompleted)
    }
}
