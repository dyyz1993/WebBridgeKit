#if DEBUG
import SwiftUI
import WebBridgeKit

struct WebCacheStatusPanel: View {
    let totalSize: String
    let totalEntries: String
    let activeSystems: String
    let pinnedCount: String
    let summaryText: String

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.md) {
            HStack {
                Text("缓存状态")
                    .font(Font.app(ThemeTokens.Typography.sectionTitle))
                    .foregroundColor(Color.appText)
                    .lineLimit(1)

                Spacer()

                StatusBadge(title: "Live", tone: .success)
            }

            LazyVGrid(columns: columns, spacing: ThemeTokens.Spacing.md) {
                MetricTile(title: "总缓存", value: totalSize, icon: .hardDrive, tone: .info)
                MetricTile(title: "条目", value: totalEntries, icon: .docText, tone: .neutral)
                MetricTile(title: "活跃", value: activeSystems, icon: .chartBar, tone: .success)
                MetricTile(title: "置顶", value: pinnedCount, icon: .pin, tone: .warning)
            }

            Text(summaryText)
                .font(Font.app(ThemeTokens.Typography.metadata))
                .foregroundColor(Color.appTextSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("webCache.statusPanel")
    }

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: ThemeTokens.Spacing.md),
            GridItem(.flexible(), spacing: ThemeTokens.Spacing.md)
        ]
    }
}

#endif
