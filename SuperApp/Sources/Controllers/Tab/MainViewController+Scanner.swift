import UIKit
import WebBridgeKit

extension MainViewController {

    func handleScannedResult(url: URL?, rawString: String?) {
        Log.debug("Handling scanned result - URL: \(url?.absoluteString ?? "nil"), Raw: \(rawString ?? "nil")", category: .ui)
        if let url = url {
            if url.scheme == "wb-app" {
                handleCustomProtocol(url)
                return
            }
            if url.pathExtension == "json" || url.absoluteString.contains("manifest") {
                loadAndCacheManifest(url)
            } else {
                openURL(url)
            }
            return
        }
        if let raw = rawString {
            if raw.starts(with: "wb-app://") {
                if let customUrl = URL(string: raw) {
                    handleCustomProtocol(customUrl)
                } else {
                    showAlert(title: L10n.tr("home.alert.protocol_error"), message: L10n.tr("home.alert.protocol_error_message", raw))
                }
            } else {
                showAlert(title: L10n.tr("home.alert.invalid_content"), message: L10n.tr("home.alert.invalid_content_message", raw))
            }
        }
    }

    func handleCustomProtocol(_ url: URL) {
        Log.debug("Handling custom protocol: \(url.absoluteString)", category: .ui)
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        if url.host == "load" {
            if let targetUrlString = components.queryItems?.first(where: { $0.name == "url" })?.value,
               let targetUrl = URL(string: targetUrlString) {
                handleScannedResult(url: targetUrl, rawString: targetUrlString)
            }
        } else if url.host == "open" {
            if let targetUrlString = components.queryItems?.first(where: { $0.name == "url" })?.value,
               let targetUrl = URL(string: targetUrlString) {
                openURL(targetUrl)
            }
        }
    }

    func loadAndCacheManifest(_ url: URL) {
        loadingView.startLoading(message: L10n.tr("home.manifest.loading"))
        Task {
            do {
                let manifest = try await PersistentManifestLoader.shared.fetchManifest(from: url)
                await MainActor.run {
                    self.loadingView.stopLoading()
                    self.showAlert(title: L10n.tr("home.manifest.success_title"), message: L10n.tr("home.manifest.success_message_format", manifest.name ?? L10n.tr("common.unknown")))
                    self.viewModel.refreshData()
                }
            } catch {
                await MainActor.run {
                    self.loadingView.stopLoading()
                    Log.error("Failed to load manifest: \(error)", category: .ui)
                    self.openURL(url)
                }
            }
        }
    }

    @objc func openScanner() {
        let config = QRScannerViewController.Configuration(
            showScanRegionOverlay: true,
            showCloseButton: true,
            tipText: L10n.tr("home.scanner.tip"),
            enableBase64Decoding: true,
            autoDismiss: false
        )
        let scannerVC = QRScannerViewController(configuration: config)
        scannerVC.scannerDidSuccess
            .subscribe(onNext: { [weak self, weak scannerVC] result in
                guard let self = self else { return }
                let url = URL(string: result)
                if let scanner = scannerVC, let nav = self.navigationController, nav.viewControllers.contains(scanner) {
                    CATransaction.begin()
                    CATransaction.setCompletionBlock {
                        self.handleScannedResult(url: url, rawString: result)
                    }
                    nav.popViewController(animated: true)
                    CATransaction.commit()
                } else {
                    scannerVC?.dismiss(animated: true) {
                        self.handleScannedResult(url: url, rawString: result)
                    }
                }
            })
            .disposed(by: rx)
        navigationController?.pushViewController(scannerVC, animated: true)
    }
}
