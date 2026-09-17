import Foundation
import UIKit
import WebKit

/// Build-time capability boundary for the Drel Store product.
///
/// The reusable WebBridgeKit SDK remains bridge-capable by default. Its Release
/// build inside Drel sets `DREL_CONTAINER_ONLY`, which makes a remote webpage a
/// plain WKWebView client: it receives read-only runtime metadata, but no bridge
/// script, message handler, or privileged launch-context JavaScript injection.
public enum DrelContainerBuildPolicy {
    #if DREL_CONTAINER_ONLY
    public static let nativeBridgeEnabled = false
    #else
    public static let nativeBridgeEnabled = true
    #endif
}

/// Resolves mutually exclusive cold-launch destinations before any delayed UI
/// work is scheduled. An explicit notification or a configured default app
/// owns the launch; a stale recent browser session must never replace either.
public enum DrelStartupNavigationPolicy {
    public static func shouldRestoreRecentSession(
        isUITesting: Bool,
        explicitlyEnablesUITestRestore: Bool,
        launchedFromRemoteNotification: Bool,
        hasDefaultStartupApp: Bool
    ) -> Bool {
        (!isUITesting || explicitlyEnablesUITestRestore)
            && !launchedFromRemoteNotification
            && !hasDefaultStartupApp
    }
}

/// Stable, read-only web runtime contract shared by every Drel web container.
///
/// The user-agent advertises immutable product/capability versions. Dynamic
/// state (local-package execution, presentation mode and viewport size) lives
/// on `window.DrelRuntime`, so rotation, keyboard and future tab containers do
/// not make the user-agent stale.
public enum DrelWebRuntimeContract {
    public static let containerProtocolVersion = "1"
    public static let offlinePackageProtocolVersion = "1"
    public static let bridgeProtocolVersion = "1.0"
    public static let webBridgeKitProtocolVersion = "1"

    public static func applicationNameForUserAgent(
        appVersion: String,
        buildNumber: String,
        screenWidth: Int,
        screenHeight: Int,
        displayScale: CGFloat,
        bridgeEnabled: Bool
    ) -> String {
        let scale = displayScale.rounded() == displayScale
            ? String(Int(displayScale))
            : String(format: "%.2f", Double(displayScale))
        let bridgeVersion = bridgeEnabled ? bridgeProtocolVersion : "0"
        return "Drel/\(appVersion) (Build/\(buildNumber); Screen/\(screenWidth)x\(screenHeight); DPR/\(scale); Container/\(containerProtocolVersion); Offline/\(offlinePackageProtocolVersion); Bridge/\(bridgeVersion)) WebBridgeKit/\(webBridgeKitProtocolVersion)"
    }

    public static func runtimeBootstrapScript(
        appVersion: String,
        buildNumber: String,
        bridgeEnabled: Bool
    ) -> String {
        let bridgeVersion = bridgeEnabled ? bridgeProtocolVersion : "0"
        return """
        (() => {
          const runtime = {};
          const isOfflinePackage = () => location.protocol === 'file:' || location.protocol === 'drel-app:';
          const liveScreen = () => Object.freeze({
            width: window.screen.width,
            height: window.screen.height,
            devicePixelRatio: window.devicePixelRatio
          });
          const liveViewport = () => Object.freeze({
            width: window.innerWidth,
            height: window.innerHeight,
            visualWidth: window.visualViewport ? window.visualViewport.width : window.innerWidth,
            visualHeight: window.visualViewport ? window.visualViewport.height : window.innerHeight
          });
          Object.defineProperties(runtime, {
            appVersion: { value: '\(escapedForSingleQuotedJavaScript(appVersion))', enumerable: true },
            buildNumber: { value: '\(escapedForSingleQuotedJavaScript(buildNumber))', enumerable: true },
            containerVersion: { value: '\(containerProtocolVersion)', enumerable: true },
            offlinePackageVersion: { value: '\(offlinePackageProtocolVersion)', enumerable: true },
            bridgeVersion: { value: '\(bridgeVersion)', enumerable: true },
            webBridgeKitVersion: { value: '\(webBridgeKitProtocolVersion)', enumerable: true },
            runtime: { get: () => isOfflinePackage() ? 'offline-package' : 'web', enumerable: true },
            isOfflinePackage: { get: isOfflinePackage, enumerable: true },
            presentation: { get: () => window.__drelPresentation || 'normal', enumerable: true },
            screen: { get: liveScreen, enumerable: true },
            viewport: { get: liveViewport, enumerable: true }
          });
          Object.freeze(runtime);
          Object.defineProperty(window, 'DrelRuntime', {
            value: runtime,
            writable: false,
            configurable: false,
            enumerable: true
          });
        })();
        """
    }

    public static func presentationScript(for displayMode: WebBrowserParams.DisplayMode) -> String {
        "window.__drelPresentation = '\(displayMode.rawValue)';"
    }

    /// Must run before WKWebView creation so the very first navigation already
    /// carries the Drel product/version token.
    @MainActor
    public static func install(on configuration: WKWebViewConfiguration, bundle: Bundle = .main) {
        let info = bundle.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        let screen = UIScreen.main.bounds.size
        configuration.applicationNameForUserAgent = applicationNameForUserAgent(
            appVersion: version,
            buildNumber: build,
            screenWidth: Int(screen.width),
            screenHeight: Int(screen.height),
            displayScale: UIScreen.main.scale,
            bridgeEnabled: DrelContainerBuildPolicy.nativeBridgeEnabled
        )
        configuration.userContentController.addUserScript(WKUserScript(
            source: runtimeBootstrapScript(
                appVersion: version,
                buildNumber: build,
                bridgeEnabled: DrelContainerBuildPolicy.nativeBridgeEnabled
            ),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
    }

    private static func escapedForSingleQuotedJavaScript(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
}
