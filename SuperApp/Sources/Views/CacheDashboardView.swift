//
//  CacheDashboardView.swift
//  SuperApp
//
//  SwiftUI rewrite of CacheDashboardViewController (294 lines UIKit → ~280 lines SwiftUI)
//

import SwiftUI
import WebBridgeKit

struct CacheDashboardView: View {

    @StateObject private var viewModel = CacheDashboardViewModelObservable()
    @State private var appeared = false

    var onNavigateToSubsystem: ((SubsystemID) -> Void)?

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.sections.isEmpty {
                loadingView
            } else if let error = viewModel.errorMessage, !error.isEmpty, viewModel.sections.isEmpty {
                errorView(error)
            } else if viewModel.sections.isEmpty && !viewModel.isLoading {
                emptyStateView
            } else {
                dashboardContent
            }
        }
        .navigationTitle("缓存仪表盘")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { viewModel.refresh() }, label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(Color.appPrimary)
                })
                .accessibilityLabel("刷新缓存数据")
            }
        }
        .onAppear { 
            viewModel.loadData()
            appeared = true
        }
    }

    private var loadingView: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.appPrimary))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: ThemeTokens.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 52, weight: .medium))
                .foregroundColor(Color.appError)
            Text("加载失败")
                .font(Font(ThemeTokens.Typography.sectionTitle))
                .foregroundColor(Color.appText)
            Text(message)
                .font(Font(ThemeTokens.Typography.subheadline))
                .foregroundColor(Color.appError)
                .multilineTextAlignment(.center)
                .padding(.horizontal, ThemeTokens.Spacing.xl)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
            Button(action: { viewModel.refresh() }, label: {
                HStack(spacing: ThemeTokens.Spacing.sm) {
                    Image(systemName: "arrow.clockwise")
                    Text("重试")
                }
                .font(Font(ThemeTokens.Typography.subheadline))
                .foregroundColor(Color(ThemeTokens.Color.onPrimary))
                .padding(.horizontal, ThemeTokens.Spacing.xxl)
                .padding(.vertical, ThemeTokens.Spacing.md)
                .background(Color.appPrimary)
                .cornerRadius(ThemeTokens.CornerRadius.md)
            })
            .accessibilityIdentifier("cacheDashboard.retryButton")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .accessibilityIdentifier("cacheDashboard.errorView")
    }

    private var emptyStateView: some View {
        VStack(spacing: ThemeTokens.Spacing.md) {
            Spacer()
            Image(systemName: "internaldrive")
                .font(.system(size: 60, weight: .light))
                .foregroundColor(Color.appTextTertiary)
                .padding(.bottom, ThemeTokens.Spacing.sm)
            Text("暂无缓存数据")
                .font(Font(ThemeTokens.Typography.sectionTitle))
                .foregroundColor(Color.appTextSecondary)
            Text("请确保后端服务已启动，或访问页面后再查看")
                .font(Font(ThemeTokens.Typography.body))
                .foregroundColor(Color.appTextTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, ThemeTokens.Spacing.xl)
            Button(action: { viewModel.refresh() }, label: {
                HStack(spacing: ThemeTokens.Spacing.xs) {
                    Image(systemName: "arrow.clockwise")
                    Text("刷新")
                }
                .font(Font(ThemeTokens.Typography.subheadline))
                .foregroundColor(Color(ThemeTokens.Color.onPrimary))
                .padding(.horizontal, ThemeTokens.Spacing.xl)
                .padding(.vertical, ThemeTokens.Spacing.sm)
                .background(Color.appPrimary)
                .cornerRadius(ThemeTokens.CornerRadius.md)
            })
            .padding(.top, ThemeTokens.Spacing.lg)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .accessibilityIdentifier("cacheDashboard.emptyState")
    }

    private var dashboardContent: some View {
        List {
            summarySection

            ForEach(viewModel.sections) { section in
                Section(header: sectionHeaderView(section.title)) {
                    ForEach(section.items) { item in
                        subsystemRow(item)
                            .listRowBackground(Color.appCardBackground)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .appListStyle()
        .accessibilityIdentifier("cacheDashboard.tableView")
    }

    private var summarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.md) {
                HStack(spacing: ThemeTokens.Spacing.sm) {
                    metricCard(icon: "internaldrive", label: "总缓存", value: viewModel.summaryValues.totalSize)
                    metricCard(icon: "doc.text", label: "总条目", value: viewModel.summaryValues.totalEntries)
                    metricCard(icon: "pin", label: "置顶数", value: viewModel.summaryValues.pinnedCount)
                    metricCard(icon: "chart.bar", label: "活跃系统", value: viewModel.summaryValues.activeSystems)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.xs)
                            .fill(Color.appSeparator)
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.xs)
                            .fill(Color.appPrimary)
                            .frame(width: geo.size.width * viewModel.summaryValues.activeRatio, height: 6)
                    }
                }
                .frame(height: 6)

                Text(viewModel.summaryText)
                    .font(Font(ThemeTokens.Typography.caption1))
                    .foregroundColor(Color.appTextSecondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(ThemeTokens.Spacing.lg)
            .background(Color.appCardBackground)
            .cornerRadius(ThemeTokens.CornerRadius.xl)
            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
            .springAppear(appeared: appeared)
            .listRowInsets(EdgeInsets(
                top: ThemeTokens.Spacing.md,
                leading: ThemeTokens.Spacing.lg,
                bottom: ThemeTokens.Spacing.xs,
                trailing: ThemeTokens.Spacing.lg
            ))
            .listRowBackground(Color.appBackground)
        }
    }

    private func metricCard(icon: String, label: String, value: String) -> some View {
        VStack(spacing: ThemeTokens.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.appPrimary)
            Text(value)
                .font(Font(ThemeTokens.Typography.title3))
                .foregroundColor(Color.appText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(Font(ThemeTokens.Typography.caption2))
                .foregroundColor(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(ThemeTokens.Spacing.xs)
        .background(Color(ThemeTokens.Color.surface))
        .cornerRadius(ThemeTokens.CornerRadius.md)
    }

    private func sectionHeaderView(_ title: String) -> some View {
        Text(title)
            .font(Font(ThemeTokens.Typography.caption1))
            .foregroundColor(Color.appTextSecondary)
    }

    private func subsystemRow(_ item: SubsystemSectionItem) -> some View {
        Button(action: {
            guard let sid = SubsystemID(rawValue: item.id) else { return }
            onNavigateToSubsystem?(sid)
        }, label: {
            HStack(spacing: ThemeTokens.Spacing.md) {
                subsystemIcon(item)
                subsystemInfo(item)
                Spacer()
                subsystemMetrics(item)
            }
            .padding(.vertical, ThemeTokens.Spacing.sm)
        })
        .buttonStyle(PlainButtonStyle())
    }

    private func subsystemIcon(_ item: SubsystemSectionItem) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md)
                .fill(item.hasData ? Color.appPrimary : Color.appTextTertiary)
                .frame(width: 36, height: 36)
            Image(uiImage: UIImage(lucideId: item.iconName) ?? UIImage())
                .renderingMode(.template)
                .foregroundColor(Color(ThemeTokens.Color.onPrimary))
                .frame(width: 20, height: 20)
        }
    }

    private func subsystemInfo(_ item: SubsystemSectionItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.nameZh)
                .font(Font(ThemeTokens.Typography.body))
                .foregroundColor(Color.appText)
                .lineLimit(1)
            Text(item.statusText)
                .font(Font(ThemeTokens.Typography.caption1))
                .foregroundColor(statusColor(item.statusColorName))
                .lineLimit(1)
        }
    }

    private func subsystemMetrics(_ item: SubsystemSectionItem) -> some View {
        HStack(spacing: ThemeTokens.Spacing.sm) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(item.entries)
                    .font(Font(ThemeTokens.Typography.monospaceMeta))
                    .foregroundColor(Color.appText)
                Text(item.size)
                    .font(Font(ThemeTokens.Typography.monospaceMeta))
                    .foregroundColor(Color.appTextSecondary)
            }
            if let hitRate = item.hitRate {
                hitRateBadge(hitRate)
            }
            statusDot(item.statusColorName)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.appTextTertiary)
        }
    }

    @ViewBuilder
    private func hitRateBadge(_ hitRate: String) -> some View {
        let rate = Double(hitRate.replacingOccurrences(of: "%", with: "")) ?? 0
        Text(hitRate)
            .font(Font(ThemeTokens.Typography.monospaceMeta))
            .foregroundColor(Color(ThemeTokens.Color.onPrimary))
            .padding(.horizontal, ThemeTokens.Spacing.sm)
            .padding(.vertical, 2)
            .background(
                rate >= 80 ? Color.appSuccess :
                    (rate >= 50 ? Color.appPrimary : Color.appError)
            )
            .cornerRadius(ThemeTokens.CornerRadius.sm)
    }

    private func statusDot(_ colorName: String) -> some View {
        Circle()
            .fill(statusColor(colorName))
            .frame(width: 8, height: 8)
    }

    private func statusColor(_ name: String) -> Color {
        switch name {
        case "success": return Color.appSuccess
        case "error": return Color.appError
        default: return Color.appTextTertiary
        }
    }
}

