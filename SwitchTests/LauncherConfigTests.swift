import XCTest
@testable import Switch

final class LauncherConfigTests: XCTestCase {

    private let safari = "/Applications/Safari.app"
    private let capture = "cleanshot://capture-window"

    private func makeConfig() -> LauncherConfig {
        var config = LauncherConfig()
        config.leaderKeyCode = 109 // F10
        config.timeoutMs = 500
        config.mappings = [
            LauncherMapping(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                keyCode: 1, target: safari, isSecondary: false), // S
            LauncherMapping(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                keyCode: 46, target: capture, isSecondary: true), // M
        ]
        return config
    }

    // MARK: - Lookup

    func testLookupFindsPrimaryMapping() {
        XCTAssertEqual(makeConfig().target(for: 1, secondary: false), safari)
    }

    func testLookupFindsSecondaryMapping() {
        XCTAssertEqual(makeConfig().target(for: 46, secondary: true), capture)
    }

    func testLookupRespectsSetBoundary() {
        XCTAssertNil(makeConfig().target(for: 1, secondary: true))
        XCTAssertNil(makeConfig().target(for: 46, secondary: false))
    }

    func testLookupIgnoresIncompleteRows() {
        var config = LauncherConfig()
        config.mappings = [
            LauncherMapping(keyCode: 1, target: nil, isSecondary: false),
            LauncherMapping(keyCode: nil, target: safari, isSecondary: false),
        ]
        XCTAssertNil(config.target(for: 1, secondary: false))
    }

    // MARK: - Persistence

    func testStoreRoundTripsThroughDefaults() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let store = LauncherConfigStore(defaults: defaults)
        store.config = makeConfig()

        let reloaded = LauncherConfigStore(defaults: defaults)
        XCTAssertEqual(reloaded.config, makeConfig())
    }

    func testStoreDefaultsToDisabledConfig() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let store = LauncherConfigStore(defaults: defaults)
        XCTAssertNil(store.config.leaderKeyCode)
        XCTAssertEqual(store.config.timeoutMs, 600)
        XCTAssertTrue(store.config.mappings.isEmpty)
    }

    // MARK: - Sorting

    func testSortMappingsOrdersPrimaryFirstThenByKeyNameWithUnsetKeysLast() {
        var config = LauncherConfig()
        config.mappings = [
            LauncherMapping(keyCode: 1, target: "/b.app", isSecondary: true),    // S, secondary
            LauncherMapping(keyCode: 1, target: "/a.app", isSecondary: false),   // S
            LauncherMapping(keyCode: nil, target: "/c.app", isSecondary: false), // unset key
            LauncherMapping(keyCode: 0, target: "/d.app", isSecondary: false),   // A
        ]
        config.sortMappings()
        XCTAssertEqual(config.mappings.map(\.target), ["/d.app", "/a.app", "/c.app", "/b.app"])
    }

    // MARK: - Migration

    func testDecodesLegacyAppURLField() throws {
        // Mappings were originally persisted with an `appURL` URL field.
        let legacy = """
        {"leaderKeyCode":109,"timeoutMs":600,"mappings":[
            {"id":"00000000-0000-0000-0000-000000000001",
             "appURL":"file:///Applications/Safari.app/","isSecondary":false,"keyCode":1},
            {"id":"00000000-0000-0000-0000-000000000002",
             "appURL":"cleanshot://capture-window","isSecondary":true,"keyCode":46}
        ]}
        """
        let config = try JSONDecoder().decode(LauncherConfig.self, from: Data(legacy.utf8))
        XCTAssertEqual(config.mappings[0].target, safari)
        XCTAssertEqual(config.mappings[1].target, capture)
    }
}
