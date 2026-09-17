import SwiftUI
import UserNotifications
import WebBridgeKit

struct SettingsView: View {
    private var sections: [SettingsViewModel.SettingsSection] { SettingsViewModel().sections }

    #if !DREL_RELEASE_MINIMAL_SETTINGS
    @State private var heroAlert: HeroAlertState?
    @AppStorage("com.webbridgekit.bark.key") private var barkKey = ""
    #endif
    @State private var appeared = false
    @State private var notificationPermissionSummary = "检查中"
    @AppStorage(SettingsPreferenceKeys.defaultStartupAppID) private var defaultStartupAppID = ""

    #if !DREL_RELEASE_MINIMAL_SETTINGS
    private var heroDisplayToken: String? {
        // S1 fix: read the same identity store the 推送通道 page renders, so
        // both surfaces can never disagree about whether an identity exists.
        if let identity = try? OfficialPushIdentityStore.shared.currentOrMigrateToShortIdentity(),
           !identity.isEmpty {
            return identity
        }
        let trimmed = barkKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var heroMaskedToken: String {
        guard let token = heroDisplayToken else {
            return L10n.tr("settings.hero.identity.unset")
        }
        guard token.count >= 8 else { return "****" }
        let prefix = token.prefix(4)
        let suffix = token.suffix(4)
        return "\(prefix)****\(suffix)"
    }
    #endif

    let onNavigate: (Destination) -> Void

    enum Destination {
        case serverConfig
        case tokenManage
        case apiKeyManage
        case webGrants
        case cacheManagement
        case favorites
        case history
        case notificationSettings
        case pushEncryption
        case defaultStartupApp
        case appearance
        case debugPanel
        case exportDiagnostics
        case cacheDashboard
        case debugCenter
        case deepLinks
        case about
    }

    private var versionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Drel v\(version) (Build \(build))"
    }

