import SwiftUI
import WebBridgeKit

/// Per-group notification mute management. Mutes are stored in the shared
/// App Group UserDefaults and enforced by the NSE MuteProcessor.
struct GroupMuteView: View {
    @State private var mutes: [String: Date] = [:]
    @State private var newGroupName = ""

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: PushSoundInstaller.appGroupIdentifier)
    }

    var body: some View {
        List {
            Section(header: Text("已静音的分组")) {
                if mutes.isEmpty {
                    Text("暂无静音的分组")
                        .font(Font.app(ThemeTokens.Typography.metadata))
                        .foregroundColor(Color.appTextSecondary)
                } else {
                    ForEach(sortedMutes, id: \.0) { group, expiry in
                        HStack {
                            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
                                Text(group)
                                    .font(Font.app(ThemeTokens.Typography.rowTitle))
                                    .foregroundColor(Color.appText)
                                Text("至 \(Self.timeFormatter.string(from: expiry))")
                                    .font(Font.app(ThemeTokens.Typography.metadata))
                                    .foregroundColor(Color.appTextSecondary)
                            }
                            Spacer()
                            Button("取消静音") {
                                mutes.removeValue(forKey: group)
                                save()
                            }
                            .font(Font.app(ThemeTokens.Typography.footnote))
                            .foregroundColor(Color.appPrimary)
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, ThemeTokens.Spacing.xs)
                    }
                }
            }

            Section(header: Text("添加静音")) {
                HStack {
                    TextField("分组名称", text: $newGroupName)
                        .font(Font.app(ThemeTokens.Typography.body))
                        .textFieldStyle(.roundedBorder)

                    Menu {
                        ForEach([1, 2, 4, 8, 24], id: \.self) { hours in
                            Button("\(hours) 小时") {
                                mute(group: newGroupName, hours: hours)
                            }
                        }
                    } label: {
                        Text("静音")
                            .font(Font.app(ThemeTokens.Typography.subheadline))
                            .padding(.horizontal, ThemeTokens.Spacing.md)
                            .padding(.vertical, ThemeTokens.Spacing.sm)
                            .background(Color(ThemeTokens.Color.primarySoft))
                            .foregroundColor(Color.appPrimary)
                            .clipShape(Capsule())
                    }
                    .disabled(newGroupName.isEmpty)
                    .buttonStyle(.borderless)
                }
                .padding(.vertical, ThemeTokens.Spacing.sm)

                Text("静音后，该分组的通知仍会送达通知中心，但不播放声音、不弹横幅。")
                    .font(Font.app(ThemeTokens.Typography.metadata))
                    .foregroundColor(Color.appTextSecondary)
            }
        }
        .appListStyle()
        .navigationTitle("分组静音")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
    }

    private var sortedMutes: [(String, Date)] {
        mutes.sorted { $0.value < $1.value }
    }

    private func load() {
        mutes = sharedDefaults?.dictionary(forKey: "groupMuteSettings") as? [String: Date] ?? [:]
        // Clean expired.
        let now = Date()
        mutes = mutes.filter { $0.value > now }
    }

    private func save() {
        sharedDefaults?.set(mutes, forKey: "groupMuteSettings")
    }

    private func mute(group: String, hours: Int) {
        mutes[group] = Date().addingTimeInterval(TimeInterval(hours * 3600))
        save()
        newGroupName = ""
        HUDService.shared.showSuccess(withStatus: "已静音 \\(group) \\(hours) 小时")
    }
}

extension GroupMuteView {
    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}
