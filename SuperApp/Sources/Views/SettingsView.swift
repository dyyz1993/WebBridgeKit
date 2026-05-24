import SwiftUI
import WebBridgeKit

struct SettingsView: View {
    private let sections = SettingsViewModel().sections

    @State private var showCopiedAlert = false
    @State private var appeared = false
    @AppStorage("settings.rememberLastApp") private var rememberLastApp = false

    let onNavigate: (Destination) -> Void

    enum Destination {
        case serverConfig
        case tokenManage
        case apiKeyManage
        case cacheManagement
        case favorites
        case history
        case notificationSettings
        case appearance
        case debugPanel
        case exportDiagnostics
        case cacheDashboard
        case about
    }

    private var versionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "WebBridgeKit v\(version) (Build \(build))"
    }

    var body: some View {
        List {
            ForEach(0..<sections.count, id: \.self) { sectionIndex in
                let section = sections[sectionIndex]
                Section(
                    header: section.header.map {
                        Text($0.uppercased())
                            .font(Font.app(ThemeTokens.Typography.metadata))
                            .foregroundColor(Color.appTextTertiary)
                            .textCase(nil)
                            .accessibilityIdentifier("settings.section.\(sectionIndex)")
                    }
                ) {
                    ForEach(0..<section.items.count, id: \.self) { rowIndex in
                        let item = section.items[rowIndex]
                        rowView(for: item)
                    }
                }
                .staggerIn(index: sectionIndex, appeared: appeared)
            }

            Section {
                Text(versionText)
                    .font(Font.app(ThemeTokens.Typography.metadata))
                    .foregroundColor(Color.appTextTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            }
            .staggerIn(index: sections.count, appeared: appeared)
        }
        .appListStyle()
        .listStyle(InsetGroupedListStyle())
        .navigationTitle(L10n.tr("tab.settings"))
        .accessibilityIdentifier("SettingsViewController")
        .onAppear { appeared = true }
        .alert(isPresented: $showCopiedAlert) {
            Alert(
                title: Text(L10n.tr("settings.hero.copied_title")),
                message: Text(L10n.tr("settings.hero.copied_message")),
                dismissButton: .default(Text(L10n.tr("common.ok")))
            )
        }
    }

    @ViewBuilder
    private func rowView(for item: SettingsViewModel.SettingsItem) -> some View {
        if item.cellKind == .hero {
            heroRow(item: item)
                .accessibilityIdentifier("settings.cell.hero")
                .listRowBackground(Color.appCardBackground)
        } else {
            normalRow(item: item)
                .accessibilityIdentifier("settings.cell.\(item.action?.rawValue ?? "default")")
                .listRowBackground(Color.appCardBackground)
        }
    }

    private func heroRow(item: SettingsViewModel.SettingsItem) -> some View {
        HStack(spacing: ThemeTokens.Spacing.md) {
            SettingsIconBox(
                image: item.lucideIcon?.templateImage(
                    pointSize: ThemeTokens.ComponentContract.SettingsRow.iconSize
                ),
                backgroundColor: ThemeTokens.Color.primary.withAlphaComponent(0.1),
                tintColor: ThemeTokens.Color.primary
            )

            Text(item.title)
                .font(Font.app(ThemeTokens.Typography.rowTitle))
                .foregroundColor(Color.appText)
                .lineLimit(1)

            Spacer()

            Button(action: {
                UIPasteboard.general.string = "abcd1234efgh5678"
                showCopiedAlert = true
            }) {
                Image(uiImage: LucideIcon.copy.templateImage(
                    pointSize: ThemeTokens.Icons.Sizes.sm
                ) ?? UIImage())
                    .renderingMode(.template)
                    .foregroundColor(Color.appPrimary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(L10n.tr("settings.hero.copied_title"))
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, ThemeTokens.Spacing.sm)
    }

    private func normalRow(item: SettingsViewModel.SettingsItem) -> some View {
        let iconImage: UIImage? = {
            if let lucide = item.lucideIcon {
                return lucide.templateImage(
                    pointSize: ThemeTokens.ComponentContract.SettingsRow.iconSize
                )
            }
            if let sfName = item.icon {
                return LucideIcon.fallbackImage(sfName: sfName)
            }
            return nil
        }()

        return SettingsRow(
            icon: iconImage,
            iconBackgroundColor: item.iconBackgroundColor ?? .clear,
            iconTintColor: item.iconTintColor ?? ThemeTokens.Color.primary,
            title: item.title,
            trailingText: item.value,
            showChevron: item.showArrow,
            isToggle: item.hasToggle,
            isToggleOn: $rememberLastApp,
            isDestructive: item.action == .cacheManager,
            badge: item.badge,
            onTap: {
                guard let action = item.action else { return }
                handleAction(action)
            }
        )
    }

    private func handleAction(_ action: SettingsViewModel.SettingsAction) {
        switch action {
        case .serverConfig: onNavigate(.serverConfig)
        case .tokenManager: onNavigate(.tokenManage)
        case .apiKeyManage: onNavigate(.apiKeyManage)
        case .cacheManager: onNavigate(.cacheManagement)
        case .favorites: onNavigate(.favorites)
        case .history: onNavigate(.history)
        case .notificationSettings: onNavigate(.notificationSettings)
        case .rememberLastApp: break
        case .appearance: onNavigate(.appearance)
        case .debugPanel: onNavigate(.debugPanel)
        case .cacheDashboard: onNavigate(.cacheDashboard)
        case .exportDiagnostics: onNavigate(.exportDiagnostics)
        case .about: onNavigate(.about)
        }
    }
}
