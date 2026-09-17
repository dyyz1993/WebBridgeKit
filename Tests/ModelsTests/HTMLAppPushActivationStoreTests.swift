import XCTest
@testable import WebBridgeKit

final class HTMLAppPushActivationStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var storageKey: String!

    override func setUp() {
        super.setUp()
        suiteName = "HTMLAppPushActivationStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        storageKey = "activated"
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        storageKey = nil
        super.tearDown()
    }

    func testOnlyExplicitlyActivatedAppsAppearInStore() {
        let store = HTMLAppPushActivationStore(defaults: defaults, storageKey: storageKey)
        XCTAssertFalse(store.contains("dev.drel.offline-network-demo"))

        store.activate("dev.drel.offline-network-demo")
        store.activate("dev.drel.offline-network-demo")

        XCTAssertEqual(store.activeAppIDs(), ["dev.drel.offline-network-demo"])
    }

    func testDeactivateRemovesOnlyTheSpecifiedApp() {
        let store = HTMLAppPushActivationStore(defaults: defaults, storageKey: storageKey)
        store.activate("one")
        store.activate("two")
        store.deactivate("one")

        XCTAssertFalse(store.contains("one"))
        XCTAssertTrue(store.contains("two"))
    }
}
