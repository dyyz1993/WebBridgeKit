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

    /// 加载 HTML 到 WebView - 使用 loadFileURL 直接加载本地缓存文件
    func loadHTML(_ html: String, cacheID: String, in webView: WKWebView) async throws {
        let cacheDir = cacheDirectory.appendingPathComponent(cacheID)
        let indexFile = cacheDir.appendingPathComponent("index.html")

        NSLog("[WEB] [ProgressUI] loadFileURL: %@, readAccessTo: %@", indexFile.path, cacheDir.path)

        guard FileManager.default.fileExists(atPath: indexFile.path) else {
            NSLog("[WEB] [ProgressUI] index.html NOT FOUND at: %@, falling back to loadHTMLString", indexFile.path)
            guard let baseURL = URL(string: "\(scheme)://\(cacheID)/") else {
                throw LoaderError.invalidManifestFormat
            }
            try await MainActor.run {
                webView.loadHTMLString(html, baseURL: baseURL)
            }
            return
        }

        try await MainActor.run {
            webView.loadFileURL(indexFile, allowingReadAccessTo: cacheDir)
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
