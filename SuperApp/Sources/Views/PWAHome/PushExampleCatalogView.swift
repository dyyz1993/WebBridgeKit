import SwiftUI
import WebBridgeKit

enum PushExampleType: String, CaseIterable, Identifiable {
    case plain
    case markdown
    case otp
    case qr
    case image
    case chat
    case approval

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plain: return "普通通知"
        case .markdown: return "Markdown"
        case .otp: return "验证码"
        case .qr: return "二维码"
        case .image: return "图片"
        case .chat: return "聊天"
        case .approval: return "审批"
        }
    }

    var subtitle: String {
        switch self {
        case .plain: return "标题与普通正文"
        case .markdown: return "标题、列表、代码块与安全链接"
        case .otp: return "验证码与有效期"
        case .qr: return "由宿主生成可扫描二维码"
        case .image: return "远程图片和可读失败降级"
        case .chat: return "定位到受信任 PWA 会话"
        case .approval: return "预览待确认状态；完整交互使用 Approval v1 POST"
        }
    }

    var icon: LucideIcon {
        switch self {
        case .plain: return .bell
        case .markdown: return .docText
        case .otp: return .key
        case .qr: return .qrCode
        case .image: return .image
        case .chat: return .paperplane
        case .approval: return .clipboard
        }
    }
}

struct PushExampleCatalogView: View {
    let onSelect: (PushExampleType) -> Void

    var body: some View {
        List(PushExampleType.allCases) { type in
            Button { onSelect(type) } label: {
                HStack(spacing: ThemeTokens.Spacing.md) {
                    Image(uiImage: type.icon.templateImage(pointSize: ThemeTokens.Icons.Sizes.md) ?? UIImage())
                        .renderingMode(.template)
                        .foregroundColor(Color.appPrimary)
                        .frame(width: 36, height: 36)
                        .background(Color(ThemeTokens.Color.primarySoft))
                        .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.sm))

                    VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
                        Text(type.title)
                            .font(.system(size: ThemeTokens.Typography.rowTitle.pointSize, weight: .medium))
                            .foregroundColor(Color.appText)
                        Text(type.subtitle)
                            .font(Font.app(ThemeTokens.Typography.metadata))
                            .foregroundColor(Color.appTextSecondary)
                    }

                    Spacer()

                    Image(uiImage: LucideIcon.compass.templateImage(pointSize: ThemeTokens.Icons.Sizes.sm) ?? UIImage())
                        .renderingMode(.template)
                        .foregroundColor(Color.appTextTertiary)
                }
                .padding(.vertical, ThemeTokens.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("pushExamples.\(type.rawValue)")
        }
        .appListStyle()
        .navigationTitle("API 示例")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("pushExamples.list")
    }
}
