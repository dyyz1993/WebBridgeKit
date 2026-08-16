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
        case autoCopy(title: String, body: String, value: String)
    }
}

extension PushExample {

    /// The full catalog organized as content types, presentation parameters
    /// and behavior parameters. Content-type ids stay equal to the historical
    /// `pushExamples.<id>` accessibility identifiers used by UI tests.
    static let all: [PushExample] = [
        // MARK: 内容类型
        PushExample(
            id: "plain",
            title: "普通通知",
            subtitle: "标题与普通正文",
            icon: .bell,
            group: .content,
            pushTitle: "测试通知",
            pushBody: "你好，这是一条来自 WebBridgeKit 的消息",
            queryItems: []
        ),
        PushExample(
            id: "markdown",
            title: "Markdown",
            subtitle: "标题、列表、代码块与安全链接",
            icon: .docText,
            group: .content,
            pushTitle: "部署完成",
            pushBody: "## 结果\n\n- 状态：成功\n- 环境：生产",
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
            pushBody: "使用 WebBridgeKit 扫描此二维码",
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
                URLQueryItem(name: "image", value: "https://example.com/preview.png")
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
                // 路由必须在 fixture 清单的白名单内，否则横幅点击会被
                // 路由校验拒绝、无法进入 PWA 页面。
                URLQueryItem(name: "route", value: "/fixtures/pwa-notification/index.html")
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
                URLQueryItem(name: "sound", value: "alarm")
            ]
        ),
        PushExample(
            id: "icon",
            title: "自定义图标",
            subtitle: "替换通知左侧图标（iOS 15 或以上）",
            icon: .appBadge,
            group: .presentation,
            pushTitle: "自定义图标",
            pushBody: "通知左侧图标已替换为示例图片",
            queryItems: [
                URLQueryItem(
                    name: "icon",
                    value: "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/images/logo.png"
                )
            ],
            preview: .banner(
                title: "自定义图标",
                body: "通知左侧图标已替换为示例图片",
                iconURL: URL(string: "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/images/logo.png")
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
            id: "subtitle",
            title: "副标题",
            subtitle: "标题下方展示灰色附加信息",
            icon: .doc,
            group: .presentation,
            pushTitle: "副标题示例",
            pushBody: "通知可以同时展示标题、副标题和正文",
            queryItems: [
                URLQueryItem(name: "subtitle", value: "来自 WebBridgeKit")
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
                    value: "https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-hub.html"
                )
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
            subtitle: "相同 id 的推送覆盖旧通知；delete=1 可撤回",
            icon: .refresh,
            group: .behavior,
            pushTitle: "覆盖通知",
            pushBody: "再次发送相同 id 会覆盖这条通知",
            queryItems: [
                URLQueryItem(name: "id", value: "wbk-demo-replace")
            ]
        )
    ]

    static func example(id: String) -> PushExample? {
        all.first { $0.id == id }
    }

    /// The parameter contract shown on the card (Bark's `queryParameter`
    /// pattern): the useful part of the URL without the device-key noise.
    /// Nil hides the line entirely (e.g. the plain example has no params).
    var spec: String? {
        guard !queryItems.isEmpty else { return nil }
        return queryItems
            .compactMap { item in item.value.map { "\(item.name)=\($0)" } }
            .joined(separator: "&")
    }
}

/// Bark-style capability catalog: each card pairs a description and its
/// parameter spec with a copy button (full device URL) and a send button
/// that fires the push from the browser. The card itself also sends.
struct PushExampleCatalogView: View {
    let onTry: (PushExample) -> Void
    let onCopy: (PushExample) -> Void
    /// Opens the ringtone picker from the sound card (Bark's "view all
    /// sounds" entry).
    let onOpenSounds: () -> Void

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
        .navigationTitle("API 示例")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("pushExamples.list")
    }

    private func exampleCard(_ example: PushExample) -> some View {
        // Vertical rhythm mirrors Bark's PreviewCardCell: title row with
        // actions, then the notification preview, then the parameter spec,
        // and the description last. The title area is deliberately NOT
        // tappable — only the explicit send button opens Safari, so
        // accidental card taps cannot fire pushes.
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.sm) {
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

                Spacer()

                iconActionButton(
                    icon: LucideIcon.send,
                    identifier: "pushExamples.\(example.id).send",
                    label: "发送 \(example.title) 推送"
                ) {
                    onTry(example)
                }
                iconActionButton(
                    icon: LucideIcon.copy,
                    identifier: "pushExamples.\(example.id).copy",
                    label: "复制 \(example.title) URL"
                ) {
                    onCopy(example)
                }
            }

            if let preview = example.preview {
                NotificationExamplePreview(preview: preview)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("pushExamples.\(example.id).preview")
            }

            if let spec = example.spec {
                Text(spec)
                    .font(Font.app(ThemeTokens.Typography.monospaceMeta))
                    .foregroundColor(Color.appTextTertiary)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }

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
                .accessibilityIdentifier("pushExamples.sound.more")
            }
        }
        .padding(.vertical, ThemeTokens.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
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
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(label)
    }
}
