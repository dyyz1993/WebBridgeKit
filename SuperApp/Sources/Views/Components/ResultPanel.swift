import SwiftUI
import WebBridgeKit

struct ResultPanel: View {
    enum State {
        case idle
        case loading(String)
        case success(String)
        case warning(String)
        case failure(String)
    }

    let title: String
    let state: State
    var detail: String?
    var copyAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.md) {
            HStack(spacing: ThemeTokens.Spacing.sm) {
                StatusBadge(title: badgeTitle, tone: badgeTone)
                Text(title)
                    .font(Font.app(ThemeTokens.Typography.sectionTitle))
                    .foregroundColor(Color.appText)
                    .lineLimit(1)
                Spacer()
                if let copyAction {
                    Button(action: copyAction) {
                        Image(uiImage: LucideIcon.copy.templateImage(pointSize: ThemeTokens.Icons.Sizes.sm) ?? UIImage())
                            .renderingMode(.template)
                            .foregroundColor(Color.appPrimary)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityIdentifier("resultPanel.copyButton")
                }
            }

            Text(message)
                .font(Font.app(ThemeTokens.Typography.body))
                .foregroundColor(Color.appTextSecondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            if let detail, !detail.isEmpty {
                CodeBlockView(title: nil, text: detail, maxHeight: 180)
            }
        }
        .padding(ThemeTokens.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.card)
                .stroke(Color.appSeparator, lineWidth: 1)
        )
        .accessibilityIdentifier("resultPanel")
    }

    private var badgeTitle: String {
        switch state {
        case .idle:
            return "Idle"
        case .loading:
            return "Running"
        case .success:
            return "OK"
        case .warning:
            return "Warn"
        case .failure:
            return "Error"
        }
    }

    private var badgeTone: StatusBadge.Tone {
        switch state {
        case .idle:
            return .neutral
        case .loading:
            return .info
        case .success:
            return .success
        case .warning:
            return .warning
        case .failure:
            return .error
        }
    }

    private var message: String {
        switch state {
        case .idle:
            return "等待执行"
        case .loading(let message),
             .success(let message),
             .warning(let message),
             .failure(let message):
            return message
        }
    }
}
