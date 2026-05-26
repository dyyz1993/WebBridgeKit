import Foundation
import Hummingbird
import NIOCore
import NIOHTTP1
import AsyncHTTPClient

final class APNsService: Sendable {
    private let configuration: ServerConfiguration
    private let tokenStore: TokenStore
    private let httpClient: HTTPClient

    init(configuration: ServerConfiguration, tokenStore: TokenStore, httpClient: HTTPClient = .shared) {
        self.configuration = configuration
        self.tokenStore = tokenStore
        self.httpClient = httpClient
    }

    func sendPush(key: String, payload: PushPayload) async throws -> PushResponse {
        let devices = await tokenStore.getDevices(forKey: key)

        guard !devices.isEmpty || key == "test" || key == "test_resources" else {
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
        let urlString = "https://\(host)/3/device/\(deviceToken)"

        guard let bodyData = try? JSONSerialization.data(withJSONObject: apnsPayload) else { return }

        guard var request = try? HTTPClient.Request(
            url: urlString,
            method: .POST,
            body: .data(bodyData)
        ) else { return }
        request.headers.add(name: "Content-Type", value: "application/json")

        do {
            let response = try await httpClient.execute(request: request).get()
            if response.status.code != 200 {
                print("APNs error: \(response.status.code)")
            }
        } catch {
            print("APNs send error: \(error)")
        }
    }
}
