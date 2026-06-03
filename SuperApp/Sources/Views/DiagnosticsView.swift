import SwiftUI
import WebBridgeKit

#if DEBUG

final class DiagnosticsViewModel: ObservableObject {
    @Published var sections: [DiagnosticsUISection] = []
    @Published var isExporting = false
    @Published var shareItemURL: URL?
    @Published var alertMessage: String?
    @Published var lastActionMessage: String?
    @Published var showClearConfirmation = false

    struct DiagnosticsUISection: Identifiable {
        let id = UUID()
        let title: String
        let items: [DiagnosticsUIItem]
    }

    struct DiagnosticsUIItem: Identifiable {
        let id = UUID()
        let title: String
        let detail: String?
        let hasAction: Bool
    }

    func load() {
        sections = [
            .init(title: L10n.tr("settings.diagnostics.system_info"), items: [
                .init(title: L10n.tr("settings.diagnostics.app_version"), detail: appVersion, hasAction: false),
                .init(title: L10n.tr("settings.diagnostics.device_model"), detail: UIDevice.current.model, hasAction: false),
                .init(title: L10n.tr("settings.diagnostics.system_version"), detail: UIDevice.current.systemVersion, hasAction: false),
                .init(title: L10n.tr("settings.diagnostics.environment"), detail: isSimulator ? L10n.tr("settings.diagnostics.simulator") : L10n.tr("settings.diagnostics.device"), hasAction: false)
            ]),
            .init(title: L10n.tr("settings.diagnostics.export_title"), items: [
                .init(title: L10n.tr("settings.export.diagnostics"), detail: L10n.tr("settings.diagnostics.export_desc"), hasAction: true),
                .init(title: "导出到文件", detail: "保存为 JSON 文件到文档目录", hasAction: true),
                .init(title: "复制到剪贴板", detail: "快速分享诊断数据", hasAction: true)
            ]),
            .init(title: "数据管理", items: [
                .init(title: "清除诊断数据", detail: "删除本地崩溃日志和缓存", hasAction: true)
            ])
        ]
    }

    func handleAction(sectionIndex: Int, itemIndex: Int) {
        switch (sectionIndex, itemIndex) {
        case (1, 0): exportAndShare()
        case (1, 1): exportToFile()
        case (1, 2): copyToClipboard()
        case (2, 0): showClearConfirmation = true
        default: break
        }
    }

    func exportAndShare() {
        isExporting = true
        Task { @MainActor in
            let diagnostics = collectDiagnosticsData()
            guard let data = try? JSONSerialization.data(withJSONObject: diagnostics, options: [.prettyPrinted, .sortedKeys]),
                  let string = String(data: data, encoding: .utf8) else {
                alertMessage = L10n.tr("settings.diagnostics.export_failed")
                lastActionMessage = alertMessage
                isExporting = false
                return
            }
            let filename = "diagnostics_\(ISO8601DateFormatter().string(from: Date())).json"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try? string.write(to: url, atomically: true, encoding: .utf8)
            shareItemURL = url
            lastActionMessage = "诊断分享已准备"
            isExporting = false
        }
    }

