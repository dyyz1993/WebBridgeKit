import Foundation

/// Explicit host-app options for the starter target.
///
/// Keep credentials outside source control (for example in Keychain or an
/// injected runtime configuration) and pass them in when constructing this
/// value. The safe defaults initialize only WebBridgeKit itself.
struct AppTemplateConfiguration {
    let initialPWAURL: URL?
    let barkServerURL: String
    let barkDeviceKey: String?
    /// Starts the local diagnostic server in DEBUG builds only.
    let localDiagnosticsPort: UInt16?
    let enablesSignedCommandValidation: Bool

    init(
        initialPWAURL: URL? = nil,
        barkServerURL: String = "https://api.day.app",
        barkDeviceKey: String? = nil,
        localDiagnosticsPort: UInt16? = nil,
        enablesSignedCommandValidation: Bool = false
    ) {
        self.initialPWAURL = initialPWAURL
        self.barkServerURL = barkServerURL
        self.barkDeviceKey = barkDeviceKey?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.localDiagnosticsPort = localDiagnosticsPort
        self.enablesSignedCommandValidation = enablesSignedCommandValidation
    }

    static let safeDefaults = AppTemplateConfiguration()
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
