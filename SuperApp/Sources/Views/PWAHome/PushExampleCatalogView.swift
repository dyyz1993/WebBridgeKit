import SwiftUI
import WebBridgeKit

/// One Bark-style push capability example: display metadata plus the exact
/// title/body/query items that build the ready-to-copy URL.
struct PushExample: Identifiable {
    enum Group: String, CaseIterable {
        case content
        case presentation
        case behavior

        var title: String {
            switch self {
            case .content: return "内容类型"
            case .presentation: return "呈现参数"
            case .behavior: return "行为参数"
            }
        }
    }

    let id: String
    let title: String
    let subtitle: String
    let icon: LucideIcon
    let group: Group
    let pushTitle: String
    let pushBody: String
    let queryItems: [URLQueryItem]
    /// Optional in-card notification preview (Bark ships static screenshots
    /// for its icon/group/critical/copy cards; we render them natively).
    var preview: Preview?

    enum Preview {
        case banner(title: String, body: String, iconURL: URL? = nil, alertStyle: Bool = false)
        case grouped(groupName: String, count: Int, title: String, body: String)
        /// The system banner keeps the Drel App Icon; a remote `icon` is the
        /// avatar rendered later in Drel's Inbox and message detail.
        case customIcon(title: String, body: String, iconURL: URL)
        case autoCopy(title: String, body: String, value: String)
    }
}

extension PushExample {