    var body: some View {
        List {
            ForEach(0..<sections.count, id: \.self) { sectionIndex in
                let section = sections[sectionIndex]
                Section(
                    header: section.header.map {
                        Text($0.uppercased())
                            .font(Font.app(ThemeTokens.Typography.metadata))
                            // Section headers are navigational landmarks, not
                            // decorative metadata. Keep them at readable
                            // secondary-text contrast in both appearances.
                            .foregroundColor(Color.appTextSecondary)
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
        .environment(\.defaultMinListRowHeight, ThemeTokens.ComponentContract.SettingsRow.minHeight)
        .navigationTitle(L10n.tr("tab.settings"))
        .accessibilityIdentifier("SettingsViewController")
        .onAppear {
            appeared = true
            refreshNotificationPermissionSummary()
        }
        #if !DREL_RELEASE_MINIMAL_SETTINGS
        .alert(item: $heroAlert) { state in
            switch state {
            case .copied:
                return Alert(
                    title: Text(L10n.tr("settings.hero.copied_title")),
                    message: Text(L10n.tr("settings.hero.copied_message")),
                    dismissButton: .default(Text(L10n.tr("common.ok")))
                )
            case .unset:
                return Alert(
                    title: Text(L10n.tr("settings.hero.unset_title")),
                    message: Text(L10n.tr("settings.hero.unset_message")),
                    dismissButton: .default(Text(L10n.tr("common.ok")))
                )
            }
        }
        #endif
    }

    #if !DREL_RELEASE_MINIMAL_SETTINGS
    enum HeroAlertState: Identifiable {
        case copied
        case unset

        var id: Self { self }
    }
    #endif

    @ViewBuilder
    private func rowView(for item: SettingsViewModel.SettingsItem) -> some View {
        #if !DREL_RELEASE_MINIMAL_SETTINGS
        if item.cellKind == .hero {
            heroRow(item: item)
                .accessibilityIdentifier("settings.cell.hero")
                .listRowBackground(Color.appCardBackground)
        } else {
            normalRow(item: item)
                .accessibilityIdentifier("settings.cell.\(item.action?.rawValue ?? "default")")
                .listRowBackground(Color.appCardBackground)
        }
        #else
        normalRow(item: item)
            .accessibilityIdentifier("settings.cell.\(item.action?.rawValue ?? "default")")
            .listRowBackground(Color.appCardBackground)
        #endif
    }

    #if !DREL_RELEASE_MINIMAL_SETTINGS
    private func heroRow(item: SettingsViewModel.SettingsItem) -> some View {
        HStack(spacing: ThemeTokens.Spacing.md) {
            SettingsIconBox(
                image: item.lucideIcon?.templateImage(
                    pointSize: ThemeTokens.ComponentContract.SettingsRow.iconSize
                ),
                backgroundColor: ThemeTokens.Color.primary.withAlphaComponent(0.1),
                tintColor: ThemeTokens.Color.primary
            )

            Text(L10n.tr("settings.hero.token_format", heroMaskedToken))
                .font(Font.app(ThemeTokens.Typography.rowTitle))
                .foregroundColor(Color.appText)
                .lineLimit(1)

            Spacer()

            Button(
                action: {
                    guard let token = heroDisplayToken else {
                        heroAlert = .unset
                        return
                    }
                    // 完整推送地址（含服务器）比裸标识更有用：拿到即可直接
                    // 向该设备推送，与推送通道页「复制当前完整地址」一致。
                    UIPasteboard.general.string = "\(HTMLAppGatewayDefaults.official.baseURL)/\(token)"
                    heroAlert = .copied
                },
                label: {
                    Image(uiImage: LucideIcon.copy.templateImage(
                        pointSize: ThemeTokens.Icons.Sizes.sm
                    ) ?? UIImage())
                        .renderingMode(.template)
                        .foregroundColor(Color.appPrimary)
                        .frame(width: 44, height: 44)
                }
            )
            .accessibilityLabel(L10n.tr("settings.hero.copy_token"))
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, ThemeTokens.Spacing.sm)
    }
    #endif

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
            trailingText: item.action == .notificationSettings
                ? notificationPermissionSummary
                : item.value,
            showChevron: item.showArrow,
            isToggle: item.hasToggle,
            isToggleOn: .constant(false),
            isDestructive: false,
            badge: item.badge,
            toggleAccessibilityIdentifier: item.action.map { "settings.toggle.\($0.rawValue)" },
            onTap: {
                guard let action = item.action else { return }
                handleAction(action)
            }
        )
    }

    private func refreshNotificationPermissionSummary() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let summary: String
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                summary = "已开启"
            case .denied:
                summary = "未允许"
            case .notDetermined:
                summary = "未设置"
            @unknown default:
                summary = "未知"
            }
            DispatchQueue.main.async {
                notificationPermissionSummary = summary
            }
        }
    }

    private func handleAction(_ action: SettingsViewModel.SettingsAction) {
        switch action {
        case .serverConfig: onNavigate(.serverConfig)
        case .tokenManager: onNavigate(.tokenManage)
        case .apiKeyManage: onNavigate(.apiKeyManage)
        case .webGrants:
            #if !DREL_CONTAINER_ONLY
            onNavigate(.webGrants)
            #endif
        case .cacheManager: onNavigate(.cacheManagement)
        case .favorites: onNavigate(.favorites)
        case .history: onNavigate(.history)
        case .notificationSettings: onNavigate(.notificationSettings)
        case .pushEncryption: onNavigate(.pushEncryption)
        case .defaultStartupApp: onNavigate(.defaultStartupApp)
        case .appearance: onNavigate(.appearance)
        case .debugPanel: onNavigate(.debugPanel)
        case .cacheDashboard: onNavigate(.cacheDashboard)
        case .exportDiagnostics: onNavigate(.exportDiagnostics)
        case .debugCenter: onNavigate(.debugCenter)
        case .deepLinks: onNavigate(.deepLinks)
        case .about: onNavigate(.about)
        }
    }
}
