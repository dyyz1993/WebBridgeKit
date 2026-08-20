import Foundation
import Security
import WebBridgeKit

enum OfficialPushIdentityStoreError: LocalizedError {
    case randomGenerationFailed(OSStatus)
    case keychainReadFailed(OSStatus)
    case keychainWriteFailed(OSStatus)
    case invalidKeychainValue

    var errorDescription: String? {
        switch self {
        case .randomGenerationFailed:
            return L10n.tr("official.push.error.identity")
        case .keychainReadFailed, .keychainWriteFailed, .invalidKeychainValue:
            return L10n.tr("official.push.error.storage")
        }
    }
}

/// Per-installation push identity with dual persistence (Keychain + UserDefaults).
/// UserDefaults acts as a read cache so all code paths — push registration,
/// message fetch, UI display — always see the same identity even when
/// Keychain access fails in background contexts.
final class OfficialPushIdentityStore {
    static let shared = OfficialPushIdentityStore()

    private let userDefaultsKey = "com.webbridgekit.official-push.identity"
    private let provider: PushDeviceIdentityProvider
    private let keychainStorage: KeychainPushDeviceIdentityStorage

    init(
        storage: KeychainPushDeviceIdentityStorage = KeychainPushDeviceIdentityStorage(),
        randomBytes: @escaping (Int) throws -> Data = OfficialPushIdentityStore.secureRandomBytes
    ) {
        self.keychainStorage = storage
        self.provider = PushDeviceIdentityProvider(storage: storage, randomBytes: randomBytes)
    }

    /// Returns the current identity, creating one if none exists. Persists to
    /// both Keychain (authoritative) and UserDefaults (fast cache) so every
    /// call site gets the same value.
    func currentOrCreate() throws -> String {
        // Fast path: UserDefaults cache
        if let cached = UserDefaults.standard.string(forKey: userDefaultsKey), !cached.isEmpty {
            // Verify Keychain still has it; sync if drifted
            if let keychainValue = try? keychainStorage.load(), keychainValue != cached {
                // Keychain has a different value (e.g., after partial restore).
                // Keychain wins; update cache.
                UserDefaults.standard.set(keychainValue, forKey: userDefaultsKey)
                return keychainValue
            }
            return cached
        }

        // Slow path: create or recover from Keychain
        let identity = try provider.currentOrCreate()
        UserDefaults.standard.set(identity, forKey: userDefaultsKey)
        return identity
    }

    /// Discards the current identity and generates a fresh one. The old
    /// identity becomes invalid for this device after the next registration.
    func reset() throws -> String {
        try? keychainStorage.delete()
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)

        let identity = try provider.currentOrCreate()
        UserDefaults.standard.set(identity, forKey: userDefaultsKey)
        return identity
    }

    private static func secureRandomBytes(count: Int) throws -> Data {
        var data = Data(repeating: 0, count: count)
        let status = data.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, count, buffer.baseAddress!)
        }
        guard status == errSecSuccess else {
            throw OfficialPushIdentityStoreError.randomGenerationFailed(status)
        }
        return data
    }
}

struct KeychainPushDeviceIdentityStorage: PushDeviceIdentityStorage {
    private let service = "com.webbridgekit.superapp.official-push"
    private let account = "device-key-v1"

    func load() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw OfficialPushIdentityStoreError.keychainReadFailed(status)
        }
        guard let data = result as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty else {
            throw OfficialPushIdentityStoreError.invalidKeychainValue
        }
        return value
    }

    func save(_ value: String) throws {
        let data = Data(value.utf8)
        let update = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw OfficialPushIdentityStoreError.keychainWriteFailed(updateStatus)
        }

        var add = baseQuery
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw OfficialPushIdentityStoreError.keychainWriteFailed(addStatus)
        }
    }

    func delete() throws {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
