#if DEBUG
import SwiftUI
import WebBridgeKit

struct WebCacheHomeView: View {
    let onAction: (WebCacheHomeAction) -> Void

    @StateObject private var viewModel = WebCacheHomeViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xxl) {
                ModuleHeaderView(
                    title: "Web 缓存调试",
                    subtitle: "网页打开、缓存策略、离线包与清理",
                    icon: .globe,
                    accessibilityIdentifier: "moduleHeader.webCache"
                )
                ServiceStatusStrip(items: serviceItems)
                urlSection
                WebCacheModePicker(selection: $viewModel.selectedMode)
                primaryActions
                WebCacheStatusPanel(
                    totalSize: viewModel.totalSize,
                    totalEntries: viewModel.totalEntries,
                    activeSystems: viewModel.activeSystems,
                    pinnedCount: viewModel.pinnedCount,
                    summaryText: viewModel.summaryText
                )
                ResultPanel(
                    title: "打开结果",
                    state: viewModel.resultState,
                    detail: viewModel.resultDetail.isEmpty ? nil : viewModel.resultDetail,
                    copyAction: copyResult
                )
            }
            .padding(.horizontal, ThemeTokens.Spacing.screenHorizontal)
            .padding(.top, ThemeTokens.Spacing.screenTop)
            .padding(.bottom, ThemeTokens.Spacing.screenBottom + 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Web")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $viewModel.showingClearAllConfirmation) {
            ConfirmDangerSheet(
                title: "清理全部 Web 缓存？",
                message: "这会清理 WKWebView、Manifest、资源缓存和统计数据。清理后需要重新在线打开页面才能恢复离线能力。",
                confirmTitle: "清理",
                onConfirm: viewModel.clearAllCache
            )
        }
        .onAppear {
            viewModel.refreshStats()
        }
        .accessibilityIdentifier("webCache.home")
    }

    private var serviceItems: [AppShellStatusItem] {
        [
            AppShellStatusItem(title: "Backend", value: ":8080", tone: .neutral),
            AppShellStatusItem(title: "Static", value: ":8081", tone: .neutral),
            AppShellStatusItem(title: "Offline", value: viewModel.selectedMode.title, tone: .success)
        ]
    }

    private var urlSection: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.sm) {
            Text("目标 URL")
                .font(Font.app(ThemeTokens.Typography.sectionTitle))
                .foregroundColor(Color.appText)

            HStack(spacing: ThemeTokens.Spacing.sm) {
                TextField("输入 URL 或域名", text: $viewModel.urlText)
                    .font(Font.app(ThemeTokens.Typography.body))
                    .foregroundColor(Color.appText)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(.horizontal, ThemeTokens.Spacing.md)
                    .frame(height: ThemeTokens.ComponentContract.SearchField.height)
                    .background(Color(ThemeTokens.Color.surface))
                    .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md)
                            .stroke(Color.appSeparator, lineWidth: 1)
                    )
                    .accessibilityIdentifier("webCache.urlInput")

                Button(action: openURL) {
                    Text("打开")
                        .font(Font.app(ThemeTokens.Typography.button))
                        .foregroundColor(Color(ThemeTokens.Color.onPrimary))
                        .frame(minWidth: 64, minHeight: 44)
                        .background(Color.appPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md))
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityIdentifier("webCache.openButton")
            }
        }
    }

    private var primaryActions: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.md) {
            Text("缓存操作")
                .font(Font.app(ThemeTokens.Typography.sectionTitle))
                .foregroundColor(Color.appText)

            ActionRow(
                title: "缓存仪表盘",
                subtitle: "查看缓存子系统、资源数、命中状态和统计",
                icon: .hardDrive,
                accessibilityIdentifier: "webCache.cacheDashboard",
                badge: "Stats",
                badgeTone: .info,
                action: { onAction(.openCacheDashboard) }
            )

            ActionRow(
                title: "缓存管理",
                subtitle: "管理收藏、历史和缓存清理入口",
                icon: .folder,
                accessibilityIdentifier: "webCache.cacheManagement",
                badge: "Manage",
                badgeTone: .neutral,
                action: { onAction(.openCacheManagement) }
            )

            ActionRow(
                title: "清理全部缓存",
                subtitle: "危险操作，执行前会二次确认",
                icon: .trash,
                accessibilityIdentifier: "webCache.clearAllButton",
                badge: "Danger",
                badgeTone: .error,
                action: { viewModel.showingClearAllConfirmation = true }
            )
        }
    }

    private func openURL() {
        guard let url = viewModel.normalizedURL() else {
            viewModel.markInvalidURL()
            return
        }

        viewModel.markOpenStarted()
        WebBrowserManager.shared.openBrowser(
            url: url,
            forceRefresh: viewModel.selectedMode == .online,
            completion: viewModel.markOpenResult
        )
    }

    private func copyResult() {
        UIPasteboard.general.string = viewModel.resultDetail
    }
}

#endif
