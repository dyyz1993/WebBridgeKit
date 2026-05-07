import Foundation

public enum L10n {
    public static func tr(_ key: String, tableName: String = "Localizable", bundle: Bundle = .main) -> String {
        return NSLocalizedString(key, tableName: tableName, bundle: bundle, value: key, comment: "")
    }

    public static func tr(_ key: String, _ args: CVarArg..., tableName: String = "Localizable", bundle: Bundle = .main) -> String {
        let format = NSLocalizedString(key, tableName: tableName, bundle: bundle, value: key, comment: "")
        return String(format: format, arguments: args)
    }
}
