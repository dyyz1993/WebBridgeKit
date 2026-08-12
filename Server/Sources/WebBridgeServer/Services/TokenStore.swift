import Crypto
import Foundation
import Hummingbird
import NIOCore

enum TokenStoreError: Error, Equatable {
    case persistenceFailed
}

actor TokenStore {
    private var devices: [String: DeviceRegistration] = [:]
    private let fileURL: URL?
    private var loadIssue: String?

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL
        guard let fileURL, FileManager.default.fileExists(atPath: fileURL.path) else { return }

        do {
            let data = try Data(contentsOf: fileURL)
            devices = try JSONDecoder().decode([String: DeviceRegistration].self, from: data)
        } catch {
            loadIssue = "Registration store could not be decoded and was quarantined."
            let quarantineURL = fileURL
                .deletingLastPathComponent()
                .appendingPathComponent("\(fileURL.lastPathComponent).corrupt-\(UUID().uuidString)")
            do {
                try FileManager.default.moveItem(at: fileURL, to: quarantineURL)
            } catch {
                loadIssue = "Registration store could not be decoded or quarantined."
            }
        }
    }

    func register(_ registration: DeviceRegistration) throws {
        let previous = devices[registration.deviceToken]
        devices[registration.deviceToken] = registration
        do {
            try persist()
        } catch {
            devices[registration.deviceToken] = previous
            loadIssue = "Registration store could not be persisted."
            throw TokenStoreError.persistenceFailed
        }
    }

    func getDevices(forKey key: String) -> [DeviceRegistration] {
        devices.values.filter { $0.key == key }
    }

    func getAllDevices() -> [DeviceRegistration] {
        Array(devices.values)
    }

    func removeDevice(token: String) throws {
        let previous = devices[token]
        devices.removeValue(forKey: token)
        do {
            try persist()
        } catch {
            devices[token] = previous
            loadIssue = "Registration store could not be persisted."
            throw TokenStoreError.persistenceFailed
        }
    }

    func deviceCount() -> Int {
        devices.count
    }

    func recoveryIssue() -> String? {
        loadIssue
    }

    private func persist() throws {
        guard let fileURL else { return }
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(devices).write(to: fileURL, options: .atomic)
        } catch {
            throw TokenStoreError.persistenceFailed
        }
    }
}
