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

final class OfficialPushIdentityStore {
    static let shared = OfficialPushIdentityStore()

    private let provider: PushDeviceIdentityProvider

    init(
        storage: any PushDeviceIdentityStorage = KeychainPushDeviceIdentityStorage(),
        randomBytes: @escaping (Int) throws -> Data = OfficialPushIdentityStore.secureRandomBytes
    ) {
        provider = PushDeviceIdentityProvider(storage: storage, randomBytes: randomBytes)
    }

    func currentOrCreate() throws -> String {
        try provider.currentOrCreate()
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

private struct KeychainPushDeviceIdentityStorage: PushDeviceIdentityStorage {
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

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
