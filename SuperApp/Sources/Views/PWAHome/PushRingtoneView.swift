import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
import WebBridgeKit

/// One push ringtone with playback metadata resolved from the file itself,
/// so durations never drift from the shipped or imported assets.
struct PushRingtone: Identifiable, Equatable {
    let name: String
    let url: URL
    let duration: TimeInterval
    let isCustom: Bool

    var id: String { name }

    var durationText: String {
        String(format: "%.2f 秒", duration)
    }
}

/// Loads the bundled ringtone library plus user-imported sounds from
/// Library/Sounds, and owns preview playback. Selecting a row previews the
/// sound; tapping the playing row again stops it.
@MainActor
final class PushRingtoneModel: ObservableObject {

    @Published private(set) var ringtones: [PushRingtone] = []
    @Published private(set) var customRingtones: [PushRingtone] = []
    @Published var selectedName: String?
    @Published private(set) var playingName: String?

    private var player: AVAudioPlayer?

    /// UNNotificationSound resolves custom names against this directory, so
    /// imported sounds become push-playable immediately — no server round trip.
    private var customSoundsDirectory: URL {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return library.appendingPathComponent("Sounds", isDirectory: true)
    }

    init() {
        loadRingtones()
        // .playback keeps previews audible even when the device is muted,
        // matching how the same sound arrives as a push.
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func loadRingtones() {
        let bundledURLs = Bundle.main.urls(forResourcesWithExtension: "caf", subdirectory: nil) ?? []
        ringtones = bundledURLs
            .compactMap { pushRingtone(url: $0, isCustom: false) }
            .sorted { $0.name < $1.name }

        // PushSoundInstaller mirrors the bundled library into Library/Sounds
        // so named sounds resolve reliably; those mirrors are not user
        // imports and must not show up in the custom section.
        let bundledNames = Set(bundledURLs.map { $0.lastPathComponent })
        let customURLs = (try? FileManager.default.contentsOfDirectory(
            at: customSoundsDirectory,
            includingPropertiesForKeys: nil
        )) ?? []
        customRingtones = customURLs
            .filter { $0.pathExtension.lowercased() == "caf" && !bundledNames.contains($0.lastPathComponent) }
            .compactMap { pushRingtone(url: $0, isCustom: true) }
            .sorted { $0.name < $1.name }
    }

    private func pushRingtone(url: URL, isCustom: Bool) -> PushRingtone? {
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        return PushRingtone(
            name: url.deletingPathExtension().lastPathComponent,
            url: url,
            duration: player.duration,
            isCustom: isCustom
        )
    }

    func toggle(_ ringtone: PushRingtone) {
        selectedName = ringtone.name
        if playingName == ringtone.name {
            player?.stop()
            playingName = nil
            return
        }
        player = try? AVAudioPlayer(contentsOf: ringtone.url)
        player?.play()
        playingName = ringtone.name
    }

    // MARK: - Custom sound import

    /// Copies picked .caf files (≤ 30 s, matching Bark's custom-sound rules)
    /// into Library/Sounds. Returns a user-facing result message.
    @discardableResult
    func importCustomRingtones(from urls: [URL]) -> String {
        var imported = 0
        var rejection: String?
        for url in urls {
            guard url.pathExtension.lowercased() == "caf" else {
                rejection = "「\(url.lastPathComponent)」不是 caf 格式"
                continue
            }
            guard let player = try? AVAudioPlayer(contentsOf: url) else {
                rejection = "「\(url.lastPathComponent)」无法读取"
                continue
            }
            guard player.duration <= 30 else {
                rejection = "「\(url.lastPathComponent)」超过 30 秒"
                continue
            }

            do {
                try FileManager.default.createDirectory(at: customSoundsDirectory, withIntermediateDirectories: true)
                let destination = customSoundsDirectory
                    .appendingPathComponent(url.lastPathComponent)
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.copyItem(at: url, to: destination)
                imported += 1
            } catch {
                rejection = "「\(url.lastPathComponent)」导入失败"
            }
        }

        if imported > 0 { loadRingtones() }
        if let rejection {
            return rejection
        }
        return "已导入 \(imported) 个铃声"
    }

    func deleteCustomRingtones(at offsets: IndexSet) {
        for index in offsets {
            try? FileManager.default.removeItem(at: customRingtones[index].url)
        }
        let removed = offsets.map { customRingtones[$0].name }
        if let playing = playingName, removed.contains(playing) {
            player?.stop()
            playingName = nil
        }
        if let selected = selectedName, removed.contains(selected) {
            selectedName = nil
        }
        loadRingtones()
    }
}

/// Bark-style push ringtone picker: bundled sounds with real durations, local
/// .caf import for custom sounds, tap-to-preview, then send a test push or
/// copy the ready-to-use URL.
struct PushRingtoneView: View {
    @StateObject private var model = PushRingtoneModel()
    @State private var isImporterPresented = false

