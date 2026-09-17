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
/// Keychain is preferred, while UserDefaults is both a read cache and a
/// non-secret fallback. The identity is intentionally public in the copyable
/// push URL, so a transient Keychain failure must not stop a new developer
/// from discovering a stable address before granting notification permission.
final class OfficialPushIdentityStore {
    static let shared = OfficialPushIdentityStore()

    private let userDefaultsKey = "com.webbridgekit.official-push.identity"
    private let provider: PushDeviceIdentityProvider
    private let userDefaultsProvider: PushDeviceIdentityProvider
    private let keychainStorage: KeychainPushDeviceIdentityStorage

    init(
        storage: KeychainPushDeviceIdentityStorage = KeychainPushDeviceIdentityStorage(),
        randomBytes: @escaping (Int) throws -> Data = OfficialPushIdentityStore.secureRandomBytes
    ) {
        self.keychainStorage = storage
        self.provider = PushDeviceIdentityProvider(storage: storage, randomBytes: randomBytes)
        self.userDefaultsProvider = PushDeviceIdentityProvider(
            storage: UserDefaultsPushDeviceIdentityStorage(key: userDefaultsKey),
            randomBytes: randomBytes
        )
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

        // Slow path: create or recover from Keychain. If the OS keychain is
        // temporarily unavailable, retain the non-secret identity in
        // UserDefaults instead of withholding the public endpoint from V1's
        // first-launch screen.
        let identity = try createIdentity()
        UserDefaults.standard.set(identity, forKey: userDefaultsKey)
        return identity
    }

    /// Moves an installation from either the legacy 43-character URL-safe
    /// base64 key or the first grouped short format to the compact 16-character
    /// identity. The server keeps the legacy registration alongside the
    /// successor, so developers' existing scripts continue to deliver while
    /// the app starts showing the separator-free address.
    func currentOrMigrateToShortIdentity() throws -> String {
        let current = try currentOrCreate()
        guard !PushDeviceIdentityProvider.isCurrentIdentity(current) else { return current }

        try keychainStorage.delete()
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)

        let successor = try createIdentity()
        UserDefaults.standard.set(successor, forKey: userDefaultsKey)
        return successor
    }

    /// Discards the current identity and generates a fresh one. The server may
    /// retain the old identity during its compatibility window, so callers that
    /// need immediate revocation must remove the old registration server-side.
    func reset() throws -> String {
        try? keychainStorage.delete()
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)

        let identity = try createIdentity()
        UserDefaults.standard.set(identity, forKey: userDefaultsKey)
        return identity
    }

    private func createIdentity() throws -> String {
        do {
            return try provider.currentOrCreate()
        } catch let error as OfficialPushIdentityStoreError {
            switch error {
            case .keychainReadFailed, .keychainWriteFailed, .invalidKeychainValue:
                return try userDefaultsProvider.currentOrCreate()
            case .randomGenerationFailed:
                throw error
            }
        }
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

/// The public push identity is not a credential. This storage is used only if
/// Keychain access fails, so a first-run address remains stable and copyable.
private struct UserDefaultsPushDeviceIdentityStorage: PushDeviceIdentityStorage {
    let key: String

    func load() throws -> String? {
        UserDefaults.standard.string(forKey: key)
    }

    func save(_ value: String) throws {
        UserDefaults.standard.set(value, forKey: key)
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
