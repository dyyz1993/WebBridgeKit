import SwiftUI
import WebBridgeKit

struct RecentAccessHistoryView: View {
    @State private var history: [WebPageHistory] = []
    @State private var filter: TimeFilter = .all
    @State private var showClearConfirmation = false

    private let manager = WebPageHistoryManager.shared

    var body: some View {
        List {
            if history.isEmpty {
                VStack(spacing: ThemeTokens.Spacing.lg) {
                    Image(uiImage: LucideIcon.clock.templateImage(pointSize: 48, weight: .light) ?? UIImage())
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(Color.appTextTertiary)
                        .frame(width: 48, height: 48)
                    Text("暂无访问记录")
                        .font(Font.app(ThemeTokens.Typography.body))
                        .foregroundColor(Color.appTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
                .listRowBackground(Color.appCardBackground)
            } else {
                ForEach(history, id: \.id) { entry in
                    historyRow(entry)
                        .listRowBackground(Color.appCardBackground)
                }
            }
        }
        .appListStyle()
        .listStyle(.plain)
        .navigationTitle("最近访问")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Filter", selection: $filter) {
                    Text("全部").tag(TimeFilter.all)
                    Text("今天").tag(TimeFilter.today)
                    Text("7天").tag(TimeFilter.last7Days)
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("清除") { showClearConfirmation = true }
            }
        }
        .alert(isPresented: $showClearConfirmation) {
            Alert(
                title: Text("确认清除"),
                message: Text("将清除所有访问历史记录"),
                primaryButton: .cancel(Text("取消")),
                secondaryButton: .destructive(Text("清除"), action: clearAll)
            )
        }
        .onChange(of: filter) { _ in loadHistory() }
        .onAppear { loadHistory() }
    }

    private func historyRow(_ entry: WebPageHistory) -> some View {
        Button {
            guard let url = URL(string: entry.url) else { return }
            let rootVC = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?.rootViewController
            let navController: UINavigationController? = (rootVC as? UINavigationController)
                ?? (rootVC as? UITabBarController)?.selectedViewController as? UINavigationController
            if let nav = navController {
                WebBrowserManager.shared.openBrowser(url: url, from: nav)
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.title ?? URL(string: entry.url)?.host ?? entry.url)
                        .font(Font.app(ThemeTokens.Typography.body))
                        .foregroundColor(Color.appText)
                        .lineLimit(1)
                    Spacer()
                    Text(relativeTime(for: entry.lastVisitDate))
                        .font(Font.app(ThemeTokens.Typography.caption2))
                        .foregroundColor(Color.appTextTertiary)
                }
                Text(entry.url)
                    .font(Font.app(ThemeTokens.Typography.caption1))
                    .foregroundColor(Color.appTextSecondary)
                    .lineLimit(1)
            }
            .padding(.vertical, 4)
        }
    }

    private func loadHistory() {
        Task { @MainActor in
            do {
                switch filter {
                case .all:
                    history = try await manager.getAllHistories()
                case .today:
                    history = try await manager.getHistoriesSince(date: Calendar.current.startOfDay(for: Date()))
                case .last7Days:
                    history = try await manager.getHistoriesSince(date: Date().addingTimeInterval(-604800))
                }
            } catch {
                HUDService.shared.showError(withStatus: "加载失败: \(error.localizedDescription)")
            }
        }
    }

    private func deleteEntry(_ entry: WebPageHistory) {
        Task { @MainActor in
            do {
                try await manager.deleteHistory(id: entry.id)
                history.removeAll { $0.id == entry.id }
                HUDService.shared.showSuccess(withStatus: "已删除")
            } catch {
                HUDService.shared.showError(withStatus: "删除失败: \(error.localizedDescription)")
            }
        }
    }

    private func clearAll() {
        Task { @MainActor in
            do {
                try await manager.clearAllHistory()
                history.removeAll()
                HUDService.shared.showSuccess(withStatus: "历史已清除")
            } catch {
                HUDService.shared.showError(withStatus: "清除失败: \(error.localizedDescription)")
            }
        }
    }

    private func relativeTime(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.day, .hour, .minute], from: date, to: Date())
        if let days = components.day, days > 0 { return "\(days)天前" }
        if let hours = components.hour, hours > 0 { return "\(hours)小时前" }
        if let minutes = components.minute, minutes > 0 { return "\(minutes)分钟前" }
        return "刚刚"
    }
}
