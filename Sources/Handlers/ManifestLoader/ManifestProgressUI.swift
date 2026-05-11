//
//  ManifestProgressUI.swift
//  WebBridgeKit
//
//  Progress UI & WebView integration for PersistentManifestLoader (split from main file).
//

import Foundation
import WebKit
import UIKit

// MARK: - Progress Modal & WebView

extension PersistentManifestLoader {

    /// 加载 HTML 到 WebView
    func loadHTML(_ html: String, cacheID: String, in webView: WKWebView) async throws {
        guard let entryURL = URL(string: "\(scheme)://\(cacheID)/index.html") else {
            throw LoaderError.invalidManifestFormat
        }

        NSLog("🌐 [PersistentManifestLoader] 加载入口页面: %@", entryURL.absoluteString)

        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                webView.load(URLRequest(url: entryURL))
                continuation.resume()
            }
        }
    }

    /// 注册 manifest 到 URL Scheme Handler
    func registerManifest(_ manifest: WebManifest, for cacheID: String, in webView: WKWebView) async {
        await MainActor.run {
            if let schemeHandler = webView.configuration.urlSchemeHandler(forURLScheme: scheme) as? ManifestURLSchemeHandler {
                schemeHandler.registerManifest(forPage: cacheID, manifest: manifest.resources)
            }
        }
    }

    // MARK: - Progress Modal

    @MainActor
    func showProgressModal(
        from viewController: UIViewController,
        description: String,
        totalResources: Int
    ) -> FullScreenProgressViewController {
        let modal = FullScreenProgressViewController(totalResources: totalResources)
        modal.modalPresentationStyle = .fullScreen
        viewController.present(modal, animated: false)

        self.progressModal = modal
        return modal
    }

    @MainActor
    func dismissProgressModal() async {
        progressModal?.dismissWithAnimation {
            // Animation complete
        }
        progressModal = nil
    }
}