    /// The complete development catalog. Store builds deliberately publish a
    /// smaller subset below: an example must be part of the current product
    /// promise, not merely a parser or framework capability.
    private static let base: [PushExample] = [
        // MARK: 内容类型
        PushExample(
            id: "bodyOnly",
            title: "仅正文",
            subtitle: "最短 Bark 兼容地址，只提供通知正文",
            icon: .docText,
            group: .content,
            pushTitle: "",
            pushBody: "这是一条只包含正文的通知",
            queryItems: []
        ),
        PushExample(
            id: "plain",
            title: "普通通知",
            subtitle: "标题与普通正文",
            icon: .bell,
            group: .content,
            pushTitle: "测试通知",
            pushBody: "你好，这是一条来自 Drel 的消息",
            queryItems: []
        ),
        PushExample(
            id: "markdown",
            title: "Markdown",
            subtitle: "标题、清单、表格、代码块与安全链接",
            icon: .docText,
            group: .content,
            pushTitle: "部署完成",
            pushBody: "## 发布结果\n\n- [x] 部署完成\n- [ ] 观察错误率\n\n| 指标 | 当前值 |\n| --- | ---: |\n| 错误率 | 0.02% |",
            queryItems: [
                URLQueryItem(name: "contentType", value: "markdown"),
                URLQueryItem(name: "markdown", value: "1")
            ]
        ),
        PushExample(
            id: "otp",
            title: "验证码",
            subtitle: "验证码与有效期",
            icon: .key,
            group: .content,
            pushTitle: "登录验证码",
            pushBody: "验证码 482901，5 分钟内有效",
            queryItems: [
                URLQueryItem(name: "contentType", value: "otp"),
                URLQueryItem(name: "category", value: "otp"),
                URLQueryItem(name: "verificationCode", value: "482901"),
                URLQueryItem(name: "ttl", value: "300")
            ]
        ),
        PushExample(
            id: "qr",
            title: "二维码",
            subtitle: "由宿主生成可扫描二维码",
            icon: .qrCode,
            group: .content,
            pushTitle: "扫码登录",
            pushBody: "使用 Drel 扫描此二维码",
            queryItems: [
                URLQueryItem(name: "contentType", value: "qr"),
                URLQueryItem(name: "qrPayload", value: "webbridgekit://login/example")
            ]
        ),
        PushExample(
            id: "image",
            title: "图片",
            subtitle: "远程图片和可读失败降级",
            icon: .image,
            group: .content,
            pushTitle: "图片预览",
            pushBody: "查看远程图片及加载失败降级",
            queryItems: [
                URLQueryItem(name: "contentType", value: "image"),
                URLQueryItem(
                    name: "image",
                    value: "https://drel.app/assets/drel-message-avatar.png"
                )
            ]
        ),
        PushExample(
            id: "chat",
            title: "聊天",
            subtitle: "定位到受信任 PWA 会话",
            icon: .paperplane,
            group: .content,
            pushTitle: "Team Chat 新消息",
            pushBody: "部署日志已经补充好了",
            queryItems: [
                URLQueryItem(name: "contentType", value: "chat"),
                URLQueryItem(name: "category", value: "chat"),
                URLQueryItem(name: "appId", value: "com.webbridgekit.fixture.chat"),
                // 路由必须在网关清单的白名单内，且是 startURL 主机上真实
                // 存在的路径（resolver 会用它替换 startURL 的 path），否则
                // 横幅点击会被路由校验拒绝或落到 404 白屏。
                URLQueryItem(name: "route", value: "/test_resources/pwa-notification/index.html")
            ]
        ),
        PushExample(
            id: "approval",
            title: "审批",
            subtitle: "预览待确认状态；完整交互使用 Approval v1 POST",
            icon: .clipboard,
            group: .content,
            pushTitle: "需要确认生产发布",
            pushBody: "版本已经通过检查，等待你的决定",
            queryItems: [
                URLQueryItem(name: "contentType", value: "approval"),
                URLQueryItem(name: "category", value: "approval"),
                URLQueryItem(name: "requestId", value: "approval-browser-example"),
                URLQueryItem(name: "actionState", value: "pending")
            ]
        ),

        // MARK: 呈现参数
        PushExample(
            id: "sound",
            title: "铃声",
            subtitle: "收到通知时播放指定提示音",
            icon: .volume,
            group: .presentation,
            pushTitle: "铃声通知",
            pushBody: "这条通知会播放 alarm 提示音",
            queryItems: [
                URLQueryItem(name: "sound", value: "alarm.caf")
            ]
        ),
        PushExample(
            id: "icon",
            title: "自定义图标",
            subtitle: "系统通知保持 Drel 图标；消息头像显示在收件箱和详情中",
            icon: .appBadge,
            group: .presentation,
            pushTitle: "自定义图标",
            pushBody: "打开 Drel 收件箱查看此消息的自定义头像",
            queryItems: [
                URLQueryItem(
                    name: "icon",
                    value: "https://drel.app/assets/drel-message-avatar.png"
                )
            ],
            preview: .customIcon(
                title: "自定义图标",
                body: "打开 Drel 收件箱查看此消息的自定义头像",
                iconURL: URL(string: "https://drel.app/assets/drel-message-avatar.png")!
            )
        ),
        PushExample(
            id: "group",
            title: "消息分组",
            subtitle: "相同分组的通知在通知中心折叠展示",
            icon: .folder,
            group: .presentation,
            pushTitle: "开发通知",
            pushBody: "分组示例：feature 分支单元测试失败",
            queryItems: [
                URLQueryItem(name: "group", value: "dev")
            ],
            preview: .grouped(
                groupName: "开发通知",
                count: 3,
                title: "开发通知",
                body: "分组示例：feature 分支单元测试失败"
            )
        ),
        PushExample(
            id: "timeSensitive",
            title: "时效性通知",
            subtitle: "即使专注模式开启也会亮屏提示",
            icon: .clock,
            group: .presentation,
            pushTitle: "时效性通知",
            pushBody: "这条通知会请求时效性呈现",
            queryItems: [
                URLQueryItem(name: "level", value: "timeSensitive")
            ]
        ),
        PushExample(
            id: "badge",
            title: "角标",
            subtitle: "更新应用图标角标数字",
            icon: .tag,
            group: .presentation,
            pushTitle: "角标更新",
            pushBody: "应用角标将设置为 1",
            queryItems: [
                URLQueryItem(name: "badge", value: "1")
            ]
        ),
        PushExample(
            id: "badgeClear",
            title: "清除角标",
            subtitle: "将应用图标角标恢复为零",
            icon: .tag,
            group: .presentation,
            pushTitle: "角标已清除",
            pushBody: "应用图标角标将恢复为 0",
            queryItems: [
                URLQueryItem(name: "badge", value: "0")
            ]
        ),
        PushExample(
            id: "subtitle",
            title: "副标题",
            subtitle: "标题下方展示灰色附加信息",
            icon: .doc,
            group: .presentation,
            pushTitle: "副标题示例",
            pushBody: "通知可以同时展示标题、副标题和正文",
            queryItems: [
                URLQueryItem(name: "subtitle", value: "来自 Drel")
            ]
        ),

        // MARK: 行为参数
        PushExample(
            id: "url",
            title: "点击跳转",
            subtitle: "点击通知在应用内浏览器打开指定网页",
            icon: .link,
            group: .behavior,
            pushTitle: "点击跳转",
            pushBody: "点击这条通知会在应用内打开网页",
            queryItems: [
                URLQueryItem(
                    name: "url",
                    value: "https://drel.app/"
                )
            ]
        ),
        PushExample(
            id: "copyManual",
            title: "复制内容",
            subtitle: "长按系统通知或进入详情后复制指定内容",
            icon: .copy,
            group: .behavior,
            pushTitle: "复制测试",
            pushBody: "展开通知后可复制验证码",
            queryItems: [
                URLQueryItem(name: "copy", value: "482901")
            ]
        ),
        PushExample(
            id: "copy",
            title: "自动复制",
            subtitle: "收到通知自动复制验证码等内容到剪贴板",
            icon: .copy,
            group: .behavior,
            pushTitle: "自动复制",
            pushBody: "验证码已随通知附带，可自动复制",
            queryItems: [
                URLQueryItem(name: "copy", value: "WBK-482901"),
                URLQueryItem(name: "autoCopy", value: "1")
            ],
            preview: .autoCopy(
                title: "自动复制",
                body: "验证码已随通知附带，可自动复制",
                value: "WBK-482901"
            )
        ),
        PushExample(
            id: "call",
            title: "电话提醒",
            subtitle: "连续播放提醒音，适合重要告警",
            icon: .bell,
            group: .behavior,
            pushTitle: "电话提醒",
            pushBody: "重要告警：服务已恢复",
            queryItems: [
                URLQueryItem(name: "call", value: "1")
            ]
        ),
        PushExample(
            id: "archive",
            title: "归档保留",
            subtitle: "通知写入历史记录，可在收件箱回看",
            icon: .bookmark,
            group: .behavior,
            pushTitle: "归档通知",
            pushBody: "这条通知会写入历史记录",
            queryItems: [
                URLQueryItem(name: "isArchive", value: "1")
            ]
        ),
        PushExample(
            id: "replace",
            title: "覆盖与撤回",
            subtitle: "相同 id 的后续推送覆盖旧通知",
            icon: .refresh,
            group: .behavior,
            pushTitle: "覆盖通知",
            pushBody: "再次发送相同 id 会覆盖这条通知",
            queryItems: [
                URLQueryItem(name: "id", value: "wbk-demo-replace")
            ]
        ),
        PushExample(
            id: "recall",
            title: "撤回通知",
            subtitle: "用相同 id 和 delete=1 移除通知与本地历史",
            icon: .trash,
            group: .behavior,
            pushTitle: "撤回通知",
            pushBody: "撤回 wbk-demo-replace",
            queryItems: [
                URLQueryItem(name: "id", value: "wbk-demo-replace"),
                URLQueryItem(name: "delete", value: "1")
            ]
        )
    ]

