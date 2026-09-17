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
      let decoded = try JSONDecoder().decode([String: DeviceRegistration].self, from: data)
      // Older stores used the token itself as the dictionary key. Normalize
      // on read so a legacy client re-registering after this upgrade does
      // not produce a duplicate delivery for the same key and token.
      devices = Dictionary(
        uniqueKeysWithValues: decoded.values.map { registration in
          (Self.registrationID(for: registration), registration)
        }
      )
    } catch {
      loadIssue = "Registration store could not be decoded and was quarantined."
      let quarantineURL =
        fileURL
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
    let registrationID = Self.registrationID(for: registration)
    let previous = devices[registrationID]
    devices[registrationID] = registration
    do {
      try persist()
    } catch {
      devices[registrationID] = previous
      loadIssue = "Registration store could not be persisted."
      throw TokenStoreError.persistenceFailed
    }
  }

  func getDevices(forKey key: String) -> [DeviceRegistration] {
    devices.values.filter { $0.key == key }
  }

  /// A self-hosted device key is installation-specific, so its recipient
  /// public key is safe to discover by the sender that already possesses the
  /// bearer push address. Never return the associated APNs device token.
  func encryptionPublicKey(forKey key: String) -> String? {
    devices.values.first(where: {
      $0.key == key && $0.encryptionPublicKey?.isEmpty == false
    })?.encryptionPublicKey
  }

  func getAllDevices() -> [DeviceRegistration] {
    Array(devices.values)
  }

  /// Removes one public push identity from one APNs token. A token can hold
  /// both a legacy and a short successor identity, so address rotation must
  /// never delete every registration for the device.
  @discardableResult
  func unregister(token: String, key: String) throws -> Bool {
    let registrationID = Self.registrationID(token: token, key: key)
    guard let previous = devices.removeValue(forKey: registrationID) else {
      return false
    }
    do {
      try persist()
      return true
    } catch {
      devices[registrationID] = previous
      loadIssue = "Registration store could not be persisted."
      throw TokenStoreError.persistenceFailed
    }
  }

  func removeDevice(token: String) throws {
    let matchingEntries = devices.filter { $0.value.deviceToken == token }
    for key in matchingEntries.keys {
      devices.removeValue(forKey: key)
    }
    do {
      try persist()
    } catch {
      for (key, registration) in matchingEntries {
        devices[key] = registration
      }
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

  /// One device token may intentionally serve both a legacy long key and a
  /// newly generated short key during an address migration. Existing JSON
  /// files decode unchanged because the dictionary's persisted values retain
  /// the original DeviceRegistration schema.
  private static func registrationID(for registration: DeviceRegistration) -> String {
    registrationID(token: registration.deviceToken, key: registration.key)
  }

  private static func registrationID(token: String, key: String) -> String {
    "\(key)\u{001F}\(token)"
  }
}
