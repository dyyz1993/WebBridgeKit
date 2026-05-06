import Foundation
import Hummingbird
import NIOCore

final class APNsService: Sendable {
    private let configuration: ServerConfiguration
    private let tokenStore: TokenStore

    init(configuration: ServerConfiguration, tokenStore: TokenStore) {
        self.configuration = configuration
        self.tokenStore = tokenStore
    }

    func sendPush(key: String, payload: PushPayload) async throws -> PushResponse {
        let devices = await tokenStore.getDevices(forKey: key)

        guard !devices.isEmpty || key == "test" else {
            throw HTTPError(.notFound, message: "No devices registered for key: \(key)")
        }

        for device in devices {
            await sendToAPNs(deviceToken: device.deviceToken, payload: payload)
        }

        return PushResponse(
            code: 200,
            message: devices.isEmpty ? "Test notification acknowledged" : "Push sent to \(devices.count) device(s)",
            timestamp: Int(Date().timeIntervalSince1970)
        )
    }

    func registerDevice(_ registration: DeviceRegistration) async {
        await tokenStore.register(registration)
    }

    private func sendToAPNs(deviceToken: String, payload: PushPayload) async {
        guard !configuration.apnsKeyID.isEmpty else { return }

        let apnsPayload: [String: Any] = [
            "aps": [
                "alert": [
                    "title": payload.title,
                    "body": payload.body,
                ],
                "sound": payload.sound ?? "default",
                "badge": payload.badge as Any,
            ] as [String: Any],
        ].compactMapValues { $0 }

        let host = configuration.apnsEnvironment == "production"
            ? "api.push.apple.com"
            : "api.sandbox.push.apple.com"
        let url = URL(string: "https://\(host)/3/device/\(deviceToken)")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: apnsPayload)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                print("APNs error: \(httpResponse.statusCode)")
            }
        } catch {
            print("APNs send error: \(error)")
        }
    }
}
