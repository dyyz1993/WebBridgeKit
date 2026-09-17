import XCTest
@testable import WebBridgeKit

final class PushDeviceIdentityTests: XCTestCase {
    func testCurrentOrCreateGeneratesAndPersistsURLSafeIdentity() throws {
        let storage = InMemoryPushDeviceIdentityStorage()
        var requestedByteCount = 0
        let provider = PushDeviceIdentityProvider(storage: storage) { count in
            requestedByteCount = count
            return Data((0..<count).map(UInt8.init))
        }

        let identity = try provider.currentOrCreate()

        XCTAssertEqual(requestedByteCount, 10)
        XCTAssertEqual(storage.value, identity)
        XCTAssertEqual(identity.count, 16)
        XCTAssertNotNil(
            identity.range(
                of: #"^[0123456789abcdefghjkmnpqrstvwxyz]{16}$"#,
                options: .regularExpression
            )
        )
        XCTAssertFalse(identity.contains("-"))
        XCTAssertFalse(identity.contains("i"))
        XCTAssertFalse(identity.contains("l"))
        XCTAssertFalse(identity.contains("o"))
        XCTAssertFalse(identity.contains("u"))
    }

    func testCurrentOrCreateEncodesAllTenRandomBytesDeterministically() throws {
        let storage = InMemoryPushDeviceIdentityStorage()
        let provider = PushDeviceIdentityProvider(storage: storage) { _ in
            Data((0..<10).map(UInt8.init))
        }

        XCTAssertEqual(try provider.currentOrCreate(), "000g40r40m30e209")
    }

    func testCurrentOrCreateUsesAllThirtyTwoBase32SymbolsSafely() throws {
        let storage = InMemoryPushDeviceIdentityStorage()
        let provider = PushDeviceIdentityProvider(storage: storage) { _ in
            Data([0xf8] + Array(repeating: 0, count: 9))
        }

        XCTAssertEqual(try provider.currentOrCreate(), "z000000000000000")
    }

    func testShortIdentityAcceptsCurrentAndPreexistingGroupedAddresses() {
        XCTAssertTrue(PushDeviceIdentityProvider.isShortIdentity("000g40r40m30e209"))
        XCTAssertTrue(PushDeviceIdentityProvider.isShortIdentity("uuuu-uuuu-uuuu-uuuu"))
    }

    func testCurrentIdentityRequiresUngroupedSixteenCharacterFormat() {
        XCTAssertTrue(PushDeviceIdentityProvider.isCurrentIdentity("000g40r40m30e209"))
        XCTAssertFalse(PushDeviceIdentityProvider.isCurrentIdentity("000g-40r4-0m30-e209"))
        XCTAssertFalse(PushDeviceIdentityProvider.isCurrentIdentity("existing_device-key"))
    }

    func testCurrentOrCreateReusesStoredIdentityWithoutCallingRandomSource() throws {
        let storage = InMemoryPushDeviceIdentityStorage(value: "existing_device-key")
        let provider = PushDeviceIdentityProvider(storage: storage) { _ in
            XCTFail("Random source must not run when an identity already exists")
            return Data()
        }

        XCTAssertEqual(try provider.currentOrCreate(), "existing_device-key")
        XCTAssertEqual(storage.saveCount, 0)
    }

    func testCurrentOrCreatePropagatesRandomSourceFailure() {
        let provider = PushDeviceIdentityProvider(storage: InMemoryPushDeviceIdentityStorage()) { _ in
            throw TestError.randomFailed
        }

        XCTAssertThrowsError(try provider.currentOrCreate()) { error in
            XCTAssertEqual(error as? TestError, .randomFailed)
        }
    }

    func testCurrentOrCreatePropagatesStorageFailure() {
        let storage = InMemoryPushDeviceIdentityStorage(saveError: TestError.storageFailed)
        let provider = PushDeviceIdentityProvider(storage: storage) { count in
            Data(repeating: 7, count: count)
        }

        XCTAssertThrowsError(try provider.currentOrCreate()) { error in
            XCTAssertEqual(error as? TestError, .storageFailed)
        }
    }
}

private final class InMemoryPushDeviceIdentityStorage: PushDeviceIdentityStorage {
    var value: String?
    var saveCount = 0
    private let saveError: Error?

    init(value: String? = nil, saveError: Error? = nil) {
        self.value = value
        self.saveError = saveError
    }

    func load() throws -> String? { value }

    func save(_ value: String) throws {
        if let saveError { throw saveError }
        self.value = value
        saveCount += 1
    }
}

private enum TestError: Error, Equatable {
    case randomFailed
    case storageFailed
}