// MARK: - Observable ViewModel Wrapper

final class CacheDashboardViewModelObservable: ObservableObject {

    struct SectionGroup: Identifiable {
        let id = UUID()
        let title: String
        let items: [SubsystemSectionItem]
    }

    struct SummaryValues {
        var totalSize = "--"
        var totalEntries = "--"
        var pinnedCount = "--"
        var activeSystems = "--"
        var activeRatio: CGFloat = 0
    }

    @Published var sections: [SectionGroup] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var summaryText = "暂无数据"
    @Published var summaryValues = SummaryValues()

    private let rxViewModel = CacheDashboardViewModel()
    private var dashboardData: DashboardData?

    func loadData() {
        isLoading = true
        errorMessage = nil

        let timeoutWorkItem = DispatchWorkItem { [weak self] in
            guard let self, self.isLoading else { return }
            self.isLoading = false
            self.errorMessage = "加载超时（8s），请检查网络或服务状态后重试"
            self.applyFallbackData()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: timeoutWorkItem)

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            do {
                let data = CacheStatsAggregator.shared.syncAggregate()
                timeoutWorkItem.cancel()
                DispatchQueue.main.async {
                    self.dashboardData = data
                    self.applyData(data)
                    self.isLoading = false
                }
            } catch {
                timeoutWorkItem.cancel()
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "同步失败: \(error.localizedDescription)"
                    self.applyFallbackData()
                }
            }
        }
    }

    private func applyFallbackData() {
        let allSubsystemIDs = SubsystemID.allCases
        let fallbackItems = allSubsystemIDs.map { id -> SubsystemSectionItem in
            SubsystemSectionItem(
                id: id.rawValue,
                nameZh: id.nameZh,
                iconName: id.iconName,
                entries: "--",
                size: "--",
                hitRate: nil,
                statusText: "未连接",
                statusColorName: "default",
                hasData: false
            )
        }
        sections = [SectionGroup(title: "[WHITE] 缓存子系统", items: fallbackItems)]
        summaryValues = SummaryValues(
            totalSize: "--",
            totalEntries: "--",
            pinnedCount: "--",
            activeSystems: "0/\(allSubsystemIDs.count)",
            activeRatio: 0
        )
        summaryText = "服务不可用 | 显示 \(allSubsystemIDs.count) 个子系统状态"
    }

    func refresh() {
        loadData()
    }

    private func applyData(_ data: DashboardData) {
        summaryValues = SummaryValues(
            totalSize: data.formattedTotalSize,
            totalEntries: "\(data.totalEntries)",
            pinnedCount: "\(data.pinnedURLCount)",
            activeSystems: "\(data.activeSubsystemCount)/\(data.subsystems.count)",
            activeRatio: data.subsystems.isEmpty ? 0 :
                CGFloat(data.activeSubsystemCount) / CGFloat(data.subsystems.count)
        )

        summaryText = "总计 \(data.formattedTotalSize) | \(data.totalEntries) 条目 | \(data.activeSubsystemCount)/\(data.subsystems.count) 子系统活跃"

        let activeItems = data.subsystems
            .filter { $0.hasData || $0.status == .active }
            .map { SubsystemSectionItem(from: $0) }

        let inactiveItems = data.subsystems
            .filter { !$0.hasData && $0.status != .active }
            .map { SubsystemSectionItem(from: $0) }

        var result: [SectionGroup] = []
        if !activeItems.isEmpty {
            result.append(SectionGroup(title: "[GREEN] 活跃", items: activeItems))
        }
        if !inactiveItems.isEmpty {
            result.append(SectionGroup(title: "[WHITE] 空闲", items: inactiveItems))
        }
        if result.isEmpty {
            let allItems = data.subsystems.map { SubsystemSectionItem(from: $0) }
            result.append(SectionGroup(title: "[WHITE] 缓存子系统", items: allItems))
        }
        sections = result
    }
}

