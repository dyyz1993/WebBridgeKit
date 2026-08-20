import Foundation

enum SettingsPreferenceKeys {
    static let rememberLastApp = "settings.rememberLastApp"
    static let lastOpenedURL = "settings.lastOpenedURL"
    static let appearanceMode = "settings.appearanceMode"

    private static let legacyRememberLastApp = "EnableLastAppMemory"
    private static let legacyLastOpenedURL = "LastOpenedURL"

    static func migrateLegacyValuesIfNeeded(defaults: UserDefaults = .standard) {
        if defaults.object(forKey: rememberLastApp) == nil,
           defaults.object(forKey: legacyRememberLastApp) != nil {
            defaults.set(defaults.bool(forKey: legacyRememberLastApp), forKey: rememberLastApp)
        }

        if defaults.string(forKey: lastOpenedURL) == nil,
           let legacyURL = defaults.string(forKey: legacyLastOpenedURL) {
            defaults.set(legacyURL, forKey: lastOpenedURL)
        }
    }
}
