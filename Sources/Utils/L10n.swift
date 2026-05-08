import Foundation

public enum L10n {

    private static var _resourceBundle: Bundle?

    private static func resolveBundle() -> Bundle {
        if let cached = _resourceBundle { return cached }

        if let url = Bundle.main.url(forResource: "Localizable", withExtension: "strings"),
           FileManager.default.fileExists(atPath: url.path) {
            _resourceBundle = Bundle.main
            return Bundle.main
        }

        let allBundles = Bundle.allBundles + Bundle.allFrameworks
        for bundle in allBundles {
            if let url = bundle.url(forResource: "Localizable", withExtension: "strings"),
               FileManager.default.fileExists(atPath: url.path) {
                _resourceBundle = bundle
                return bundle
            }
        }

        _resourceBundle = Bundle.main
        return Bundle.main
    }

    public static func tr(_ key: String, tableName: String = "Localizable", bundle: Bundle? = nil) -> String {
        let target = bundle ?? resolveBundle()
        return NSLocalizedString(key, tableName: tableName, bundle: target, value: key, comment: "")
    }

    public static func tr(_ key: String, _ args: CVarArg..., tableName: String = "Localizable", bundle: Bundle? = nil) -> String {
        let target = bundle ?? resolveBundle()
        let format = NSLocalizedString(key, tableName: tableName, bundle: target, value: key, comment: "")
        return String(format: format, arguments: args)
    }
}
