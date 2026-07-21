import XCTest
@testable import LinkCompassCore

final class RuleStoreTests: XCTestCase {
    func testRecordsAndMatchesDomainChoice() throws {
        let persistence = InMemoryPreferencesStore()
        let store = RuleStore(persistence: persistence)

        try store.recordChoice(host: "WWW.Example.COM", browserBundleIdentifier: "com.apple.Safari")

        XCTAssertEqual(store.preferredBrowserBundleIdentifier(forHost: "example.com"), "com.apple.Safari")
    }

    func testFallsBackToGlobalDefault() {
        let persistence = InMemoryPreferencesStore()
        let store = RuleStore(persistence: persistence)
        store.globalDefaultBrowserBundleIdentifier = "org.mozilla.firefox"

        XCTAssertEqual(store.preferredBrowserBundleIdentifier(forHost: "unknown.test"), "org.mozilla.firefox")
        XCTAssertNil(store.domainRuleBrowserBundleIdentifier(forHost: "unknown.test"))
    }

    func testPersistsAutoOpenKnownHostsSetting() throws {
        let persistence = InMemoryPreferencesStore()
        let store = RuleStore(persistence: persistence)

        store.autoOpenKnownHosts = true

        let reloadedStore = RuleStore(persistence: persistence)
        XCTAssertTrue(reloadedStore.autoOpenKnownHosts)
    }

    func testPersistsLearningEnabledSetting() throws {
        let persistence = InMemoryPreferencesStore()
        let store = RuleStore(persistence: persistence)

        XCTAssertFalse(store.learningEnabled)
        store.learningEnabled = true

        let reloadedStore = RuleStore(persistence: persistence)
        XCTAssertTrue(reloadedStore.learningEnabled)
    }

    func testDecodesLegacyPreferencesWithoutLearningEnabled() throws {
        let json = """
        {
          "autoOpenKnownHosts": true,
          "globalDefaultBrowserBundleIdentifier": "com.apple.Safari",
          "rules": []
        }
        """.data(using: .utf8)!

        let preferences = try JSONDecoder.linkCompass.decode(LinkCompassPreferences.self, from: json)

        XCTAssertTrue(preferences.autoOpenKnownHosts)
        XCTAssertEqual(preferences.globalDefaultBrowserBundleIdentifier, "com.apple.Safari")
        XCTAssertFalse(preferences.learningEnabled)
        XCTAssertEqual(preferences.rules, [])
    }

    func testDeletesDomainRule() throws {
        let persistence = InMemoryPreferencesStore()
        let store = RuleStore(persistence: persistence)
        try store.recordChoice(host: "example.com", browserBundleIdentifier: "com.apple.Safari")
        let rule = try XCTUnwrap(store.currentPreferences.rules.first)

        try store.deleteRule(id: rule.id)

        XCTAssertNil(store.domainRuleBrowserBundleIdentifier(forHost: "example.com"))
    }
}

private final class InMemoryPreferencesStore: PreferencesPersisting, @unchecked Sendable {
    private var preferences = LinkCompassPreferences()

    func load() throws -> LinkCompassPreferences {
        preferences
    }

    func save(_ preferences: LinkCompassPreferences) throws {
        self.preferences = preferences
    }
}
