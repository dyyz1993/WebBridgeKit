import AVFoundation
import RxSwift
import SwiftUI
import UIKit
import WebBridgeKit

final class GatewayConfigurationViewController: UIViewController {
    private let allowsDevelopmentMode = _isDebugAssertConfiguration()
    private lazy var registry = HTMLAppGatewayRegistry(allowsDevelopmentHTTP: allowsDevelopmentMode)
    private lazy var onboardingService = HTMLAppGatewayOnboardingService(
        gatewayRegistry: registry,
        allowsDevelopmentMode: allowsDevelopmentMode
    )
    private lazy var viewModel = GatewayManagementViewModel(
        registry: registry,
        onboardingService: onboardingService,
        allowsDevelopmentMode: allowsDevelopmentMode
    )
    private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = text("gateway.title", "网关管理")
        view.backgroundColor = ThemeTokens.Color.background
        let content = GatewayImportView(
            viewModel: viewModel,
            scan: { [weak self] in self?.scanGateway() },
            paste: { [weak self] in self?.pasteGateway() }
        )
        let host = UIHostingController(rootView: content)
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        view.accessibilityIdentifier = "gateway.table"

        if ProcessInfo.processInfo.arguments.contains("--UITesting"),
           let payload = ProcessInfo.processInfo.environment["WBK_GATEWAY_UI_PAYLOAD"] {
            viewModel.payload = payload
        }
    }

    private func pasteGateway() {
        if let payload = UIPasteboard.general.string, !payload.isEmpty {
            viewModel.payload = payload
        }
    }

    private func scanGateway() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .denied || status == .restricted {
            showCameraFallback()
            return
        }
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.presentScanner()
                    } else {
                        self?.showCameraFallback()
                    }
                }
            }
            return
        }
        presentScanner()
    }

    private func presentScanner() {
        let scanner = QRScannerViewController(configuration: .init(
            showScanRegionOverlay: true,
            showCloseButton: true,
            tipText: text("gateway.scan.tip", "扫描 WebBridgeKit 网关配置码"),
            autoDismiss: true
        ))
        scanner.scannerDidSuccess.subscribe(onNext: { [weak self] payload in
            self?.navigationController?.popViewController(animated: true)
            self?.viewModel.usePayload(payload)
        }).disposed(by: disposeBag)
        navigationController?.pushViewController(scanner, animated: true)
    }

    private func showCameraFallback() {
        let alert = UIAlertController(
            title: text("gateway.camera.denied.title", "无法使用相机"),
            message: text("gateway.camera.denied.message", "你仍可粘贴部署者提供的网关配置，或前往系统设置允许相机访问。"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: text("gateway.paste", "粘贴配置"), style: .default) { [weak self] _ in
            self?.pasteGateway()
        })
        alert.addAction(UIAlertAction(title: text("gateway.settings", "系统设置"), style: .default) { _ in
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        })
        alert.addAction(UIAlertAction(title: text("gateway.cancel", "取消"), style: .cancel))
        present(alert, animated: true)
    }

    private func text(_ key: String, _ fallback: String) -> String {
        NSLocalizedString(key, tableName: "Localizable", bundle: .main, value: fallback, comment: "")
    }
}
