import SwiftUI
import WebBridgeKit

@MainActor
final class PWAHomeViewModel: ObservableObject {
    enum PushState: Equatable {
        case identityPreparing
        case permissionRequired
        case registering
        case ready
        case denied
        case recoverableError(String)
    }

    enum AppState {
        case loading
        case ready
        case unavailable
    }

    struct AppItem: Identifiable {
        let id: String
        let name: String
        let iconURL: URL?
        let iconCacheKey: String
        let fallbackInitial: String
        let tint: UIColor
    }

    @Published var pushURL: String
    @Published var pushState: PushState
    @Published var pushChannels: [DrelPushChannel] = []
    @Published var activePushChannelID = DrelPushChannelStore.officialChannelID
    @Published var appState: AppState = .loading
    @Published var apps: [AppItem] = []

    init(pushURL: String, pushState: PushState) {
        self.pushURL = pushURL
        self.pushState = pushState
    }

    var isPushReady: Bool { pushState == .ready }

    var activePushChannel: DrelPushChannel? {
        pushChannels.first(where: { $0.id == activePushChannelID })
    }

    var pushStatusText: String {
        switch pushState {
        case .identityPreparing: return L10n.tr("official.push.status.preparing")
        case .permissionRequired: return L10n.tr("official.push.status.permission_required")
        case .registering: return L10n.tr("official.push.status.registering")
        case .ready: return L10n.tr("official.push.status.ready")
        case .denied: return L10n.tr("official.push.status.denied")
        case .recoverableError(let message): return message
        }
    }

    var primaryActionTitle: String {
        switch pushState {
        case .ready: return L10n.tr("official.push.action.send_safari")
        case .registering: return L10n.tr("official.push.action.registering")
        case .denied: return L10n.tr("official.push.action.settings")
        case .identityPreparing: return L10n.tr("official.push.action.preparing")
        case .permissionRequired, .recoverableError: return L10n.tr("official.push.action.enable")
        }
    }
}

struct PWAHomeView: View {
    @ObservedObject var viewModel: PWAHomeViewModel

    let onSendTest: (String, String) -> Void
    let onCopyPushURL: () -> Void
    let onManagePushAddress: () -> Void
    let onConfigurePush: () -> Void
    let onSelectPushChannel: (DrelPushChannel) -> Void
    let onSelectApp: (String) -> Void
    let onManageApps: () -> Void
    let onOpenAPIExamples: () -> Void
    let onOpenGuideAndDebug: () -> Void

