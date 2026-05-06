import Crypto
import Foundation
import Hummingbird
import NIOCore

actor TokenStore {
    private var devices: [String: DeviceRegistration] = [:]

    func register(_ registration: DeviceRegistration) {
        devices[registration.deviceToken] = registration
    }

    func getDevices(forKey key: String) -> [DeviceRegistration] {
        devices.values.filter { $0.key == key }
    }

    func getAllDevices() -> [DeviceRegistration] {
        Array(devices.values)
    }

    func removeDevice(token: String) {
        devices.removeValue(forKey: token)
    }

    func deviceCount() -> Int {
        devices.count
    }
}