    /// Critical Alerts requires an Apple-reviewed entitlement that Drel 1.0
    /// does not request. Keep the debug example for future entitlement work,
    /// but compile it out of the Store container's catalog.
#if !DREL_CONTAINER_ONLY
    private static let criticalExample = PushExample(
        id: "critical",
        title: "重要警告",
        subtitle: "突破静音和勿扰（需系统授权重要警告）",
        icon: .warning,
        group: .presentation,
        pushTitle: "重要警告",
        pushBody: "Something critical has happened!",
        queryItems: [
            URLQueryItem(name: "level", value: "critical"),
            URLQueryItem(name: "volume", value: "5")
        ],
        preview: .banner(
            title: "重要警告",
            body: "Something critical has happened!",
            alertStyle: true
        )
    )
#endif

    static var all: [PushExample] {
        var examples = base
#if DREL_CONTAINER_ONLY
        // Drel 1.0 is a developer push utility, so Store builds should expose
        // every implemented push/presentation behavior that belongs to that
        // product promise. Only omit capabilities outside the V1 boundary:
        // managed HTML-app chat/approval routes, Apple's separately entitled
        // Critical Alerts, and call=1 long-ringtone synthesis (known to have
        // caused SpringBoard instability on a supported iOS release).
        let releaseExampleIDs: Set<String> = [
            "bodyOnly", "plain", "markdown", "otp", "qr", "image",
            "sound", "icon", "group", "timeSensitive", "badge", "badgeClear", "subtitle",
            "url", "copyManual", "copy", "archive", "replace", "recall"
        ]
        examples = examples.filter { releaseExampleIDs.contains($0.id) }
#else
#if !DREL_CONTAINER_ONLY
        if let timeSensitiveIndex = examples.firstIndex(where: { $0.id == "timeSensitive" }) {
            examples.insert(criticalExample, at: timeSensitiveIndex + 1)
        }
#endif
#endif
        return examples
    }

