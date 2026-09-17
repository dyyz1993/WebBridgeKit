//
//  MessageDetailViewController+LinkMenu.swift
//  SuperApp
//
//  Long-press link menu for the Markdown message detail webview.
//

import UIKit
import WebKit
import WebBridgeKit

extension MessageDetailViewController: WKUIDelegate {

    /// Long-press on any recognized link in the Markdown body — explicit
    /// `[text](url)` links, angle autolinks, and bare URLs autolinked from
    /// plain text or code blocks — opens a menu whose "open link" action uses
    /// the shared browser with a normal (non-fullscreen) presentation, so the
    /// reader can check the page and come straight back to the message.
    func webView(
        _ webView: WKWebView,
        contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo,
        completionHandler: @escaping (UIContextMenuConfiguration?) -> Void
    ) {
        guard let url = elementInfo.linkURL,
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" || scheme == "drel" else {
            completionHandler(nil)
            return
        }

        let configuration = UIContextMenuConfiguration(
            identifier: nil,
            previewProvider: nil
        ) { [weak self] _ in
            guard let self else { return UIMenu() }
            let openAction = UIAction(
                title: L10n.tr("message.detail.open_link"),
                image: LucideIcon.link.templateImage(pointSize: ThemeTokens.Icons.Sizes.md)
            ) { [weak self] _ in
                guard let self else { return }
                if url.scheme?.lowercased() == "drel" {
                    DrelExternalAppLinkOpener.openIfAppLink(url, from: self)
                } else {
                    self.openRecognizedLink(url)
                }
            }
            let copyAction = UIAction(
                title: L10n.tr("message.detail.copy_link"),
                image: LucideIcon.copy.templateImage(pointSize: ThemeTokens.Icons.Sizes.md)
            ) { _ in
                UIPasteboard.general.string = url.absoluteString
                HUDService.shared.showSuccess(withStatus: L10n.tr("message.detail.copied"))
            }
            return UIMenu(children: [openAction, copyAction])
        }
        completionHandler(configuration)
    }

    /// Normal mode by design: links discovered inside a message body are
    /// reference material, so the browser pushes with a back button instead
    /// of taking over the full screen.
    private func openRecognizedLink(_ url: URL) {
        WebBrowserManager.shared.openBrowser(
            url: url,
            params: DrelMessageOpenPolicy.browserParams(
                for: url,
                mode: .normal,
                payload: message.payload.userInfo,
                useManifestLoader: false
            ),
            from: self
        )
    }
}
