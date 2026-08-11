import XCTest
@testable import LinkCompassCore

final class NativeHostMessageHandlerTests: XCTestCase {
    func testRecentRouteForURLReturnsUnexpiredMatchWithoutFullURL() throws {
        let routePersistence = InMemoryPendingRoutePersistence()
        let routeStore = PendingRouteStore(persistence: routePersistence, routeLifetime: 60)
        _ = try routeStore.recordRoute(
            url: URL(string: "https://example.com/private?token=secret")!,
            browserBundleIdentifier: "com.google.Chrome",
            browserDisplayName: "Google Chrome"
        )
        let handler = NativeHostMessageHandler(
            routeStore: routeStore,
            ruleStore: RuleStore(persistence: InMemoryPreferencesPersistence())
        )

        let response = handler.handle(jsonData(["type": "recentRouteForURL", "url": "https://www.example.com/other#fragment"]))

        XCTAssertTrue(response.ok)
        XCTAssertEqual(response.type, "recentRouteForURLResult")
        XCTAssertEqual(response.matched, true)
        XCTAssertEqual(response.host, "example.com")
        XCTAssertEqual(response.browserBundleIdentifier, "com.google.Chrome")
        XCTAssertEqual(response.browserDisplayName, "Google Chrome")
        XCTAssertNil(response.error)
    }

    func testRecentRouteForURLRejectsFileURL() throws {
        let handler = NativeHostMessageHandler(
            routeStore: PendingRouteStore(persistence: InMemoryPendingRoutePersistence()),
            ruleStore: RuleStore(persistence: InMemoryPreferencesPersistence())
        )

        let response = handler.handle(jsonData(["type": "recentRouteForURL", "url": "file:///tmp/example.html"]))

        XCTAssertFalse(response.ok)
        XCTAssertEqual(response.type, "error")
    }

    func testRememberRoutePersistsNormalizedHostRule() throws {
        let preferencesPersistence = InMemoryPreferencesPersistence()
        let handler = NativeHostMessageHandler(
            routeStore: PendingRouteStore(persistence: InMemoryPendingRoutePersistence()),
            ruleStore: RuleStore(persistence: preferencesPersistence)
        )

        let response = handler.handle(jsonData([
            "type": "rememberRoute",
            "host": "www.Example.com.",
            "browserBundleIdentifier": "com.google.Chrome"
        ]))

        XCTAssertTrue(response.ok)
        XCTAssertEqual(response.type, "rememberRouteResult")
        XCTAssertEqual(response.host, "example.com")
        XCTAssertEqual(preferencesPersistence.preferences.rules.first?.hostPattern, "example.com")
        XCTAssertEqual(preferencesPersistence.preferences.rules.first?.browserBundleIdentifier, "com.google.Chrome")
    }

    func testUnsupportedMessageTypeReturnsStructuredError() throws {
        let handler = NativeHostMessageHandler(
            routeStore: PendingRouteStore(persistence: InMemoryPendingRoutePersistence()),
            ruleStore: RuleStore(persistence: InMemoryPreferencesPersistence())
        )

        let response = handler.handle(jsonData(["type": "unknown"]));

        XCTAssertFalse(response.ok)
        XCTAssertEqual(response.type, "error")
        XCTAssertTrue(response.error?.contains("Unsupported message type") ?? false)
    }
}

private func jsonData(_ object: [String: String]) -> Data {
    try! JSONSerialization.data(withJSONObject: object)
}

private final class InMemoryPendingRoutePersistence: PendingRoutePersisting, @unchecked Sendable {
    var routes: [PendingRoute] = []

    func load() throws -> [PendingRoute] {
        routes
    }

    func save(_ routes: [PendingRoute]) throws {
        self.routes = routes
    }
}

private final class InMemoryPreferencesPersistence: PreferencesPersisting, @unchecked Sendable {
    var preferences = LinkCompassPreferences()

    func load() throws -> LinkCompassPreferences {
        preferences
    }

    func save(_ preferences: LinkCompassPreferences) throws {
        self.preferences = preferences
    }
}