    static func example(id: String) -> PushExample? {
        all.first { $0.id == id }
    }

    /// The parameter contract shown on the card (Bark's `queryParameter`
    /// pattern): the useful part of the URL without the device-key noise.
    /// Every catalog card shows this line. A body-only or normal notification
    /// has no URL query items, which is useful information in its own right.
    var spec: String {
        guard !queryItems.isEmpty else { return "无额外 URL 参数" }
        // 零宽空格让换行落在参数边界，而不是把 ttl=300 之类的词拆成两半。
        return queryItems
            .compactMap { item in item.value.map { "\(item.name)=\($0)" } }
            .joined(separator: "&\u{200B}")
    }
}

/// Bark-style capability catalog: each card pairs a description and its
/// parameter spec with two compact developer actions: send the complete URL
/// in Safari or copy that URL for a script or another developer tool.
struct PushExampleCatalogView: View {
    /// The send icon opens the complete Bark-compatible URL in Safari. There
    /// is intentionally no separate in-app test-send action.
    let onSend: (PushExample) -> Void
    /// Copy keeps the complete developer URL available without adding text
    /// buttons to every card.
    let onCopy: (PushExample) -> Void
    /// Opens the ringtone picker from the sound card (Bark's "view all
    /// sounds" entry).
    let onOpenSounds: () -> Void
    /// URL pushes are ordinary browser pages by default. This per-card option
    /// adds the existing Bark-compatible `mode=immersive` parameter only when
    /// the developer explicitly wants the destination to occupy the screen.
    @State private var urlOpensFullscreen = false

    var body: some View {
        List {
            ForEach(PushExample.Group.allCases, id: \.rawValue) { group in
                Section(header: Text(group.title)) {
                    ForEach(PushExample.all.filter { $0.group == group }) { example in
                        exampleCard(example)
                    }
                }
            }
        }
        .appListStyle()
        .navigationTitle(catalogTitle)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("pushExamples.list")
    }

    private var catalogTitle: String {
#if DREL_CONTAINER_ONLY
        return "推送示例"
#else
        return "API 示例"
#endif
    }

