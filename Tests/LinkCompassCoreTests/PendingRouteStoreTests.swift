import XCTest
@testable import LinkCompassCore

final class PendingRouteStoreTests: XCTestCase {
    func testRecordsOnlyNormalizedHostAndBrowserMetadata() throws {
        let persistence = InMemoryPendingRoutePersistence()
        let store = PendingRouteStore(persistence: persistence, routeLifetime: 60)

        let route = try store.recordRoute(
            url: URL(string: "https://www.Example.com/private/path?token=secret#fragment")!,
            browserBundleIdentifier: "com.google.Chrome",
            browserDisplayName: "Google Chrome",
            date: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(route?.normalizedHost, "example.com")
        XCTAssertEqual(route?.browserBundleIdentifier, "com.google.Chrome")
        XCTAssertEqual(route?.browserDisplayName, "Google Chrome")
        XCTAssertEqual(persistence.routes.first?.normalizedHost, "example.com")
        let encoded = String(data: try JSONEncoder.linkCompass.encode(persistence.routes), encoding: .utf8)
        XCTAssertFalse(encoded?.contains("private/path") ?? true)
        XCTAssertFalse(encoded?.contains("token=secret") ?? true)
        XCTAssertFalse(encoded?.contains("fragment") ?? true)
    }

    func testDoesNotRecordFileURLs() throws {
        let persistence = InMemoryPendingRoutePersistence()
        let store = PendingRouteStore(persistence: persistence)

        let route = try store.recordRoute(
            url: URL(fileURLWithPath: "/tmp/example.html"),
            browserBundleIdentifier: "com.apple.Safari",
            browserDisplayName: "Safari"
        )

        XCTAssertNil(route)
        XCTAssertTrue(persistence.routes.isEmpty)
    }

    func testRecentRouteIgnoresExpiredRoutes() throws {
        let persistence = InMemoryPendingRoutePersistence()
        let store = PendingRouteStore(persistence: persistence, routeLifetime: 10)
        let date = Date(timeIntervalSince1970: 100)
        _ = try store.recordRoute(
            url: URL(string: "https://example.com")!,
            browserBundleIdentifier: "com.google.Chrome",
            browserDisplayName: "Google Chrome",
            date: date
        )

        XCTAssertNotNil(try store.recentRoute(for: URL(string: "https://example.com/next")!, date: date.addingTimeInterval(9)))
        XCTAssertNil(try store.recentRoute(for: URL(string: "https://example.com/next")!, date: date.addingTimeInterval(11)))
        XCTAssertTrue(persistence.routes.isEmpty)
    }
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
