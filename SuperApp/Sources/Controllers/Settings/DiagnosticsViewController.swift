//
//  DiagnosticsViewController.swift
//  SuperApp
//
//  Created on 2026-05-19.
//  Copyright © 2026年 WebBridgeKit. All rights reserved.
//

import UIKit
import WebBridgeKit

#if DEBUG

class DiagnosticsViewController: UIViewController {

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var diagnosticsSections: [DiagnosticsSection] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.tr("settings.diagnostics.title")
        view.backgroundColor = ThemeTokens.Color.background

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(DiagnosticsActionCell.self, forCellReuseIdentifier: DiagnosticsActionCell.reuseIdentifier)

        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        loadDiagnostics()
    }

    private func loadDiagnostics() {
        diagnosticsSections = [
            DiagnosticsSection(
                title: L10n.tr("settings.diagnostics.system_info"),
                items: [
                    DiagnosticsItem(title: L10n.tr("settings.diagnostics.app_version"), detail: getAppVersion(), action: nil),
                    DiagnosticsItem(title: L10n.tr("settings.diagnostics.device_model"), detail: UIDevice.current.model, action: nil),
                    DiagnosticsItem(title: L10n.tr("settings.diagnostics.system_version"), detail: UIDevice.current.systemVersion, action: nil),
                    DiagnosticsItem(title: L10n.tr("settings.diagnostics.environment"), detail: isSimulator ? L10n.tr("settings.diagnostics.simulator") : L10n.tr("settings.diagnostics.device"), action: nil)
                ]
            ),
            DiagnosticsSection(
                title: L10n.tr("settings.diagnostics.export_title"),
                items: [
                    DiagnosticsItem(
                        title: L10n.tr("settings.export.diagnostics"),
                        detail: L10n.tr("settings.diagnostics.export_desc"),
                        action: { [weak self] in self?.exportDiagnosticsPackage() }
                    ),
                    DiagnosticsItem(
                        title: "导出到文件",
                        detail: "保存为 JSON 文件到文档目录",
                        action: { [weak self] in self?.exportToFile() }
                    ),
                    DiagnosticsItem(
                        title: "复制到剪贴板",
                        detail: "快速分享诊断数据",
                        action: { [weak self] in self?.copyToClipboard() }
                    )
                ]
            ),
            DiagnosticsSection(
                title: "数据管理",
                items: [
                    DiagnosticsItem(
                        title: "清除诊断数据",
                        detail: "删除本地崩溃日志和缓存",
                        action: { [weak self] in self?.confirmClearData() }
                    )
                ]
            )
        ]
        tableView.reloadData()
    }

    private func getAppVersion() -> String {
        guard let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String else {
            return "Unknown"
        }
        return "\(version) (\(build))"
    }

    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    private func exportDiagnosticsPackage() {
        let hud = UIAlertController(title: L10n.tr("settings.diagnostics.exporting"), message: L10n.tr("settings.diagnostics.collecting"), preferredStyle: .alert)
        present(hud, animated: true)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let diagnostics = self.collectDiagnosticsData()

            DispatchQueue.main.async {
                hud.dismiss(animated: true)
                self.shareDiagnostics(diagnostics)
            }
        }
    }

    private func exportToFile() {
        let hud = UIAlertController(title: "正在导出", message: "正在收集诊断数据...", preferredStyle: .alert)
        present(hud, animated: true)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let diagnostics = self.collectDiagnosticsData()

            guard let jsonData = try? JSONSerialization.data(withJSONObject: diagnostics, options: [.prettyPrinted, .sortedKeys]) else {
                DispatchQueue.main.async {
                    hud.dismiss(animated: true)
                    self.showError(message: "导出失败：无法生成 JSON 数据")
                }
                return
            }

            let timestamp = ISO8601DateFormatter().string(from: Date())
            let filename = "WebBridgeKit_Diagnostics_\(timestamp).json"

            guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                DispatchQueue.main.async {
                    hud.dismiss(animated: true)
                    self.showError(message: "导出失败：无法访问文档目录")
                }
                return
            }

            let fileURL = documentsDir.appendingPathComponent(filename)

            do {
                try jsonData.write(to: fileURL)
                DispatchQueue.main.async {
                    hud.dismiss(animated: true)
                    self.showSuccess(message: "已导出: \(filename)") { [weak self] in
                        self?.presentShareSheet(for: fileURL)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    hud.dismiss(animated: true)
                    self.showError(message: "导出失败: \(error.localizedDescription)")
                }
            }
        }
    }

    private func copyToClipboard() {
        let hud = UIAlertController(title: "正在复制", message: "正在收集诊断数据...", preferredStyle: .alert)
        present(hud, animated: true)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let diagnostics = self.collectDiagnosticsData()

            guard let jsonData = try? JSONSerialization.data(withJSONObject: diagnostics, options: [.prettyPrinted, .sortedKeys]),
                  let jsonString = String(data: jsonData, encoding: .utf8) else {
                DispatchQueue.main.async {
                    hud.dismiss(animated: true)
                    self.showError(message: "复制失败：无法生成 JSON 数据")
                }
                return
            }

            UIPasteboard.general.string = jsonString

            DispatchQueue.main.async {
                hud.dismiss(animated: true)
                self.showSuccess(message: "已复制到剪贴板")
            }
        }
    }

    private func confirmClearData() {
        let alert = UIAlertController(title: "确认清除", message: "这将删除所有本地崩溃日志和缓存数据。此操作不可撤销。\n\n您确定要继续吗？", preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "清除", style: .destructive) { [weak self] _ in
            self?.clearDiagnosticsData()
        })

        present(alert, animated: true)
    }

    private func clearDiagnosticsData() {
        let hud = UIAlertController(title: "正在清除", message: "正在删除诊断数据...", preferredStyle: .alert)
        present(hud, animated: true)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var errors: [String] = []

            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let crashLogsPath = documentsPath.appendingPathComponent("crash_logs")

            do {
                if FileManager.default.fileExists(atPath: crashLogsPath.path) {
                    try FileManager.default.removeItem(at: crashLogsPath)
                }
            } catch {
                errors.append("删除崩溃日志失败: \(error.localizedDescription)")
            }

            StructuredLogger.shared.clearBuffer()

            DispatchQueue.main.async {
                hud.dismiss(animated: true)

                if errors.isEmpty {
                    self.showSuccess(message: "诊断数据已清除") { [weak self] in
                        self?.loadDiagnostics()
                    }
                } else {
                    self.showError(message: "清除时发生错误:\n" + errors.joined(separator: "\n"))
                }
            }
        }
    }

    private func collectDiagnosticsData() -> [String: Any] {
        var data: [String: Any] = [:]

        data["timestamp"] = ISO8601DateFormatter().string(from: Date())
        data["appVersion"] = getAppVersion()
        data["deviceModel"] = UIDevice.current.model
        data["systemVersion"] = UIDevice.current.systemVersion
        data["environment"] = isSimulator ? "simulator" : "device"

        data["crashLogs"] = collectCrashLogs()
        data["commandHistory"] = collectCommandHistory()
        data["environmentInfo"] = collectEnvironmentInfo()

        return data
    }

    private func collectCrashLogs() -> [[String: Any]] {
        var logs: [[String: Any]] = []

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let crashLogsPath = documentsPath.appendingPathComponent("crash_logs")

        if FileManager.default.fileExists(atPath: crashLogsPath.path) {
            if let enumerator = FileManager.default.enumerator(at: crashLogsPath, includingPropertiesForKeys: nil) {
                for case let fileURL as URL in enumerator {
                    if fileURL.pathExtension == "json",
                       let data = try? Data(contentsOf: fileURL),
                       let crashLog = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        var sanitized = sanitizeLog(crashLog)
                        sanitized["filename"] = fileURL.lastPathComponent
                        logs.append(sanitized)
                    }
                }
            }
        }

        return Array(logs.prefix(20))
    }

    private func collectCommandHistory() -> [String] {
        var history: [String] = []

        let logs = StructuredLogger.shared.query(limit: 20)
        for log in logs {
            var sanitized = log.debugString
            sanitized = sanitizeSensitiveData(sanitized)
            history.append(sanitized)
        }

        return history
    }

    private func collectEnvironmentInfo() -> [String: Any] {
        var info: [String: Any] = [:]

        let env = EnvironmentInfo()
        info["summary"] = env.summary
        info["availableMemory"] = ProcessInfo.processInfo.physicalMemory
        info["processorCount"] = ProcessInfo.processInfo.processorCount

        return info
    }

    private func sanitizeLog(_ log: [String: Any]) -> [String: Any] {
        var sanitized = log

        let sensitiveKeys = ["token", "password", "secret", "key", "authorization", "cookie"]

        for key in sanitized.keys {
            if let lowerKey = key as? String, sensitiveKeys.contains(where: { lowerKey.lowercased().contains($0) }) {
                sanitized[key] = "***REDACTED***"
            }
        }

        return sanitized
    }

    private func sanitizeSensitiveData(_ text: String) -> String {
        var sanitized = text

        let patterns = [
            ( #"token["\s]*[:=]["\s]*["']?([^"'\s]+)["']?"#, "***TOKEN***"),
            (#"password["\s]*[:=]["\s]*["']?([^"'\s]+)["']?"#, "***PASSWORD***"),
            (#"secret["\s]*[:=]["\s]*["']?([^"'\s]+)["']?"#, "***SECRET***"),
            (#"authorization["\s]*[:=]["\s]*["']?([^"'\s]+)["']?"#, "***AUTH***")
        ]

        for (pattern, replacement) in patterns {
            sanitized = sanitized.replacingOccurrences(of: pattern, with: replacement, options: [.regularExpression, .caseInsensitive])
        }

        return sanitized
    }

    private func showSuccess(message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: "成功", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }

    private func showError(message: String) {
        let alert = UIAlertController(title: "错误", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    private func presentShareSheet(for fileURL: URL) {
        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        present(activityVC, animated: true)
    }

    private func shareDiagnostics(_ diagnostics: [String: Any]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: diagnostics, options: [.prettyPrinted, .sortedKeys]),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            let alert = UIAlertController(
                title: L10n.tr("settings.diagnostics.export_failed"),
                message: L10n.tr("settings.diagnostics.export_error"),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: L10n.tr("settings.diagnostics.ok"), style: .default))
            present(alert, animated: true)
            return
        }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let fileName = "diagnostics_\(timestamp).json"

        let tempFileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try jsonString.write(to: tempFileURL, atomically: true, encoding: .utf8)

            let activityVC = UIActivityViewController(activityItems: [tempFileURL], applicationActivities: nil)
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = view
                popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }

            present(activityVC, animated: true)
        } catch {
            let alert = UIAlertController(
                title: L10n.tr("settings.diagnostics.save_failed"),
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: L10n.tr("settings.diagnostics.ok"), style: .default))
            present(alert, animated: true)
        }
    }
}