    @State private var pushTitle = L10n.tr("official.push.test.default_title")
    @State private var pushBody = L10n.tr("official.push.test.default_body")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.lg) {
                header
                endpointCard
                #if !DREL_RELEASE_MINIMAL_SETTINGS
                appsSection
                #endif
                testPushSection
                supportSection
            }
            .padding(.horizontal, ThemeTokens.Spacing.screenHorizontal)
            .padding(.top, ThemeTokens.Spacing.md)
            .padding(.bottom, ThemeTokens.Spacing.screenBottom + 16)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .overlay(alignment: .top) {
            StatusBarScrim()
        }
        .accessibilityIdentifier("pwaCenter.table")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.sm) {
            HStack(alignment: .center) {
                Text("Drel")
                    .font(.system(size: ThemeTokens.Typography.screenTitle.pointSize, weight: .bold))
                    .foregroundColor(Color.appText)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("pwaHome.root")

                Spacer()

                if !viewModel.pushChannels.isEmpty {
                    Menu {
                        ForEach(viewModel.pushChannels) { channel in
                            Button {
                                onSelectPushChannel(channel)
                            } label: {
                                if channel.id == viewModel.activePushChannelID {
                                    Label(channel.name, systemImage: "checkmark")
                                } else {
                                    Text(channel.name)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(viewModel.activePushChannel?.name ?? "官方 Drel")
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.semibold))
                        }
                        .font(Font.app(ThemeTokens.Typography.metadata))
                        .foregroundColor(Color.appPrimary)
                    }
                    .accessibilityIdentifier("home.push.channel-picker")
                    .accessibilityLabel("切换推送通道")
                }
            }

            Text("将推送直接送到你需要的地方")
                .font(Font.app(ThemeTokens.Typography.body))
                .foregroundColor(Color.appTextSecondary)

            HStack(spacing: ThemeTokens.Spacing.sm) {
                Circle()
                    .fill(viewModel.isPushReady ? Color.appSuccess : Color(ThemeTokens.Color.warning))
                    .frame(width: 8, height: 8)

                Text(viewModel.pushStatusText)
                    .font(Font.app(ThemeTokens.Typography.metadata))
                    .foregroundColor(viewModel.isPushReady ? Color.appSuccess : Color(ThemeTokens.Color.warning))
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("pwaHome.pushStatus")
            .overlay(
                Color.clear
                    .accessibilityLabel(viewModel.pushStatusText)
                    .accessibilityIdentifier("home.push.status")
            )
        }
    }

    private var endpointCard: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.sm) {
            HStack(spacing: ThemeTokens.Spacing.md) {
                Image(uiImage: LucideIcon.link.templateImage(pointSize: ThemeTokens.Icons.Sizes.lg) ?? UIImage())
                    .renderingMode(.template)
                    .foregroundColor(Color.appPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color(ThemeTokens.Color.primarySoft))
                    .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
                    Text(viewModel.activePushChannel?.isOfficial == false ? "自建推送地址" : "你的推送地址")
                        .font(Font.app(ThemeTokens.Typography.sectionTitle))
                        .foregroundColor(Color.appText)
                    Text("复制后即可从你的服务、脚本或网页发起推送")
                        .font(Font.app(ThemeTokens.Typography.metadata))
                        .foregroundColor(Color.appTextSecondary)
                }
            }

            HStack(spacing: ThemeTokens.Spacing.md) {
                VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
                    Text(viewModel.pushURL.isEmpty ? L10n.tr("official.push.address.pending") : viewModel.pushURL)
                        .font(Font.app(ThemeTokens.Typography.monospaceMeta))
                        .foregroundColor(Color.appTextSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .accessibilityLabel(
                            !viewModel.pushURL.isEmpty
                                ? "我的推送地址 \(viewModel.pushURL)"
                                : L10n.tr("official.push.address.pending")
                        )
                        .accessibilityIdentifier("home.push.address")
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
                // The address is generated locally before notification permission
                // is requested. Developers must be able to copy and inspect the
                // public API endpoint on first launch; permission only gates
                // delivery, not discovery of their personal endpoint.
                .disabled(viewModel.pushURL.isEmpty)
                .accessibilityIdentifier("home.push.copy")

                Button(action: onManagePushAddress) {
                    Image(uiImage: LucideIcon.ellipsis.templateImage(pointSize: ThemeTokens.Icons.Sizes.md) ?? UIImage())
                        .renderingMode(.template)
                        .foregroundColor(Color.appPrimary)
                        .frame(width: 44, height: 44)
                        .background(Color(ThemeTokens.Color.primarySoft))
                        .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md))
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityLabel("管理推送地址")
                .disabled(viewModel.pushURL.isEmpty)
                .accessibilityIdentifier("home.push.manage")
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("pwaHome.copyPushURL")

            if viewModel.pushState == .denied {
                Text(L10n.tr("official.push.permission.denied"))
                    .font(Font.app(ThemeTokens.Typography.caption))
                    .foregroundColor(Color(ThemeTokens.Color.warning))
                    .accessibilityIdentifier("home.push.permission-denied")
            }

            if !viewModel.isPushReady, !viewModel.pushURL.isEmpty {
                Text(L10n.tr("official.push.address.enable_to_receive"))
                    .font(Font.app(ThemeTokens.Typography.caption))
                    .foregroundColor(Color.appTextSecondary)
                    .accessibilityIdentifier("home.push.address.enable-to-receive")
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

    private var testPushSection: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.sm) {
            HStack(spacing: ThemeTokens.Spacing.md) {
                Image(uiImage: LucideIcon.send.templateImage(pointSize: ThemeTokens.Icons.Sizes.md) ?? UIImage())
                    .renderingMode(.template)
                    .foregroundColor(Color.appPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color(ThemeTokens.Color.primarySoft))
                    .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.sm))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
                    Text(L10n.tr("official.push.test.title"))
                        .font(Font.app(ThemeTokens.Typography.rowTitle))
                        .foregroundColor(Color.appText)
                    Text(L10n.tr("official.push.test.subtitle"))
                        .font(Font.app(ThemeTokens.Typography.metadata))
                        .foregroundColor(Color.appTextSecondary)
                }
            }

            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
                Text(L10n.tr("official.push.test.field.title"))
                    .font(Font.app(ThemeTokens.Typography.metadata))
                    .foregroundColor(Color.appTextSecondary)
                TextField(L10n.tr("official.push.test.default_title"), text: $pushTitle)
                    .font(Font.app(ThemeTokens.Typography.body))
                    .foregroundColor(Color.appText)
                    .padding(.horizontal, ThemeTokens.Spacing.md)
                    .frame(minHeight: ThemeTokens.ComponentContract.SearchField.height)
                    .background(Color.appBackground)
                    .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.row))
                    .overlay(
                        RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.row)
                            .stroke(Color.appSeparator, lineWidth: 1)
                    )
                    .accessibilityIdentifier("pwaHome.pushTitle")
                    .accessibilityLabel(L10n.tr("official.push.test.field.title"))
                    .accessibilityHint(L10n.tr("official.push.test.field.title.hint"))

                Text(L10n.tr("official.push.test.field.body"))
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
                    .accessibilityLabel(L10n.tr("official.push.test.field.body"))
                    .accessibilityHint(L10n.tr("official.push.test.field.body.hint"))
            }
            .disabled(!viewModel.isPushReady)
            // 未启用通知时主按钮是「启用通知」；先弱化表单，避免填完点按钮
            // 却触发系统授权的语义错位。
            .opacity(viewModel.isPushReady ? 1 : 0.55)

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
                    Text(viewModel.primaryActionTitle)
                }
                .font(Font.app(ThemeTokens.Typography.button))
                .foregroundColor(Color(ThemeTokens.Color.onPrimary))
                .frame(maxWidth: .infinity, minHeight: ThemeTokens.ComponentContract.Button.height)
                .background(Color.appPrimary)
                .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md))
            }
            .buttonStyle(PressScaleButtonStyle())
            .disabled(viewModel.pushState == .identityPreparing || viewModel.pushState == .registering)
            .accessibilityIdentifier("home.push.send-safari")
            .overlay(Color.clear.accessibilityIdentifier("pwaHome.sendTest"))

            Text(viewModel.isPushReady
                 ? "将在外部浏览器发起请求，返回 App 后即可收到通知"
                 : L10n.tr("official.push.help.enable"))
                .font(Font.app(ThemeTokens.Typography.caption))
                .foregroundColor(Color.appTextSecondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
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
            // 应用数量天然少：4 列自适应换行，第 5 个及以后不再被截断。
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: ThemeTokens.Spacing.sm),
                    count: 4
                ),
                spacing: ThemeTokens.Spacing.md
            ) {
                ForEach(viewModel.apps) { app in
                    installedAppTile(app)
                }

                // A lone application looked accidental in the four-column
                // app shelf. This is intentionally not an add button or a
                // fabricated "recent" entry: trusted apps only arrive after
                // a user-visible push activation.
                if viewModel.apps.count == 1 {
                    waitingAppSlot
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

    private func installedAppTile(_ app: PWAHomeViewModel.AppItem) -> some View {
        Button { onSelectApp(app.id) } label: {
            VStack(spacing: ThemeTokens.Spacing.sm) {
                PWAAppIconView(
                    iconURL: app.iconURL,
                    cacheKey: app.iconCacheKey,
                    fallbackInitial: app.fallbackInitial,
                    tint: app.tint
                )
                    .id(app.iconCacheKey)
                    .frame(width: 44, height: 44)

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

    private var waitingAppSlot: some View {
        VStack(spacing: ThemeTokens.Spacing.sm) {
            Text("待")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.appTextTertiary)
                .frame(width: 44, height: 44)
                .background(Color.appBackground)
                .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.sm)
                        .stroke(
                            Color.appSeparator,
                            style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                        )
                )

            Text("虚位以待")
                .font(Font.app(ThemeTokens.Typography.caption))
                .foregroundColor(Color.appTextTertiary)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("虚位以待")
        .accessibilityHint("新的私有应用会在收到并打开对应推送后显示在这里")
        .accessibilityIdentifier("pwaHome.appPlaceholder")
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
        case .unavailable: return "暂时没有可用的应用"
        }
    }

    private var emptyAppsSubtitle: String {
        switch viewModel.appState {
        case .loading: return "正在校验受签名的应用清单"
        case .ready: return "连接官方或自部署应用服务"
        case .unavailable: return "点按管理应用服务，稍后会自动重试"
        }
    }

    private var supportSection: some View {
        VStack(spacing: 0) {
            supportRow(
                title: releaseExamplesTitle,
                subtitle: releaseExamplesSubtitle,
                icon: .terminal,
                identifier: "pwaHome.apiExamples",
                action: onOpenAPIExamples
            )

            #if !DREL_RELEASE_MINIMAL_SETTINGS
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
            #endif
        }
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.card)
                .stroke(Color.appSeparator, lineWidth: 1)
        )
    }

    private var releaseExamplesTitle: String {
#if DREL_CONTAINER_ONLY
        return "推送示例"
#else
        return "全部 API 示例"
#endif
    }

    private var releaseExamplesSubtitle: String {
#if DREL_CONTAINER_ONLY
        return "文本通知、点击打开网页与铃声提示"
#else
        return "普通、Markdown、验证码、二维码、图片、聊天、审批"
#endif
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

/// Fades scrolled content out before it reaches the status bar / Dynamic
/// Island. The home ScrollView is intentionally full-bleed; without this
/// scrim the address card and hint row collide with the system clock while
/// scrolling.
private struct StatusBarScrim: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: Color.appBackground, location: 0),
                .init(color: Color.appBackground, location: 0.45),
                .init(color: Color.appBackground.opacity(0), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 64)
        .frame(maxWidth: .infinity)
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