    private func exampleCard(_ example: PushExample) -> some View {
        // Vertical rhythm mirrors Bark's PreviewCardCell: title row, action
        // row, preview, parameter spec, then description. The title area is
        // deliberately NOT tappable so no accidental card tap fires a push.
        let deliveryExample = exampleForDelivery(example)
        return VStack(alignment: .leading, spacing: ThemeTokens.Spacing.sm) {
            HStack(spacing: ThemeTokens.Spacing.md) {
                HStack(spacing: ThemeTokens.Spacing.md) {
                    Image(uiImage: example.icon.templateImage(pointSize: ThemeTokens.Icons.Sizes.md) ?? UIImage())
                        .renderingMode(.template)
                        .foregroundColor(Color.appPrimary)
                        .frame(width: 36, height: 36)
                        .background(Color(ThemeTokens.Color.primarySoft))
                        .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.sm))

                    Text(example.title)
                        .font(.system(size: ThemeTokens.Typography.rowTitle.pointSize, weight: .medium))
                        .foregroundColor(Color.appText)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                iconActionButton(
                    icon: .send,
                    identifier: "pushExamples.\(example.id).send",
                    label: "在 Safari 发送 \(example.title) 推送"
                ) {
                    onSend(deliveryExample)
                }

                iconActionButton(
                    icon: .copy,
                    identifier: "pushExamples.\(example.id).copy",
                    label: "复制 \(example.title) URL"
                ) {
                    onCopy(deliveryExample)
                }
            }

            if let preview = example.preview {
                NotificationExamplePreview(preview: preview)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("pushExamples.\(example.id).preview")
            }

            if example.id == "url" {
                urlOpeningModePicker
            }

            Text(deliveryExample.spec)
                .font(Font.app(ThemeTokens.Typography.monospaceMeta))
                .foregroundColor(Color.appTextTertiary)
                .lineLimit(2)
                .truncationMode(.tail)

            // Description sits at the card bottom, like Bark's notice label.
            Text(example.subtitle)
                .font(Font.app(ThemeTokens.Typography.metadata))
                .foregroundColor(Color.appTextSecondary)

            if example.id == "sound" {
                Button {
                    onOpenSounds()
                } label: {
                    Text("查看全部铃声 ›")
                        .font(Font.app(ThemeTokens.Typography.footnote))
                        .foregroundColor(Color.appPrimary)
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("pushExamples.sound.more")
            }
        }
        .padding(.vertical, ThemeTokens.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var urlOpeningModePicker: some View {
        HStack(spacing: ThemeTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("网页打开方式")
                    .font(.system(size: ThemeTokens.Typography.footnote.pointSize, weight: .semibold))
                    .foregroundColor(Color.appText)
                Text(urlOpensFullscreen ? "打开后隐藏导航栏，沉浸展示网页" : "默认保留应用导航，便于返回消息")
                    .font(Font.app(ThemeTokens.Typography.metadata))
                    .foregroundColor(Color.appTextSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Picker("网页打开方式", selection: $urlOpensFullscreen) {
                Text("普通").tag(false)
                Text("全屏").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 142)
            .accessibilityIdentifier("pushExamples.url.fullscreen")
            .accessibilityHint("默认普通；选择全屏后发送的 URL 会附带 mode=immersive")
        }
        .padding(ThemeTokens.Spacing.sm)
        .background(Color(ThemeTokens.Color.primarySoft))
        .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md)
                .strokeBorder(Color.appPrimary.opacity(0.14), lineWidth: 1)
        )
    }

    private func exampleForDelivery(_ example: PushExample) -> PushExample {
        guard example.id == "url", urlOpensFullscreen else { return example }
        var queryItems = example.queryItems.filter { $0.name != "mode" }
        queryItems.append(URLQueryItem(name: "mode", value: "immersive"))
        return PushExample(
            id: example.id,
            title: example.title,
            subtitle: example.subtitle,
            icon: example.icon,
            group: example.group,
            pushTitle: example.pushTitle,
            pushBody: example.pushBody,
            queryItems: queryItems,
            preview: example.preview
        )
    }

    private func iconActionButton(
        icon: LucideIcon,
        identifier: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(uiImage: icon.templateImage(pointSize: ThemeTokens.Icons.Sizes.sm) ?? UIImage())
                .renderingMode(.template)
                .foregroundColor(Color.appPrimary)
                .frame(width: 32, height: 32)
                .background(Color(ThemeTokens.Color.primarySoft))
                .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.sm))
        }
        // Default-styled buttons inside a List row make the whole row act as
        // the button; borderless confines the tap target to the icon itself.
        .buttonStyle(.borderless)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(label)
    }

}
