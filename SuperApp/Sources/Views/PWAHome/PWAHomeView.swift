import SwiftUI
import WebBridgeKit

@MainActor
final class PWAHomeViewModel: ObservableObject {
    enum AppState {
        case loading
        case ready
        case unavailable
    }

    struct AppItem: Identifiable {
        let id: String
        let name: String
        let icon: LucideIcon
        let tint: UIColor
    }

    @Published var pushURL: String
    @Published var isPushReady: Bool
    @Published var appState: AppState = .loading
    @Published var apps: [AppItem] = []

    init(pushURL: String, isPushReady: Bool) {
        self.pushURL = pushURL
        self.isPushReady = isPushReady
    }
}

struct PWAHomeView: View {
    @ObservedObject var viewModel: PWAHomeViewModel

    let onSendTest: (String, String) -> Void
    let onCopyPushURL: () -> Void
    let onConfigurePush: () -> Void
    let onSelectApp: (String) -> Void
    let onManageApps: () -> Void
    let onOpenAPIExamples: () -> Void
    let onOpenGuideAndDebug: () -> Void

    @State private var pushTitle = "测试通知"
    @State private var pushBody = "你好，这是一条来自 WebBridgeKit 的消息"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.lg) {
                header
                firstPushCard
                appsSection
                supportSection
            }
            .padding(.horizontal, ThemeTokens.Spacing.screenHorizontal)
            .padding(.top, ThemeTokens.Spacing.md)
            .padding(.bottom, ThemeTokens.Spacing.screenBottom + 16)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .accessibilityIdentifier("pwaCenter.table")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.sm) {
            Text("WebBridgeKit")
                .font(.system(size: ThemeTokens.Typography.screenTitle.pointSize, weight: .bold))
                .foregroundColor(Color.appText)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("pwaHome.root")

            HStack(spacing: ThemeTokens.Spacing.sm) {
                Circle()
                    .fill(viewModel.isPushReady ? Color.appSuccess : Color(ThemeTokens.Color.warning))
                    .frame(width: 8, height: 8)

                Text(viewModel.isPushReady ? "可以接收通知" : "先配置推送地址")
                    .font(Font.app(ThemeTokens.Typography.metadata))
                    .foregroundColor(viewModel.isPushReady ? Color.appSuccess : Color(ThemeTokens.Color.warning))
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("pwaHome.pushStatus")
        }
    }

    private var firstPushCard: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.sm) {
            HStack(spacing: ThemeTokens.Spacing.md) {
                Image(uiImage: LucideIcon.send.templateImage(pointSize: ThemeTokens.Icons.Sizes.lg) ?? UIImage())
                    .renderingMode(.template)
                    .foregroundColor(Color.appPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color(ThemeTokens.Color.primarySoft))
                    .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md))

                VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
                    Text("发送第一条通知")
                        .font(.system(size: ThemeTokens.Typography.sectionTitle.pointSize, weight: .semibold))
                        .foregroundColor(Color.appText)
                    Text("输入标题和内容，立即测试推送效果")
                        .font(Font.app(ThemeTokens.Typography.metadata))
                        .foregroundColor(Color.appTextSecondary)
                }
            }

            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
                Text("标题")
                    .font(Font.app(ThemeTokens.Typography.metadata))
                    .foregroundColor(Color.appTextSecondary)
                TextField("测试通知", text: $pushTitle)
                    .font(Font.app(ThemeTokens.Typography.body))
                    .foregroundColor(Color.appText)
                    .padding(.horizontal, ThemeTokens.Spacing.md)
                    .frame(minHeight: 44)
                    .background(Color.appBackground)
                    .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.row))
                    .overlay(
                        RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.row)
                            .stroke(Color.appSeparator, lineWidth: 1)
                    )
                    .accessibilityIdentifier("pwaHome.pushTitle")

                Text("内容")
                    .font(Font.app(ThemeTokens.Typography.metadata))
                    .foregroundColor(Color.appTextSecondary)
                TextEditor(text: $pushBody)
                    .font(Font.app(ThemeTokens.Typography.body))
                    .foregroundColor(Color.appText)
                    .padding(ThemeTokens.Spacing.sm)
                    .frame(minHeight: 60)
                    .background(Color.appBackground)
                    .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.row))
                    .overlay(
                        RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.row)
                            .stroke(Color.appSeparator, lineWidth: 1)
                    )
                    .accessibilityIdentifier("pwaHome.pushBody")
            }

            Button {
                if viewModel.isPushReady {
                    onSendTest(pushTitle, pushBody)
                } else {
                    onConfigurePush()
                }
            } label: {
                HStack(spacing: ThemeTokens.Spacing.sm) {
                    Image(uiImage: LucideIcon.compass.templateImage(pointSize: ThemeTokens.Icons.Sizes.sm) ?? UIImage())
                        .renderingMode(.template)
                    Text(viewModel.isPushReady ? "用 Safari 发送测试" : "配置推送地址")
                }
                .font(.system(size: ThemeTokens.Typography.button.pointSize, weight: .semibold))
                .foregroundColor(Color(ThemeTokens.Color.onPrimary))
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color.appPrimary)
                .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md))
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityIdentifier("pwaHome.sendTest")

            Text(viewModel.isPushReady
                 ? "将在外部浏览器发起请求，返回 App 后即可收到通知"
                 : "先生成设备 Key，之后即可通过浏览器验证真实推送")
                .font(Font.app(ThemeTokens.Typography.caption))
                .foregroundColor(Color.appTextSecondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            Divider().overlay(Color.appSeparator)

            HStack(spacing: ThemeTokens.Spacing.md) {
                VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
                    Text("我的推送地址")
                        .font(Font.app(ThemeTokens.Typography.metadata))
                        .foregroundColor(Color.appText)
                    Text(viewModel.pushURL)
                        .font(Font.app(ThemeTokens.Typography.monospaceMeta))
                        .foregroundColor(Color.appTextSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .accessibilityIdentifier("pwaHome.pushURL")
                }

                Spacer(minLength: ThemeTokens.Spacing.sm)

                Button(action: onCopyPushURL) {
                    Image(uiImage: LucideIcon.copy.templateImage(pointSize: ThemeTokens.Icons.Sizes.md) ?? UIImage())
                        .renderingMode(.template)
                        .foregroundColor(Color.appPrimary)
                        .frame(width: 44, height: 44)
                        .background(Color(ThemeTokens.Color.primarySoft))
                        .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md))
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityLabel("复制推送地址")
                .accessibilityIdentifier("pwaHome.copyPushURL")
            }
        }
        .padding(ThemeTokens.Spacing.md)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.card)
                .stroke(Color.appSeparator, lineWidth: 1)
        )
    }

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.md) {
            HStack {
                Text("我的应用")
                    .font(.system(size: ThemeTokens.Typography.sectionTitle.pointSize, weight: .semibold))
                    .foregroundColor(Color.appText)
                    .accessibilityIdentifier("pwaHome.appsSection")
                Spacer()
                Button("管理", action: onManageApps)
                    .font(.system(size: ThemeTokens.Typography.buttonMedium.pointSize, weight: .medium))
                    .foregroundColor(Color.appPrimary)
                    .accessibilityIdentifier("pwaHome.manageApps")
            }

            Group {
                if viewModel.apps.isEmpty {
                    emptyApps
                } else {
                    installedApps
                }
            }
        }
    }

    private var installedApps: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: ThemeTokens.Spacing.sm) {
                ForEach(viewModel.apps.prefix(4)) { app in
                    Button { onSelectApp(app.id) } label: {
                        VStack(spacing: ThemeTokens.Spacing.sm) {
                            Image(uiImage: app.icon.templateImage(pointSize: ThemeTokens.Icons.Sizes.lg) ?? UIImage())
                                .renderingMode(.template)
                                .foregroundColor(Color(app.tint))
                                .frame(width: 44, height: 44)
                                .background(Color(app.tint).opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md))

                            Text(app.name)
                                .font(Font.app(ThemeTokens.Typography.caption))
                                .foregroundColor(Color.appText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                                .frame(maxWidth: .infinity)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityIdentifier("pwaHome.app.\(app.id)")
                }
            }
            .padding(ThemeTokens.Spacing.md)

            Divider().overlay(Color.appSeparator)

            Button(action: onManageApps) {
                HStack {
                    Text("点击应用进入详情与配置")
                        .font(Font.app(ThemeTokens.Typography.metadata))
                        .foregroundColor(Color.appTextSecondary)
                    Spacer()
                    Image(uiImage: LucideIcon.chevronRight.templateImage(pointSize: ThemeTokens.Icons.Sizes.chevron) ?? UIImage())
                        .renderingMode(.template)
                        .foregroundColor(Color.appTextTertiary)
                }
                .padding(.horizontal, ThemeTokens.Spacing.lg)
                .frame(minHeight: 44)
            }
            .buttonStyle(PressScaleButtonStyle())
        }
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.card)
                .stroke(Color.appSeparator, lineWidth: 1)
        )
    }

    private var emptyApps: some View {
        Button(action: onManageApps) {
            HStack(spacing: ThemeTokens.Spacing.md) {
                Image(uiImage: LucideIcon.plus.templateImage(pointSize: ThemeTokens.Icons.Sizes.md) ?? UIImage())
                    .renderingMode(.template)
                    .foregroundColor(Color.appPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color(ThemeTokens.Color.primarySoft))
                    .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md))

                VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
                    Text(emptyAppsTitle)
                        .font(.system(size: ThemeTokens.Typography.rowTitle.pointSize, weight: .medium))
                        .foregroundColor(Color.appText)
                    Text(emptyAppsSubtitle)
                        .font(Font.app(ThemeTokens.Typography.metadata))
                        .foregroundColor(Color.appTextSecondary)
                }
                Spacer()
                Image(uiImage: LucideIcon.chevronRight.templateImage(pointSize: ThemeTokens.Icons.Sizes.chevron) ?? UIImage())
                    .renderingMode(.template)
                    .foregroundColor(Color.appTextTertiary)
            }
            .padding(ThemeTokens.Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(Color.appCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.card)
                    .stroke(Color.appSeparator, lineWidth: 1)
            )
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityIdentifier("pwaHome.emptyApps")
    }

    private var emptyAppsTitle: String {
        switch viewModel.appState {
        case .loading: return "正在连接应用服务"
        case .ready: return "还没有添加应用"
        case .unavailable: return "应用服务暂不可用"
        }
    }

    private var emptyAppsSubtitle: String {
        switch viewModel.appState {
        case .loading: return "正在校验受签名的应用清单"
        case .ready: return "连接官方或自部署应用服务"
        case .unavailable: return "点击重试或连接自有服务"
        }
    }

    private var supportSection: some View {
        VStack(spacing: 0) {
            supportRow(
                title: "全部 API 示例",
                subtitle: "普通、Markdown、验证码、二维码、图片、聊天、审批",
                icon: .terminal,
                identifier: "pwaHome.apiExamples",
                action: onOpenAPIExamples
            )

            Divider()
                .overlay(Color.appSeparator)
                .padding(.leading, 60)

            supportRow(
                title: "手册与调试",
                subtitle: "接入文档、日志、网络与缓存工具",
                icon: .docText,
                identifier: "pwaHome.guideAndDebug",
                action: onOpenGuideAndDebug
            )
        }
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.card)
                .stroke(Color.appSeparator, lineWidth: 1)
        )
    }

    private func supportRow(
        title: String,
        subtitle: String,
        icon: LucideIcon,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: ThemeTokens.Spacing.md) {
                Image(uiImage: icon.templateImage(pointSize: ThemeTokens.Icons.Sizes.md) ?? UIImage())
                    .renderingMode(.template)
                    .foregroundColor(Color.appPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color(ThemeTokens.Color.primarySoft))
                    .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.sm))

                VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
                    Text(title)
                        .font(.system(size: ThemeTokens.Typography.rowTitle.pointSize, weight: .medium))
                        .foregroundColor(Color.appText)
                    Text(subtitle)
                        .font(Font.app(ThemeTokens.Typography.metadata))
                        .foregroundColor(Color.appTextSecondary)
                        .lineLimit(2)
                }
                Spacer(minLength: ThemeTokens.Spacing.sm)
                Image(uiImage: LucideIcon.chevronRight.templateImage(pointSize: ThemeTokens.Icons.Sizes.chevron) ?? UIImage())
                    .renderingMode(.template)
                    .foregroundColor(Color.appTextTertiary)
            }
            .padding(.horizontal, ThemeTokens.Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: 64)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityIdentifier(identifier)
    }
}
