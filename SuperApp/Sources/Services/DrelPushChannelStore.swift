import Foundation

/// The active address is a presentation choice, not a delivery switch. Both
/// official and self-hosted registrations stay alive while the user switches
/// the address shown on the Drel home screen.
struct DrelPushChannel: Identifiable, Equatable {
    enum Kind: String, Equatable {
        case official
        case selfHosted
    }

    let id: String
    let kind: Kind
    let name: String
    let pushURL: String

    var isOfficial: Bool { kind == .official }
}

final class DrelPushChannelStore {
    static let shared = DrelPushChannelStore()

    static let officialChannelID = "drel.official"
    static let didChangeNotification = Notification.Name("drel.push-channel.did-change")
    private let selectedChannelKey = "drel.push-channel.selected.v1"

    private init() {}

    func channels(officialPushURL: String) -> [DrelPushChannel] {
        var result = [
            DrelPushChannel(
                id: Self.officialChannelID,
                kind: .official,
                name: "官方 Drel",
                pushURL: officialPushURL
            )
        ]

        // The existing self-hosted configuration intentionally remains a
        // separate persistence record. In the first channel-switch release it
        // is one optional Bark-compatible direct server, rather than a risky
        // migration of the app-group encryption identity store.
        if let configuration = SelfHostedPushConfiguration.load(),
           configuration.resolvedRelayKind == .selfHostedDirect {
            let base = configuration.serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            result.append(
                DrelPushChannel(
                    id: selfHostedChannelID(for: configuration),
                    kind: .selfHosted,
                    name: configuration.name.isEmpty ? "自建推送" : configuration.name,
                    pushURL: "\(base)/\(configuration.deviceKey)"
                )
            )
        }
        return result
    }

    func activeChannel(officialPushURL: String) -> DrelPushChannel {
        let all = channels(officialPushURL: officialPushURL)
        let selected = UserDefaults.standard.string(forKey: selectedChannelKey)
        return all.first(where: { $0.id == selected }) ?? all[0]
    }

    func select(_ channel: DrelPushChannel) {
        UserDefaults.standard.set(channel.id, forKey: selectedChannelKey)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    func isActiveSelfHosted(officialPushURL: String) -> Bool {
        activeChannel(officialPushURL: officialPushURL).kind == .selfHosted
    }

    private func selfHostedChannelID(for configuration: SelfHostedPushConfiguration) -> String {
        "drel.selfhosted.\(configuration.serverURL.lowercased())"
    }
}
