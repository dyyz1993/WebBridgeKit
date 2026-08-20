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

        XCTAssertEqual(requestedByteCount, 32)
        XCTAssertEqual(storage.value, identity)
        XCTAssertFalse(identity.isEmpty)
        XCTAssertNil(identity.range(of: #"[^A-Za-z0-9_-]"#, options: .regularExpression))
        XCTAssertFalse(identity.contains("/"))
        XCTAssertFalse(identity.contains("+"))
        XCTAssertFalse(identity.contains("="))
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