    func exportToFile() {
        isExporting = true
        Task { @MainActor in
            let diagnostics = collectDiagnosticsData()
            guard let data = try? JSONSerialization.data(withJSONObject: diagnostics, options: [.prettyPrinted, .sortedKeys]) else {
                alertMessage = "导出失败：无法生成 JSON 数据"
                lastActionMessage = alertMessage
                isExporting = false
                return
            }
            let filename = "WebBridgeKit_Diagnostics_\(ISO8601DateFormatter().string(from: Date())).json"
            guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                alertMessage = "导出失败：无法访问文档目录"
                lastActionMessage = alertMessage
                isExporting = false
                return
            }
            let url = docs.appendingPathComponent(filename)
            do {
                try data.write(to: url)
                shareItemURL = url
                lastActionMessage = "诊断文件已生成"
            } catch {
                alertMessage = "导出失败: \(error.localizedDescription)"
                lastActionMessage = alertMessage
            }
            isExporting = false
        }
    }

    func copyToClipboard() {
        isExporting = true
        let diagnostics = collectDiagnosticsData()
        guard let data = try? JSONSerialization.data(withJSONObject: diagnostics, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            alertMessage = "复制失败：无法生成 JSON 数据"
            lastActionMessage = alertMessage
            isExporting = false
            return
        }
        UIPasteboard.general.string = string
        alertMessage = "已复制到剪贴板"
        lastActionMessage = "已复制到剪贴板"
        isExporting = false
    }

    func confirmClear() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let crashPath = docs.appendingPathComponent("crash_logs")
        do {
            if FileManager.default.fileExists(atPath: crashPath.path) {
                try FileManager.default.removeItem(at: crashPath)
            }
            StructuredLogger.shared.clearBuffer()
            alertMessage = "诊断数据已清除"
            lastActionMessage = "诊断数据已清除"
            load()
        } catch {
            alertMessage = "清除失败: \(error.localizedDescription)"
            lastActionMessage = alertMessage
        }
    }

    private var appVersion: String {
        guard let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String else { return "Unknown" }
        return "\(v) (\(b))"
    }

    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    private func collectDiagnosticsData() -> [String: Any] {
        var data: [String: Any] = [:]
        data["timestamp"] = ISO8601DateFormatter().string(from: Date())
        data["appVersion"] = appVersion
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
        let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("crash_logs")
        guard FileManager.default.fileExists(atPath: path.path),
              let enumerator = FileManager.default.enumerator(at: path, includingPropertiesForKeys: nil) else { return logs }
        for case let url as URL in enumerator where url.pathExtension == "json" {
            if let d = try? Data(contentsOf: url),
               let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
                var sanitized = obj
                for key in sanitized.keys where ["token", "password", "secret", "key", "authorization", "cookie"].contains(where: { key.lowercased().contains($0) }) {
                    sanitized[key] = "***REDACTED***"
                }
                sanitized["filename"] = url.lastPathComponent
                logs.append(sanitized)
            }
        }
        return Array(logs.prefix(20))
    }

    private func collectCommandHistory() -> [String] {
        StructuredLogger.shared.query(limit: 20).map { sanitize($0.debugString) }
    }

    private func collectEnvironmentInfo() -> [String: Any] {
        let env = EnvironmentInfo()
        return ["summary": env.summary, "availableMemory": ProcessInfo.processInfo.physicalMemory, "processorCount": ProcessInfo.processInfo.processorCount]
    }

    private func sanitize(_ text: String) -> String {
        var result = text
        let patterns: [(String, String)] = [
            (#"token["\s]*[:=]["\s]*["']?([^"'\s]+)["']?"#, "***TOKEN***"),
            (#"password["\s]*[:=]["\s]*["']?([^"'\s]+)["']?"#, "***PASSWORD***"),
            (#"secret["\s]*[:=]["\s]*["']?([^"'\s]+)["']?"#, "***SECRET***"),
            (#"authorization["\s]*[:=]["\s]*["']?([^"'\s]+)["']?"#, "***AUTH***")
        ]
        for (pattern, replacement) in patterns {
            result = result.replacingOccurrences(of: pattern, with: replacement, options: [.regularExpression, .caseInsensitive])
        }
        return result
    }
}

struct DiagnosticsView: View {
    @ObservedObject private var viewModel = DiagnosticsViewModel()
    @State private var appeared = false

    var body: some View {
        ZStack {
            List {
                Section {
                    Text(viewModel.lastActionMessage ?? "诊断页就绪")
                        .font(Font.app(ThemeTokens.Typography.caption1))
                        .foregroundColor(Color.appTextSecondary)
                        .accessibilityIdentifier("diagnostics.lastAction")
                }
                .staggerIn(index: 0, appeared: appeared)

                ForEach(Array(viewModel.sections.enumerated()), id: \.element.id) { sIndex, section in
                    Section(header: Text(section.title).font(Font.app(ThemeTokens.Typography.headline))) {
                        ForEach(Array(section.items.enumerated()), id: \.element.id) { iIndex, item in
                            if item.hasAction {
                                Button { viewModel.handleAction(sectionIndex: sIndex, itemIndex: iIndex) } label: {
                                    actionRow(item: item)
                                }
                                .buttonStyle(PressScaleButtonStyle())
                                .accessibilityIdentifier("diagnostics.action.\(sIndex).\(iIndex)")
                            } else {
                                infoRow(item: item)
                                    .accessibilityIdentifier("diagnostics.info.\(sIndex).\(iIndex)")
                            }
                        }
                    }
                    .staggerIn(index: sIndex, appeared: appeared)
                }
            }
            .appListStyle()
            .listStyle(.insetGrouped)

            if viewModel.isExporting {
                Color.black.opacity(0.2).edgesIgnoringSafeArea(.all)
                ProgressView()
            }
        }
        .navigationTitle(L10n.tr("settings.diagnostics.title"))
        .accessibilityIdentifier("diagnostics.root")
        .sheet(isPresented: Binding(
            get: { viewModel.shareItemURL != nil },
            set: { if !$0 { viewModel.shareItemURL = nil } }
        )) {
            ActivityShareSheet(url: viewModel.shareItemURL ?? URL(fileURLWithPath: "/dev/null"))
        }
        .alert(isPresented: $viewModel.showClearConfirmation) {
            Alert(
                title: Text("确认清除"),
                message: Text("这将删除所有本地崩溃日志和缓存数据。此操作不可撤销。"),
                primaryButton: .cancel(Text("取消")),
                secondaryButton: .destructive(Text("清除"), action: { viewModel.confirmClear() })
            )
        }
        .alert(isPresented: Binding(
            get: { viewModel.alertMessage != nil },
            set: { if !$0 { viewModel.alertMessage = nil } }
        )) {
            Alert(title: Text("提示"), message: Text(viewModel.alertMessage ?? ""), dismissButton: .default(Text("确定")))
        }
        .onAppear {
            viewModel.load()
            appeared = true
        }
    }

    private func infoRow(item: DiagnosticsViewModel.DiagnosticsUIItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(Font.app(ThemeTokens.Typography.body))
                .foregroundColor(Color.appText)
            if let detail = item.detail {
                Text(detail)
                    .font(Font.app(ThemeTokens.Typography.caption1))
                    .foregroundColor(Color.appTextSecondary)
            }
        }
        .listRowBackground(Color.appCardBackground)
    }

    private func actionRow(item: DiagnosticsViewModel.DiagnosticsUIItem) -> some View {
        HStack(spacing: 12) {
            Image(uiImage: LucideIcon.docText.templateImage() ?? UIImage())
                .resizable()
                .renderingMode(.template)
                .foregroundColor(Color.appPrimary)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(Font.app(ThemeTokens.Typography.body))
                    .foregroundColor(Color.appText)
                if let detail = item.detail {
                    Text(detail)
                        .font(Font.app(ThemeTokens.Typography.caption1))
                        .foregroundColor(Color.appTextSecondary)
                }
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.appCardBackground)
    }
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activityVC.view.accessibilityIdentifier = "diagnostics.shareSheet"
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = activityVC.view
            popover.sourceRect = CGRect(x: activityVC.view.bounds.midX, y: activityVC.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        return activityVC
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#endif
