import SwiftUI
import UIKit
import WebBridgeKit

struct AppearanceSettingsView: View {
    @AppStorage(SettingsPreferenceKeys.appearanceMode) private var selectedMode = ThemeMode.system.rawValue

    private let modes = ThemeMode.allCases

    var body: some View {
        List {
            Section {
                Picker(L10n.tr("settings.appearance"), selection: $selectedMode) {
                    ForEach(modes, id: \.rawValue) { mode in
                        Text(title(for: mode)).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("appearance.modePicker")
                .onChange(of: selectedMode) { newValue in
                    applyMode(rawValue: newValue)
                }
            }
            .listRowBackground(Color.appCardBackground)

            Section {
                VStack(alignment: .leading, spacing: ThemeTokens.Spacing.sm) {
                    Text(title(for: mode(from: selectedMode)))
                        .font(Font.app(ThemeTokens.Typography.rowTitle))
                        .foregroundColor(Color.appText)
                    Text(description(for: mode(from: selectedMode)))
                        .font(Font.app(ThemeTokens.Typography.body))
                        .foregroundColor(Color.appTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, ThemeTokens.Spacing.xs)
                .accessibilityIdentifier("appearance.currentMode")
            }
            .listRowBackground(Color.appCardBackground)
        }
        .appListStyle()
        .listStyle(InsetGroupedListStyle())
        .navigationTitle(L10n.tr("settings.appearance"))
        .accessibilityIdentifier("appearance.root")
        .onAppear {
            applyMode(rawValue: selectedMode)
        }
    }

    private func mode(from rawValue: String) -> ThemeMode {
        ThemeMode(rawValue: rawValue) ?? .system
    }

    private func title(for mode: ThemeMode) -> String {
        switch mode {
        case .system: return L10n.tr("settings.appearance.system")
        case .light: return L10n.tr("settings.appearance.light")
        case .dark: return L10n.tr("settings.appearance.dark")
        @unknown default: return L10n.tr("settings.appearance.system")
        }
    }

    private func description(for mode: ThemeMode) -> String {
        switch mode {
        case .system: return L10n.tr("settings.appearance.system.description")
        case .light: return L10n.tr("settings.appearance.light.description")
        case .dark: return L10n.tr("settings.appearance.dark.description")
        @unknown default: return L10n.tr("settings.appearance.system.description")
        }
    }

    private func applyMode(rawValue: String) {
        let mode = mode(from: rawValue)
        Task {
            await ThemeManager.shared.apply(mode)
            await MainActor.run {
                UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .flatMap(\.windows)
                    .forEach { ThemeManager.applyMode(mode, to: $0) }
            }
        }
    }
}
