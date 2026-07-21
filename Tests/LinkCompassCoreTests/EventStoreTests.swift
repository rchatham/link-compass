import XCTest
@testable import LinkCompassCore

final class EventStoreTests: XCTestCase {
    func testChoiceEventStoresNormalizedHostButNotURLPathQueryOrFragment() throws {
        let url = try XCTUnwrap(URL(string: "https://www.Example.com/private/path?token=secret#fragment"))

        let event = ChoiceEvent(
            url: url,
            chosenBrowserBundleIdentifier: "com.apple.Safari",
            preselectedBrowserBundleIdentifier: "org.mozilla.firefox",
            calendar: Calendar(identifier: .gregorian),
            date: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(event.normalizedHost, "example.com")
        XCTAssertEqual(event.chosenBrowserBundleIdentifier, "com.apple.Safari")
        XCTAssertEqual(event.preselectedBrowserBundleIdentifier, "org.mozilla.firefox")
        XCTAssertTrue(event.wasOverride)
        XCTAssertFalse(event.isFileURL)

        let encoded = String(data: try JSONEncoder.linkCompass.encode(event), encoding: .utf8)
        XCTAssertNotNil(encoded)
        XCTAssertFalse(encoded?.contains("private") ?? true)
        XCTAssertFalse(encoded?.contains("token") ?? true)
        XCTAssertFalse(encoded?.contains("secret") ?? true)
        XCTAssertFalse(encoded?.contains("fragment") ?? true)
    }

    func testChoiceEventStoresNilHostForFileURL() {
        let url = URL(fileURLWithPath: "/Users/example/private/report.html")

        let event = ChoiceEvent(
            url: url,
            chosenBrowserBundleIdentifier: "com.apple.Safari",
            preselectedBrowserBundleIdentifier: "com.apple.Safari",
            calendar: Calendar(identifier: .gregorian),
            date: Date(timeIntervalSince1970: 0)
        )

        XCTAssertNil(event.normalizedHost)
        XCTAssertTrue(event.isFileURL)
        XCTAssertFalse(event.wasOverride)
    }

    func testJSONEventStoreRetainsNewestEventsUpToLimit() throws {
        let fileURL = temporaryFileURL()
        let persistence = try JSONEventStore(fileURL: fileURL, retentionLimit: 2)
        let store = EventStore(persistence: persistence)

        try store.append(event(browser: "one"))
        try store.append(event(browser: "two"))
        try store.append(event(browser: "three"))

        let events = try store.events()
        XCTAssertEqual(events.map(\.chosenBrowserBundleIdentifier), ["two", "three"])
    }

    func testJSONEventStoreDeleteAllRemovesEventsFile() throws {
        let fileURL = temporaryFileURL()
        let persistence = try JSONEventStore(fileURL: fileURL, retentionLimit: 10)
        let store = EventStore(persistence: persistence)

        try store.append(event(browser: "one"))
        XCTAssertEqual(try store.events().count, 1)

        try store.deleteAll()

        XCTAssertEqual(try store.events(), [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    private func event(browser: String) -> ChoiceEvent {
        ChoiceEvent(
            normalizedHost: "example.com",
            chosenBrowserBundleIdentifier: browser,
            preselectedBrowserBundleIdentifier: nil,
            wasOverride: false,
            hourOfDay: 12,
            weekday: 2,
            isFileURL: false
        )
    }

    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
    }
}
