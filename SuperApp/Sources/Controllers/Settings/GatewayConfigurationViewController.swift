import RxSwift
import SnapKit
import UIKit
import WebBridgeKit

final class GatewayConfigurationViewController: UIViewController {
    private let allowsDevelopmentMode = _isDebugAssertConfiguration()
    private lazy var registry = HTMLAppGatewayRegistry(allowsDevelopmentHTTP: allowsDevelopmentMode)
    private lazy var onboardingService = HTMLAppGatewayOnboardingService(
        gatewayRegistry: registry,
        allowsDevelopmentMode: allowsDevelopmentMode
    )
    private let disposeBag = DisposeBag()
    private lazy var tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var gateways: [HTMLAppGatewayConfiguration] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "网关配置"
        view.backgroundColor = ThemeTokens.Color.background
        tableView.backgroundColor = ThemeTokens.Color.background
        tableView.accessibilityIdentifier = "gateway.table"
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "gateway")
        view.addSubview(tableView)
        tableView.snp.makeConstraints { $0.edges.equalToSuperview() }
        let scanButton = UIBarButtonItem(title: "扫码", style: .plain, target: self, action: #selector(scanGateway))
        scanButton.accessibilityIdentifier = "gateway.scanButton"
        let pasteButton = UIBarButtonItem(title: "粘贴", style: .plain, target: self, action: #selector(pasteGateway))
        pasteButton.accessibilityIdentifier = "gateway.pasteButton"
        navigationItem.rightBarButtonItems = [scanButton, pasteButton]
        reloadGateways()
    }

    private func reloadGateways() {
        gateways = registry.allGateways()
        tableView.reloadData()
    }

    @objc private func pasteGateway() {
        let alert = UIAlertController(title: "导入网关", message: "粘贴 JSON 配置或 webbridgekit://gateway 链接", preferredStyle: .alert)
        alert.addTextField { field in
            let processInfo = ProcessInfo.processInfo
            let testingPayload = processInfo.arguments.contains("--UITesting")
                ? processInfo.environment["WBK_GATEWAY_UI_PAYLOAD"]
                : nil
            field.text = testingPayload ?? UIPasteboard.general.string
            field.accessibilityIdentifier = "gateway.importField"
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "导入", style: .default) { [weak self, weak alert] _ in
            self?.importGateway(alert?.textFields?.first?.text ?? "")
        })
        present(alert, animated: true)
    }

    @objc private func scanGateway() {
        let scanner = QRScannerViewController(configuration: .init(showScanRegionOverlay: true, showCloseButton: true, tipText: "扫描 WebBridgeKit 网关配置码", autoDismiss: true))
        scanner.scannerDidSuccess.subscribe(onNext: { [weak self] payload in
            self?.importGateway(payload)
        }).disposed(by: disposeBag)
        navigationController?.pushViewController(scanner, animated: true)
    }

    private func importGateway(_ payload: String) {
        do {
            let gateway = try HTMLAppGatewayConfiguration.importPayload(
                payload,
                allowsDevelopmentHTTP: allowsDevelopmentMode
            )
            validateAndConfirm(gateway)
        } catch {
            showMessage(title: "无法导入", message: error.localizedDescription)
        }
    }

    private func validateAndConfirm(_ gateway: HTMLAppGatewayConfiguration) {
        navigationItem.prompt = "正在验证网关和应用清单..."
        navigationItem.rightBarButtonItems?.forEach { $0.isEnabled = false }
        onboardingService.validate(gateway) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.navigationItem.prompt = nil
                self.navigationItem.rightBarButtonItems?.forEach { $0.isEnabled = true }
                switch result {
                case .failure(let error):
                    self.showMessage(title: "网关验证失败", message: error.localizedDescription)
                case .success(let report):
                    self.presentConfirmation(report)
                }
            }
        }
    }

    private func presentConfirmation(_ report: HTMLAppGatewayValidationReport) {
        let keyDescription = report.gateway.publicKeyID ?? (allowsDevelopmentMode ? "调试模式（未签名）" : "未提供")
        let message = """
        主机：\(report.gateway.baseURL)
        健康检查：\(report.gateway.healthURL?.absoluteString ?? report.gateway.healthPath)
        清单：\(report.gateway.manifestURL?.absoluteString ?? report.gateway.manifestPath)
        应用：\(report.manifests.count) 个
        信任密钥：\(keyDescription)
        """
        let alert = UIAlertController(title: "确认网关", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "保存并启用", style: .default) { [weak self] _ in
            guard let self else { return }
            do {
                try self.onboardingService.activate(report)
                self.reloadGateways()
                self.showMessage(title: "网关已启用", message: "已注册 \(report.manifests.count) 个 HTML 应用")
            } catch {
                self.showMessage(title: "无法启用", message: error.localizedDescription)
            }
        })
        present(alert, animated: true)
    }

    private func showMessage(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
    }
}

extension GatewayConfigurationViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { 2 }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { section == 0 ? 1 : gateways.count }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { section == 0 ? "快速配置" : "已保存网关" }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "gateway", for: indexPath)
        var content = cell.defaultContentConfiguration()
        if indexPath.section == 0 {
            content.text = "粘贴配置或扫描二维码"
            content.secondaryText = "仅接受 HTTPS 网关；调试版可使用 localhost"
            cell.accessoryType = .none
        } else {
            let gateway = gateways[indexPath.row]
            content.text = gateway.name
            content.secondaryText = gateway.baseURL
            cell.accessoryType = registry.activeGateway()?.id == gateway.id ? .checkmark : .none
        }
        cell.contentConfiguration = content
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        guard indexPath.section == 1 else { return }
        let gateway = gateways[indexPath.row]
        validateAndConfirm(gateway)
    }
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool { indexPath.section == 1 }
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        let gateway = gateways[indexPath.row]
        do {
            try onboardingService.removeGateway(id: gateway.id)
            reloadGateways()
        } catch {
            showMessage(title: "无法移除", message: error.localizedDescription)
        }
    }
}