extension DiagnosticsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return diagnosticsSections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return diagnosticsSections[section].items.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return diagnosticsSections[section].title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = diagnosticsSections[indexPath.section].items[indexPath.row]

        if item.action != nil {
            let cell = tableView.dequeueReusableCell(withIdentifier: DiagnosticsActionCell.reuseIdentifier, for: indexPath) as! DiagnosticsActionCell
            cell.configure(title: item.title, detail: item.detail)
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            var config = cell.defaultContentConfiguration()
            config.text = item.title
            config.secondaryText = item.detail
            cell.contentConfiguration = config
            cell.selectionStyle = .none
            return cell
        }
    }
}

extension DiagnosticsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = diagnosticsSections[indexPath.section].items[indexPath.row]
        item.action?()
    }
}

struct DiagnosticsSection {
    let title: String
    let items: [DiagnosticsItem]
}

struct DiagnosticsItem {
    let title: String
    let detail: String?
    let action: (() -> Void)?
}

class DiagnosticsActionCell: UITableViewCell {
    static let reuseIdentifier = "DiagnosticsActionCell"

    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let iconImageView = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        iconImageView.image = LucideIcon.docText.image()
        iconImageView.tintColor = ThemeTokens.Color.primary
        iconImageView.contentMode = .scaleAspectFit

        titleLabel.font = UIFont.preferredFont(forTextStyle: .body)
        titleLabel.textColor = ThemeTokens.Color.text

        detailLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        detailLabel.textColor = ThemeTokens.Color.textSecondary
        detailLabel.numberOfLines = 0

        contentView.addSubview(iconImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(detailLabel)

        [iconImageView, titleLabel, detailLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            detailLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            detailLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    func configure(title: String, detail: String?) {
        titleLabel.text = title
        detailLabel.text = detail
    }
}

#endif
