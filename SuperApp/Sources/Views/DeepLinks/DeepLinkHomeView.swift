import SwiftUI
import WebBridgeKit

struct DeepLinkHomeView: View {
    let onAction: (DeepLinkAction) -> Void

    @StateObject private var viewModel = DeepLinkHomeViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xxl) {
                ModuleHeaderView(
                    title: "Links",
                    subtitle: "协议跳转、URL 参数与命令路由",
                    icon: .link,
                    accessibilityIdentifier: "moduleHeader.links"
                )
                ServiceStatusStrip(items: viewModel.serviceItems)
                templateSection
                builderSection
                commandSection
                ResultPanel(
                    title: "协议结果",
                    state: viewModel.resultState,
                    detail: viewModel.resultDetail.isEmpty ? nil : viewModel.resultDetail,
                    copyAction: viewModel.copyResult
                )
            }
            .padding(.horizontal, ThemeTokens.Spacing.screenHorizontal)
            .padding(.top, ThemeTokens.Spacing.screenTop)
            .padding(.bottom, ThemeTokens.Spacing.screenBottom + 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Links")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("deepLink.home")
    }

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.md) {
            Text("模板")
                .font(Font.app(ThemeTokens.Typography.sectionTitle))
                .foregroundColor(Color.appText)

            ForEach(viewModel.templates) { template in
                ActionRow(
                    title: template.title,
                    subtitle: template.subtitle,
                    icon: template.icon,
                    accessibilityIdentifier: "deepLink.template.\(template.id)",
                    badge: template.id == viewModel.selectedTemplateID ? "Selected" : nil,
                    badgeTone: .success,
                    action: { viewModel.selectTemplate(template) }
                )
            }
        }
    }

    private var builderSection: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.md) {
            HStack {
                Text("Open 链接")
                    .font(Font.app(ThemeTokens.Typography.sectionTitle))
                    .foregroundColor(Color.appText)
                Spacer()
                StatusBadge(title: viewModel.modeTitle(viewModel.displayMode), tone: .info)
            }

            TextField("https://example.com", text: $viewModel.targetURLText)
                .font(Font.app(ThemeTokens.Typography.body))
                .foregroundColor(Color.appText)
                .padding(.horizontal, ThemeTokens.Spacing.md)
                .frame(minHeight: 44)
                .background(Color(ThemeTokens.Color.surface))
                .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md)
                        .stroke(Color.appSeparator, lineWidth: 1)
                )
                .accessibilityIdentifier("deepLink.targetURLInput")

            modePicker
            CodeBlockView(title: "webbridgekit://open", text: viewModel.generatedOpenScheme, maxHeight: 120)
                .accessibilityIdentifier("deepLink.generatedOpenScheme")

            HStack(spacing: ThemeTokens.Spacing.md) {
                primaryButton(title: "校验", action: viewModel.validateOpenScheme)
                    .accessibilityIdentifier("deepLink.validateOpenButton")
                iconButton(icon: .copy, action: viewModel.copyOpenScheme)
                    .accessibilityIdentifier("deepLink.copyOpenButton")
                iconButton(icon: .send) {
                    if let action = viewModel.openTargetAction() {
                        onAction(action)
                    }
                }
                .accessibilityIdentifier("deepLink.openTargetButton")
            }
        }
    }

    private var modePicker: some View {
        HStack(spacing: ThemeTokens.Spacing.sm) {
            modeButton(title: "Normal", mode: .normal)
            modeButton(title: "Immersive", mode: .immersive)
            modeButton(title: "Modal", mode: .modal)
        }
        .accessibilityIdentifier("deepLink.modePicker")
    }

    private func modeButton(title: String, mode: WebBrowserParams.DisplayMode) -> some View {
        Button(
            action: { viewModel.displayMode = mode },
            label: {
                Text(title)
                    .font(Font.app(ThemeTokens.Typography.buttonMedium))
                    .foregroundColor(viewModel.displayMode == mode ? Color(ThemeTokens.Color.onPrimary) : Color.appText)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(viewModel.displayMode == mode ? Color.appPrimary : Color(ThemeTokens.Color.surface))
                    .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md))
            }
        )
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityIdentifier("deepLink.mode.\(viewModel.modeTitle(mode))")
    }

    private var commandSection: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.md) {
            Text("Command / Tab")
                .font(Font.app(ThemeTokens.Typography.sectionTitle))
                .foregroundColor(Color.appText)

            TextField("command token", text: $viewModel.commandToken)
                .font(Font.app(ThemeTokens.Typography.monospaceBody))
                .foregroundColor(Color.appText)
                .padding(.horizontal, ThemeTokens.Spacing.md)
                .frame(minHeight: 44)
                .background(Color(ThemeTokens.Color.surface))
                .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md)
                        .stroke(Color.appSeparator, lineWidth: 1)
                )
                .accessibilityIdentifier("deepLink.commandTokenInput")

            CodeBlockView(title: "webbridgekit://command", text: viewModel.generatedCommandScheme, maxHeight: 88)
            HStack(spacing: ThemeTokens.Spacing.md) {
                primaryButton(title: "复制 Command", action: viewModel.copyCommandScheme)
                    .accessibilityIdentifier("deepLink.copyCommandButton")
                iconButton(icon: .send) {
                    if let url = URL(string: viewModel.generatedCommandScheme) {
                        onAction(.openScheme(url))
                    }
                }
                .accessibilityIdentifier("deepLink.openCommandButton")
            }

            TextField("tab index", text: $viewModel.tabIndexText)
                .font(Font.app(ThemeTokens.Typography.monospaceBody))
                .foregroundColor(Color.appText)
                .padding(.horizontal, ThemeTokens.Spacing.md)
                .frame(minHeight: 44)
                .background(Color(ThemeTokens.Color.surface))
                .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md)
                        .stroke(Color.appSeparator, lineWidth: 1)
                )
                .accessibilityIdentifier("deepLink.tabIndexInput")

            CodeBlockView(title: "webbridgekit://tab", text: viewModel.generatedTabScheme, maxHeight: 88)
            HStack(spacing: ThemeTokens.Spacing.md) {
                primaryButton(title: "复制 Tab", action: viewModel.copyTabScheme)
                    .accessibilityIdentifier("deepLink.copyTabButton")
                iconButton(icon: .arrowRight) {
                    onAction(viewModel.switchTabAction())
                }
                .accessibilityIdentifier("deepLink.switchTabButton")
            }
        }
    }

    private func primaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(
            action: action,
            label: {
                Text(title)
                    .font(Font.app(ThemeTokens.Typography.button))
                    .foregroundColor(Color(ThemeTokens.Color.onPrimary))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.appPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md))
            }
        )
        .buttonStyle(PressScaleButtonStyle())
    }

    private func iconButton(icon: LucideIcon, action: @escaping () -> Void) -> some View {
        Button(
            action: action,
            label: {
                Image(uiImage: icon.templateImage(pointSize: ThemeTokens.Icons.Sizes.md) ?? UIImage())
                    .renderingMode(.template)
                    .foregroundColor(Color.appText)
                    .frame(width: 52, height: 44)
                    .background(Color(ThemeTokens.Color.surface))
                    .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md))
            }
        )
        .buttonStyle(PressScaleButtonStyle())
    }
}
