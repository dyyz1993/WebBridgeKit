import SwiftUI
import WebBridgeKit

struct AboutView: View {
    private let appIcon: UIImage? = Bundle.main.icon
    private let appName: String = Bundle.main.displayName
    private let versionText: String = {
        if let version = Bundle.main.version, let build = Bundle.main.build {
            return L10n.tr("about.version_format", version, build)
        }
        return L10n.tr("about.version_default")
    }()

    @State private var appeared = false

    var body: some View {
        List {
            headerSection
                .staggerIn(index: 0, appeared: appeared)
            introductionSection
                .staggerIn(index: 1, appeared: appeared)
            featuresSection
                .staggerIn(index: 2, appeared: appeared)
            licenseSection
                .staggerIn(index: 3, appeared: appeared)
            feedbackSection
                .staggerIn(index: 4, appeared: appeared)
        }
        .appListStyle()
        .listStyle(InsetGroupedListStyle())
        .navigationTitle(L10n.tr("about.title"))
        .onAppear { appeared = true }
    }

    private var headerSection: some View {
        Section(header: EmptyView()) {
            VStack(spacing: 12) {
                Group {
                    if let icon = appIcon {
                        Image(uiImage: icon)
                            .resizable()
                    } else {
                        Image(uiImage: LucideIcon.appFill.templateImage(pointSize: 60, weight: .light) ?? UIImage())
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(Color.appPrimary)
                    }
                }
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.xxl))
                .overlay(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.xxl).stroke(Color.appSeparator, lineWidth: 1))

                Text(appName)
                    .font(Font.app(ThemeTokens.Typography.title3))
                    .foregroundColor(Color.appText)

                Text(versionText)
                    .font(Font.app(ThemeTokens.Typography.body))
                    .foregroundColor(Color.appTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .listRowBackground(Color.appCardBackground)
        }
    }

    private var introductionSection: some View {
        Section(header: Text(L10n.tr("about.section.introduction")).font(Font.app(ThemeTokens.Typography.headline))) {
            Text(L10n.tr("about.introduction"))
                .font(Font.app(ThemeTokens.Typography.callout))
                .foregroundColor(Color.appTextSecondary)
                .listRowBackground(Color.appCardBackground)
        }
    }

    private var featuresSection: some View {
        Section(header: Text(L10n.tr("about.section.features")).font(Font.app(ThemeTokens.Typography.headline))) {
            ForEach([
                L10n.tr("about.feature.cache"),
                L10n.tr("about.feature.favorite"),
                L10n.tr("about.feature.token"),
                L10n.tr("about.feature.api_key")
            ], id: \.self) { feature in
                Text(feature)
                    .font(Font.app(ThemeTokens.Typography.callout))
                    .foregroundColor(Color.appText)
                    .listRowBackground(Color.appCardBackground)
            }
        }
    }

    private var licenseSection: some View {
        Section(header: Text(L10n.tr("about.section.license")).font(Font.app(ThemeTokens.Typography.headline))) {
            NavigationLink(destination: ThirdPartyLicensesWrapperView()) {
                Text("MIT License")
                    .font(Font.app(ThemeTokens.Typography.callout))
                    .foregroundColor(Color.appPrimary)
            }
            .listRowBackground(Color.appCardBackground)
        }
    }

    private var feedbackSection: some View {
        Section(header: Text(L10n.tr("about.section.feedback")).font(Font.app(ThemeTokens.Typography.headline))) {
            Button {
                if let url = URL(string: "https://github.com/yourusername/WebBridgeKit/issues") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text(L10n.tr("about.feedback.github"))
                    .font(Font.app(ThemeTokens.Typography.callout))
                    .foregroundColor(Color.appPrimary)
            }
            .listRowBackground(Color.appCardBackground)

            Button {
                if let url = URL(string: "mailto:support@webbridgekit.com") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text(L10n.tr("about.feedback.email"))
                    .font(Font.app(ThemeTokens.Typography.callout))
                    .foregroundColor(Color.appPrimary)
            }
            .listRowBackground(Color.appCardBackground)
        }
    }
}

private struct ThirdPartyLicensesWrapperView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UINavigationController {
        let vc = ThirdPartyLicensesViewController()
        return UINavigationController(rootViewController: vc)
    }
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}
