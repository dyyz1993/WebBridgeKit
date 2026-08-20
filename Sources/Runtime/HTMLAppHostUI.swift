//
//  HTMLAppHostUI.swift
//  WebBridgeKit
//

import UIKit

/// Lets a host product provide its own managed-PWA settings journey without
/// coupling the reusable browser container to product-specific screens.
public protocol HTMLAppSettingsViewControllerProviding: AnyObject {
    func makeHTMLAppSettingsViewController(appID: String, documentURL: URL?) -> UIViewController?
}

public enum HTMLAppHostUI {
    public static weak var settingsViewControllerProvider: HTMLAppSettingsViewControllerProviding?
}
