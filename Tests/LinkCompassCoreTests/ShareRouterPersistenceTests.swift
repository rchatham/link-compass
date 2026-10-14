import XCTest
@testable import LinkCompassCore

@MainActor
final class ShareRouterPersistenceTests: XCTestCase {
    private enum LaunchError: Error { case failed }

    func testUncheckedExplicitOpenLeavesEveryPersistenceFileByteIdentical() async throws {
        let fixture = try Fixture(seed: true)
        defer { fixture.remove() }
        let before = try fixture.snapshot()
        var launches = 0
        let route = try await fixture.router.open(try fixture.approved(remember: false), browsers: fixture.browsers) { url, browser in
            launches += 1
            XCTAssertEqual(url, fixture.url)
            XCTAssertEqual(browser, fixture.firefox)
        }
        XCTAssertEqual(route, .browser(fixture.firefox, remember: false))
        XCTAssertEqual(launches, 1)
        XCTAssertEqual(try fixture.snapshot(), before)
    }

    func testUncheckedFirstUseDoesNotCreateDefaultLearningOrPendingFiles() async throws {
        let fixture = try Fixture(seed: false)
        defer { fixture.remove() }
        var launches = 0
        try await fixture.router.open(try fixture.approved(remember: false), browsers: fixture.browsers) { _, _ in launches += 1 }
        XCTAssertEqual(launches, 1)
        XCTAssertEqual(try fixture.snapshot(), [:])
        XCTAssertNil(try fixture.preferences.load().globalDefaultBrowserBundleIdentifier)
    }

    func testRememberWritesOnlySiteAfterSuccessfulLaunch() async throws {
        let fixture = try Fixture(seed: true)
        defer { fixture.remove() }
        let before = try fixture.snapshot()
        let original = try fixture.preferences.load()
        let route = try await fixture.router.open(try fixture.approved(remember: true), browsers: fixture.browsers) { _, _ in
            XCTAssertEqual(try fixture.snapshot(), before, "No persistence may precede a successful launch")
        }
        XCTAssertEqual(route, .browser(fixture.firefox, remember: true))
        let after = try fixture.snapshot()
        XCTAssertEqual(after["events.json"], before["events.json"])
        XCTAssertEqual(after["pending.json"], before["pending.json"])
        let saved = try fixture.preferences.load()
        XCTAssertEqual(saved.globalDefaultBrowserBundleIdentifier, original.globalDefaultBrowserBundleIdentifier)
        XCTAssertEqual(saved.autoOpenKnownHosts, original.autoOpenKnownHosts)
        XCTAssertEqual(saved.learningEnabled, original.learningEnabled)
        XCTAssertEqual(saved.rules.first(where: { $0.hostPattern == "other.example" }), original.rules.first(where: { $0.hostPattern == "other.example" }))
        let site = try XCTUnwrap(saved.rules.first(where: { $0.hostPattern == "example.com" }))
        XCTAssertEqual(site.browserBundleIdentifier, fixture.firefox.bundleIdentifier)
        XCTAssertEqual(site.usageCount, 6)
        let preferencesText = try XCTUnwrap(String(data: try XCTUnwrap(after["preferences.json"]), encoding: .utf8))
        XCTAssertFalse(preferencesText.contains("private"))
        XCTAssertFalse(preferencesText.contains("secret"))
    }

