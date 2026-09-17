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
///
/// New identities use 16 contiguous Crockford-style base-32 characters. This
/// keeps the public address compact while retaining 80 bits of entropy.
/// Existing stored identities are intentionally returned unchanged so hosts
/// can choose their own migration moment.
public struct PushDeviceIdentityProvider {
    private static let byteCount = 10
    /// Crockford Base32 has exactly 32 symbols. It omits I, L, O, and U so
    /// the remaining 0 and 1 are not ambiguous with any emitted letter.
    private static let alphabet = Array("0123456789abcdefghjkmnpqrstvwxyz")
    /// The first Drel short-address rollout accidentally used a 31-character
    /// alphabet that included U and omitted 0/1. Keep accepting those already
    /// persisted identities so an app update never rotates a working address.
    private static let legacyAlphabet = Array("23456789abcdefghjkmnpqrstuvwxyz")

    private let storage: any PushDeviceIdentityStorage
    private let randomBytes: (Int) throws -> Data

    public init(
        storage: any PushDeviceIdentityStorage,
        randomBytes: @escaping (Int) throws -> Data
    ) {
        self.storage = storage
        self.randomBytes = randomBytes
    }

    /// Whether the value already uses the current compact, separator-free
    /// format. Product hosts use this to decide whether a stored legacy value
    /// needs a one-time migration.
    public static func isCurrentIdentity(_ identity: String) -> Bool {
        identity.count == 16 && identity.allSatisfy { alphabet.contains($0) }
    }

    /// Accepts both the current compact format and the earlier grouped short
    /// format. This is a compatibility classifier, not a migration decision.
    public static func isShortIdentity(_ identity: String) -> Bool {
        if isCurrentIdentity(identity) { return true }

        let parts = identity.split(separator: "-", omittingEmptySubsequences: false)
        return parts.count == 4
            && parts.allSatisfy {
                $0.count == 4 && $0.allSatisfy {
                    alphabet.contains($0) || legacyAlphabet.contains($0)
                }
            }
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

        let identity = shortIdentity(from: bytes)
        try storage.save(identity)
        return identity
    }

    private func shortIdentity(from bytes: Data) -> String {
        var buffer = 0
        var availableBits = 0
        var characters: [Character] = []

        for byte in bytes {
            buffer = (buffer << 8) | Int(byte)
            availableBits += 8
            while availableBits >= 5 {
                availableBits -= 5
                let index = (buffer >> availableBits) & 0b1_1111
                characters.append(Self.alphabet[index])
            }
            // Keep only the as-yet-unemitted bits. Apart from making the
            // bit-packing invariant explicit, this prevents a future larger
            // identity from accumulating consumed bits in `buffer`.
            buffer = availableBits == 0 ? 0 : buffer & ((1 << availableBits) - 1)
        }

        return String(characters)
    }
}
