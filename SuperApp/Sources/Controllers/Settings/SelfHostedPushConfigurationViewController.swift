import AVFoundation
import RxSwift
import UIKit
import WebBridgeKit

/// Optional self-hosted encrypted push setup. This is deliberately separate
/// from HTML-app gateway management: it configures only a direct APNs relay
/// chosen by the user and grants it no native web capabilities.
final class SelfHostedPushConfigurationViewController: UIViewController {
    private let statusLabel = UILabel()
    private let configureButton = UIButton(type: .system)
    private let scanButton = UIButton(type: .system)
    private let copyDeveloperConfigButton = UIButton(type: .system)
    private let resetAddressButton = UIButton(type: .system)
    private let removeButton = UIButton(type: .system)
    private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "自定义推送"
        view.backgroundColor = ThemeTokens.Color.background
        setupUI()
        refresh()
    }

    private func setupUI() {
        let description = UILabel()
        description.text = "可选：接入你自己部署的 Drel 直连推送，或扫描 Drel 托管加密推送配置码。直连服务可读取其收到的正文；托管加密服务只接收发送端加密后的信封。官方 Drel 通道始终保留，不会被这里的配置替换。"
        description.numberOfLines = 0
        description.font = ThemeTokens.Typography.body
        description.textColor = ThemeTokens.Color.textSecondary

        statusLabel.numberOfLines = 0
        statusLabel.font = ThemeTokens.Typography.body
        statusLabel.textColor = ThemeTokens.Color.text

        configureButton.setTitle("粘贴服务器地址或配置码", for: .normal)
        scanButton.setTitle("扫描配置码", for: .normal)
        copyDeveloperConfigButton.setTitle("复制开发者发送配置", for: .normal)
        resetAddressButton.setTitle("重置推送地址", for: .normal)
        removeButton.setTitle("移除自托管服务器", for: .normal)
        removeButton.setTitleColor(ThemeTokens.Color.error, for: .normal)
        [configureButton, scanButton, copyDeveloperConfigButton, resetAddressButton, removeButton].forEach {
            $0.heightAnchor.constraint(equalToConstant: 46).isActive = true
            $0.backgroundColor = ThemeTokens.Color.cardBackground
            $0.layer.cornerRadius = ThemeTokens.CornerRadius.md
        }
        configureButton.addTarget(self, action: #selector(pasteTapped), for: .touchUpInside)
        scanButton.addTarget(self, action: #selector(scanTapped), for: .touchUpInside)
        copyDeveloperConfigButton.addTarget(self, action: #selector(copyDeveloperConfigTapped), for: .touchUpInside)
        resetAddressButton.addTarget(self, action: #selector(resetAddressTapped), for: .touchUpInside)
        removeButton.addTarget(self, action: #selector(removeTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [description, statusLabel, configureButton, scanButton, copyDeveloperConfigButton, resetAddressButton, removeButton])
        stack.axis = .vertical; stack.spacing = 16
        view.addSubview(stack); stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    private func refresh() {
        if let config = SelfHostedPushConfiguration.load() {
            statusLabel.text = statusText(for: config)
            copyDeveloperConfigButton.isHidden = false
            resetAddressButton.isHidden = false
            removeButton.isHidden = false
        } else {
            statusLabel.text = "尚未配置。官方 Drel 推送仍可正常使用。"
            copyDeveloperConfigButton.isHidden = true
            resetAddressButton.isHidden = true
            removeButton.isHidden = true
        }
    }

    @objc private func pasteTapped() {
        let alert = UIAlertController(title: "连接推送服务", message: "粘贴自托管 HTTPS 地址，或粘贴部署页面生成的 drel:// 配置码。", preferredStyle: .alert)
        alert.addTextField { $0.text = UIPasteboard.general.string; $0.autocapitalizationType = .none; $0.autocorrectionType = .no }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "连接", style: .default) { [weak self, weak alert] _ in
            self?.activate(alert?.textFields?.first?.text ?? "")
        })
        present(alert, animated: true)
    }

    @objc private func scanTapped() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        guard status != .denied && status != .restricted else { pasteTapped(); return }
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async { granted ? self?.presentScanner() : self?.pasteTapped() }
            }
        } else { presentScanner() }
    }

    private func presentScanner() {
        let scanner = QRScannerViewController(configuration: .init(showScanRegionOverlay: true, showCloseButton: true, tipText: "扫描 Drel 推送服务配置码", autoDismiss: true))
        scanner.scannerDidSuccess.subscribe(onNext: { [weak self] payload in
            self?.navigationController?.popViewController(animated: true)
            self?.activate(payload)
        }).disposed(by: disposeBag)
        navigationController?.pushViewController(scanner, animated: true)
    }

    @objc private func removeTapped() {
        guard let configuration = SelfHostedPushConfiguration.load() else { return }
        removeButton.isEnabled = false
        PushNotificationManager.shared.revokeSelfHostedPush(configuration) { [weak self] result in
            // Local key removal is unconditional: a server that is offline
            // during unregister must still lose the ability to send content
            // this installation can decrypt.
            SelfHostedPushCrypto.discardIdentity()
            SelfHostedPushConfiguration.remove()
            DispatchQueue.main.async {
                self?.removeButton.isEnabled = true
                self?.refresh()
                if case .failure = result {
                    self?.showError("已移除本机密钥和配置。原服务器暂时无法撤销，请在它恢复后清理该设备登记。")
                }
            }
        }
    }

    @objc private func resetAddressTapped() {
        guard let configuration = SelfHostedPushConfiguration.load() else { return }
        let serverURL = configuration.serverURL
        resetAddressButton.isEnabled = false
        PushNotificationManager.shared.revokeSelfHostedPush(configuration) { [weak self] _ in
            // A new identity and capability address are created after the old
            // registration is removed. If the network is down, local removal
            // still prevents this installation from decrypting old envelopes.
            SelfHostedPushCrypto.discardIdentity()
            SelfHostedPushConfiguration.remove()
            DispatchQueue.main.async {
                self?.resetAddressButton.isEnabled = true
                self?.activate(serverURL)
            }
        }
    }

    @objc private func copyDeveloperConfigTapped() {
        guard let configuration = SelfHostedPushConfiguration.load() else { return }
        let serverURL = configuration.serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let payload = developerConfiguration(for: configuration, serverURL: serverURL)
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]),
              let text = String(data: data, encoding: .utf8) else { return }
        UIPasteboard.general.string = text
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
        let alert = UIAlertController(
            title: "已复制开发者配置",
            message: "其中的 deviceKey 是本机的推送能力地址；泄露后可在此页重置。请只交给可信的发送端。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
    }

    private func activate(_ payload: String) {
        PushNotificationManager.shared.activateSelfHostedPush(importPayload: payload) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .ready: self?.refresh()
                case .denied: self?.showError("请在系统设置中允许通知后再连接自托管服务器。")
                case .failed(let message): self?.showError(message)
                }
            }
        }
    }

    private func statusText(for configuration: SelfHostedPushConfiguration) -> String {
        let serverURL = configuration.serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        switch configuration.resolvedRelayKind {
        case .selfHostedDirect:
            return "已连接：\(configuration.name)\n\(serverURL)\n直接推送地址：\(serverURL)/\(configuration.deviceKey)\n高隐私发送：先从 /self-hosted/recipients/<deviceKey> 获取公开密钥，再向 /push 发送 drelEnvelope。"
        case .managedEncrypted:
            let recipient = absoluteEndpoint(
                configuration.recipientPath, configuration: configuration) ?? "（服务未提供）"
            let delivery = absoluteEndpoint(
                configuration.deliveryPath, configuration: configuration) ?? "（服务未提供）"
            return "已连接：\(configuration.name)\n\(serverURL)\n托管加密推送：发送端先从 \(recipient) 获取本机公开密钥，再仅向 \(delivery) 发送 drelEnvelope。正文仅在本机解密。"
        }
    }

    private func developerConfiguration(
        for configuration: SelfHostedPushConfiguration,
        serverURL: String
    ) -> [String: String] {
        var payload: [String: String] = [
            "server": serverURL,
            "deviceKey": configuration.deviceKey,
            "mode": configuration.resolvedRelayKind.rawValue,
            "envelopeSchema": configuration.envelopeSchema ?? SelfHostedPushCrypto.schema
        ]
        switch configuration.resolvedRelayKind {
        case .selfHostedDirect:
            payload["directPushURL"] = "\(serverURL)/\(configuration.deviceKey)"
            payload["recipientEndpoint"] = "\(serverURL)/self-hosted/recipients/\(configuration.deviceKey)"
            payload["pushEndpoint"] = "\(serverURL)/push"
        case .managedEncrypted:
            if let recipient = absoluteEndpoint(configuration.recipientPath, configuration: configuration) {
                payload["recipientEndpoint"] = recipient
            }
            if let delivery = absoluteEndpoint(configuration.deliveryPath, configuration: configuration) {
                payload["deliveryEndpoint"] = delivery
            }
        }
        return payload
    }

    private func absoluteEndpoint(
        _ path: String?, configuration: SelfHostedPushConfiguration
    ) -> String? {
        guard let path else { return nil }
        let resolvedPath = path.replacingOccurrences(of: "{deviceKey}", with: configuration.deviceKey)
        return try? SelfHostedPushConfiguration.endpointURL(
            serverURL: configuration.serverURL,
            path: resolvedPath
        ).absoluteString
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "未能连接", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default)); present(alert, animated: true)
    }
}
