import Foundation

/// Storage boundary for a per-installation push identity. Product hosts can
/// provide Keychain-backed storage without coupling the reusable SDK to UI.
public protocol PushDeviceIdentityStorage {
    func load() throws -> String?
    func save(_ value: String) throws
}

public enum PushDeviceIdentityError: Error, Equatable {
    case invalidRandomByteCount(expected: Int, actual: Int)
}

/// Generates a stable, URL-safe, high-entropy identity for push registration.
public struct PushDeviceIdentityProvider {
    private static let byteCount = 32

    private let storage: any PushDeviceIdentityStorage
    private let randomBytes: (Int) throws -> Data

    public init(
        storage: any PushDeviceIdentityStorage,
        randomBytes: @escaping (Int) throws -> Data
    ) {
        self.storage = storage
        self.randomBytes = randomBytes
    }

    public func currentOrCreate() throws -> String {
        if let stored = try storage.load(), !stored.isEmpty {
            return stored
        }

        let bytes = try randomBytes(Self.byteCount)
        guard bytes.count == Self.byteCount else {
            throw PushDeviceIdentityError.invalidRandomByteCount(
                expected: Self.byteCount,
                actual: bytes.count
            )
        }

        let identity = bytes.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        try storage.save(identity)
        return identity
    }
}