    func testRememberFirstUseDoesNotSetGlobalDefaultOrWriteHistory() async throws {
        let fixture = try Fixture(seed: false)
        defer { fixture.remove() }
        try await fixture.router.open(try fixture.approved(remember: true), browsers: fixture.browsers) { _, _ in }
        let saved = try fixture.preferences.load()
        XCTAssertNil(saved.globalDefaultBrowserBundleIdentifier)
        XCTAssertEqual(saved.rules.map(\.browserBundleIdentifier), [fixture.firefox.bundleIdentifier])
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.directory.appendingPathComponent("events.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.directory.appendingPathComponent("pending.json").path))
    }

    func testFailedLaunchNeverPersistsRememberIntent() async throws {
        for seed in [false, true] {
            let fixture = try Fixture(seed: seed)
            defer { fixture.remove() }
            let before = try fixture.snapshot()
            do {
                try await fixture.router.open(try fixture.approved(remember: true), browsers: fixture.browsers) { _, _ in throw LaunchError.failed }
                XCTFail("Expected launch failure")
            } catch {
                XCTAssertTrue(error is LaunchError)
            }
            XCTAssertEqual(try fixture.snapshot(), before)
        }
    }

    func testWireOpenOnceConsentDoesNotWriteDespiteRememberFlag() async throws {
        let fixture = try Fixture(seed: true)
        defer { fixture.remove() }
        let before = try fixture.snapshot()
        let wire = try ShareOpenRequest(url: fixture.url, selection: .browser(bundleIdentifier: fixture.firefox.bundleIdentifier, remember: true))
        let approved = try XCTUnwrap(ShareConsentPolicy.approve(wire, origin: .wire, consent: .openOnce))
        var launches = 0
        try await fixture.router.open(approved, browsers: fixture.browsers) { _, _ in launches += 1 }
        XCTAssertEqual(launches, 1)
        XCTAssertEqual(try fixture.snapshot(), before)
    }

    func testCanceledConsentNeverLaunchesOrWrites() async throws {
        let fixture = try Fixture(seed: true)
        defer { fixture.remove() }
        let before = try fixture.snapshot()
        let wire = try ShareOpenRequest(url: fixture.url, selection: .browser(bundleIdentifier: fixture.firefox.bundleIdentifier, remember: true))
        var launches = 0
        if let approved = try ShareConsentPolicy.approve(wire, origin: .wire, consent: .cancel) {
            try await fixture.router.open(approved, browsers: fixture.browsers) { _, _ in launches += 1 }
        }
        XCTAssertEqual(launches, 0)
        XCTAssertEqual(try fixture.snapshot(), before)
    }

    func testSavedChoiceSkipsLearnedSuggestionAndWritesNothing() async throws {
        let fixture = try Fixture(seed: true)
        defer { fixture.remove() }
        let before = try fixture.snapshot()
        let events = try fixture.events.load()
        XCTAssertEqual(ChoiceInsights.suggestion(forHost: "example.com", events: events)?.bundleIdentifier, fixture.firefox.bundleIdentifier)
        let wire = try ShareOpenRequest(url: fixture.url, selection: .savedChoice)
        let approved = try XCTUnwrap(ShareConsentPolicy.approve(wire, origin: .wire))
        var openedBrowser: Browser?
        try await fixture.router.open(approved, browsers: fixture.browsers) { _, browser in openedBrowser = browser }
        XCTAssertEqual(openedBrowser, fixture.safari)
        XCTAssertEqual(try fixture.snapshot(), before)
    }

    func testPickerFallbackAndMissingBrowserNeverLaunchOrWrite() async throws {
        for seed in [false, true] {
            let fixture = try Fixture(seed: seed)
            defer { fixture.remove() }
            let before = try fixture.snapshot()
            let wire = try ShareOpenRequest(url: fixture.url, selection: .savedChoice)
            let approved = try XCTUnwrap(ShareConsentPolicy.approve(wire, origin: .wire))
            var launches = 0
            do {
                let route = try await fixture.router.open(approved, browsers: [fixture.firefox]) { _, _ in launches += 1 }
                XCTAssertFalse(seed, "Existing unavailable site rule must fail")
                XCTAssertEqual(route, .picker)
            } catch {
                XCTAssertTrue(seed)
                XCTAssertEqual(error as? ShareRoutingError, .browserUnavailable(fixture.safari.bundleIdentifier))
            }
            XCTAssertEqual(launches, 0)
            XCTAssertEqual(try fixture.snapshot(), before)
        }
    }

    func testRememberPreservesPreferenceChangesMadeDuringLaunch() async throws {
        let fixture = try Fixture(seed: true)
        defer { fixture.remove() }
        try await fixture.router.open(try fixture.approved(remember: true), browsers: fixture.browsers) { _, _ in
            var preferences = try fixture.preferences.load()
            preferences.globalDefaultBrowserBundleIdentifier = KnownBrowser.brave.rawValue
            preferences.learningEnabled = false
            try fixture.preferences.save(preferences)
        }
        let saved = try fixture.preferences.load()
        XCTAssertEqual(saved.globalDefaultBrowserBundleIdentifier, KnownBrowser.brave.rawValue)
        XCTAssertFalse(saved.learningEnabled)
        XCTAssertEqual(saved.rules.first(where: { $0.hostPattern == "example.com" })?.browserBundleIdentifier, fixture.firefox.bundleIdentifier)
    }

    func testSaveFailureIsReportedAfterLaunchInsteadOfBeingSwallowed() async throws {
        let fixture = try Fixture(seed: false)
        defer { fixture.remove() }
        let router = ShareRouter(ruleStore: RuleStore(persistence: FailingPreferences()))
        var launches = 0
        do {
            try await router.open(try fixture.approved(remember: true), browsers: fixture.browsers) { _, _ in launches += 1 }
            XCTFail("Expected persistence failure")
        } catch {
            guard case .couldNotSavePreference = error as? ShareRoutingError else {
                XCTFail("Unexpected error: \(error)")
                return
            }
        }
        XCTAssertEqual(launches, 1)
    }

    private struct FailingPreferences: PreferencesPersisting {
        func load() throws -> LinkCompassPreferences { LinkCompassPreferences() }
        func save(_ preferences: LinkCompassPreferences) throws { throw CocoaError(.fileWriteNoPermission) }
    }

    @MainActor
    private struct Fixture {
        let directory: URL
        let preferences: JSONPreferencesStore
        let events: JSONEventStore
        let router: ShareRouter
        let url = URL(string: "https://www.example.com./private?token=secret")!
        let safari = Browser(displayName: "Safari", bundleIdentifier: KnownBrowser.safari.rawValue, appURL: URL(fileURLWithPath: "/Applications/Safari.app"))
        let firefox = Browser(displayName: "Firefox", bundleIdentifier: KnownBrowser.firefox.rawValue, appURL: URL(fileURLWithPath: "/Applications/Firefox.app"))
        var browsers: [Browser] { [safari, firefox] }

        init(seed: Bool) throws {
            directory = FileManager.default.temporaryDirectory.appendingPathComponent("LinkCompass-share-tests-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            preferences = try JSONPreferencesStore(fileURL: directory.appendingPathComponent("preferences.json"))
            events = try JSONEventStore(fileURL: directory.appendingPathComponent("events.json"))
            if seed {
                try preferences.save(LinkCompassPreferences(
                    globalDefaultBrowserBundleIdentifier: safari.bundleIdentifier,
                    autoOpenKnownHosts: false,
                    learningEnabled: true,
                    rules: [
                        BrowserChoiceRule(hostPattern: "example.com", browserBundleIdentifier: safari.bundleIdentifier, usageCount: 5),
                        BrowserChoiceRule(hostPattern: "other.example", browserBundleIdentifier: safari.bundleIdentifier, usageCount: 3)
                    ]
                ))
                let learnedEvent = ChoiceEvent(url: url, chosenBrowserBundleIdentifier: firefox.bundleIdentifier, preselectedBrowserBundleIdentifier: nil)
                try events.save(Array(repeating: learnedEvent, count: 5))
                let pendingPersistence = try JSONPendingRoutePersistence(fileURL: directory.appendingPathComponent("pending.json"))
                try PendingRouteStore(persistence: pendingPersistence).recordRoute(url: url, browserBundleIdentifier: safari.bundleIdentifier, browserDisplayName: safari.displayName)
            }
            router = ShareRouter(ruleStore: RuleStore(persistence: preferences))
        }

        func approved(remember: Bool) throws -> ApprovedShareOpenRequest {
            let wire = try ShareOpenRequest(url: url, selection: .browser(bundleIdentifier: firefox.bundleIdentifier, remember: remember))
            return try XCTUnwrap(ShareConsentPolicy.approve(wire, origin: .wire, consent: .openAndRemember))
        }

        func snapshot() throws -> [String: Data] {
            var files: [String: Data] = [:]
            for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
                files[file.lastPathComponent] = try Data(contentsOf: file)
            }
            return files
        }

        func remove() {
            do {
                try FileManager.default.removeItem(at: directory)
            } catch {
                XCTFail("Could not remove temporary test fixture: \(error)")
            }
        }
    }
}