    /// Fires with the selected sound name; the host opens the test push URL.
    let onTry: (String) -> Void
    /// Fires with the selected sound name; the host copies the sound= URL.
    let onCopy: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            List {
                if !model.customRingtones.isEmpty {
                    Section(header: Text("自定义铃声")) {
                        ForEach(model.customRingtones) { ringtone in
                            row(ringtone)
                        }
                        .onDelete { offsets in
                            model.deleteCustomRingtones(at: offsets)
                        }
                    }
                }
                Section(header: Text("默认铃声")) {
                    ForEach(model.ringtones) { ringtone in
                        row(ringtone)
                    }
                }
            }
            .appListStyle()
            // On the List only: a container-level identifier on the VStack
            // would override the action bar buttons' own identifiers.
            .accessibilityIdentifier("pushRingtones.list")

            actionBar
        }
        .navigationTitle("推送铃声")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing: importButton)
        .sheet(isPresented: $isImporterPresented) {
            RingtoneDocumentPicker { urls in
                guard !urls.isEmpty else { return }
                let message = model.importCustomRingtones(from: urls)
                HUDService.shared.showSuccess(withStatus: message)
            }
        }
    }

    private var importButton: some View {
        Button {
            isImporterPresented = true
        } label: {
            HStack(spacing: ThemeTokens.Spacing.xs) {
                Image(uiImage: LucideIcon.upload.templateImage(pointSize: ThemeTokens.Icons.Sizes.sm) ?? UIImage())
                    .renderingMode(.template)
                Text("导入")
                    .font(Font.app(ThemeTokens.Typography.subheadline))
            }
        }
        .accessibilityIdentifier("pushRingtones.import")
    }

    private func row(_ ringtone: PushRingtone) -> some View {
        Button {
            model.toggle(ringtone)
        } label: {
            HStack(spacing: ThemeTokens.Spacing.md) {
                let icon = ringtone.isCustom ? LucideIcon.upload : LucideIcon.volume
                Image(uiImage: icon.templateImage(pointSize: ThemeTokens.Icons.Sizes.md) ?? UIImage())
                    .renderingMode(.template)
                    .foregroundColor(
                        model.selectedName == ringtone.name ? Color.appPrimary : Color.appTextSecondary
                    )
                    .frame(width: 36, height: 36)
                    .background(Color(ThemeTokens.Color.primarySoft))
                    .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.sm))

                VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
                    Text(ringtone.name)
                        .font(.system(size: ThemeTokens.Typography.rowTitle.pointSize, weight: .medium))
                        .foregroundColor(Color.appText)
                    Text(ringtone.durationText)
                        .font(Font.app(ThemeTokens.Typography.metadata))
                        .foregroundColor(Color.appTextSecondary)
                }

                Spacer()

                if model.playingName == ringtone.name {
                    Image(uiImage: LucideIcon.success.templateImage(pointSize: ThemeTokens.Icons.Sizes.sm) ?? UIImage())
                        .renderingMode(.template)
                        .foregroundColor(Color.appPrimary)
                }
            }
            .padding(.vertical, ThemeTokens.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("pushRingtones.\(ringtone.name)")
    }

    private var actionBar: some View {
        HStack(spacing: ThemeTokens.Spacing.sm) {
            actionButton(
                title: "用此铃声发送测试",
                identifier: "pushRingtones.try",
                prominent: true
            ) {
                guard let name = model.selectedName else { return }
                onTry(name)
            }
            actionButton(
                title: "复制 sound= URL",
                identifier: "pushRingtones.copy",
                prominent: false
            ) {
                guard let name = model.selectedName else { return }
                onCopy(name)
            }
        }
        .padding(.horizontal, ThemeTokens.Spacing.lg)
        .padding(.vertical, ThemeTokens.Spacing.sm)
        .background(Color(ThemeTokens.Color.background))
        .disabled(model.selectedName == nil)
        .opacity(model.selectedName == nil ? 0.55 : 1)
    }

    private func actionButton(
        title: String,
        identifier: String,
        prominent: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(Font.app(ThemeTokens.Typography.headline))
                .frame(maxWidth: .infinity)
                .padding(.vertical, ThemeTokens.Spacing.sm)
                .background(prominent ? Color.appPrimary : Color(ThemeTokens.Color.surface))
                .foregroundColor(prominent ? Color(ThemeTokens.Color.surface) : Color.appPrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.lg)
                        .stroke(prominent ? Color.clear : Color.appPrimary, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.lg))
        }
        .accessibilityIdentifier(identifier)
    }
}

/// File importer restricted to audio types; the model then enforces the
/// caf-and-≤30 s rules before anything lands in Library/Sounds.
struct RingtoneDocumentPicker: UIViewControllerRepresentable {
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void
        init(onPick: @escaping ([URL]) -> Void) { self.onPick = onPick }

        func documentPicker(
            _ controller: UIDocumentPickerViewController,
            didPickDocumentsAt urls: [URL]
        ) {
            onPick(urls)
        }
    }

    let onPick: ([URL]) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.audio], asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
}