// MARK: - Section Item Model

struct SubsystemSectionItem: Identifiable {
    let id: String
    let nameZh: String
    let iconName: String
    let entries: String
    let size: String
    let hitRate: String?
    let statusText: String
    let statusColorName: String
    let hasData: Bool

    init(from stats: SubsystemStats) {
        self.id = stats.id.rawValue
        self.nameZh = stats.id.nameZh
        self.iconName = stats.id.iconName
        self.entries = "\(stats.totalEntries)"
        self.size = stats.formattedSize
        self.hitRate = stats.formattedHitRate
        self.statusText = stats.status.displayText
        self.statusColorName = stats.status.statusColorName
        self.hasData = stats.hasData
    }

    init(id: String, nameZh: String, iconName: String, entries: String, size: String, hitRate: String?, statusText: String, statusColorName: String, hasData: Bool) {
        self.id = id
        self.nameZh = nameZh
        self.iconName = iconName
        self.entries = entries
        self.size = size
        self.hitRate = hitRate
        self.statusText = statusText
        self.statusColorName = statusColorName
        self.hasData = hasData
    }
}

// MARK: - UIViewControllerRepresentable for embedding in UIKit

struct CacheDashboardHostingView: UIViewControllerRepresentable {

    let onNavigateToSubsystem: (SubsystemID) -> Void

    func makeUIViewController(context: Context) -> UIHostingController<CacheDashboardView> {
        let view = CacheDashboardView(onNavigateToSubsystem: onNavigateToSubsystem)
        return UIHostingController(rootView: view)
    }

    func updateUIViewController(_ uiViewController: UIHostingController<CacheDashboardView>, context: Context) {}
}
