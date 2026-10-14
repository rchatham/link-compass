import XCTest
@testable import LinkCompassCore

final class ShareRoutingPolicyTests: XCTestCase {
    private let safari = Browser(displayName: "Safari", bundleIdentifier: KnownBrowser.safari.rawValue, appURL: URL(fileURLWithPath: "/Applications/Safari.app"))
    private let firefox = Browser(displayName: "Firefox", bundleIdentifier: KnownBrowser.firefox.rawValue, appURL: URL(fileURLWithPath: "/Applications/Firefox.app"))

    func testExplicitBrowserBypassesSiteAndGlobalChoice() throws {
        let preferences = LinkCompassPreferences(globalDefaultBrowserBundleIdentifier: safari.bundleIdentifier, rules: [rule(browser: safari.bundleIdentifier)])
        for remember in [false, true] {
            let request = try request(.browser(bundleIdentifier: firefox.bundleIdentifier, remember: remember))
            XCTAssertEqual(try ShareRoutingPolicy.route(request, browsers: [safari, firefox], preferences: preferences), .browser(firefox, remember: remember))
        }
    }

    func testSavedChoiceUsesNormalizedHostOverGlobalWithAutoOpenDisabled() throws {
        let preferences = LinkCompassPreferences(globalDefaultBrowserBundleIdentifier: safari.bundleIdentifier, autoOpenKnownHosts: false, learningEnabled: true, rules: [rule(browser: firefox.bundleIdentifier)])
        XCTAssertEqual(try ShareRoutingPolicy.route(try request(.savedChoice), browsers: [safari, firefox], preferences: preferences), .browser(firefox, remember: false))
    }

    func testSavedChoiceUsesGlobalDefaultWhenHostHasNoRule() throws {
        let preferences = LinkCompassPreferences(globalDefaultBrowserBundleIdentifier: firefox.bundleIdentifier, learningEnabled: true)
        XCTAssertEqual(try ShareRoutingPolicy.route(try request(.savedChoice), browsers: [safari, firefox], preferences: preferences), .browser(firefox, remember: false))
    }

    func testSavedChoiceFallsBackToPickerWithoutSavedPreferenceEvenIfLearningEnabled() throws {
        for autoOpen in [false, true] {
            let preferences = LinkCompassPreferences(autoOpenKnownHosts: autoOpen, learningEnabled: true)
            XCTAssertEqual(try ShareRoutingPolicy.route(try request(.savedChoice), browsers: [safari, firefox], preferences: preferences), .picker)
        }
    }

    func testUnavailableExplicitBrowserDoesNotSubstituteSavedChoice() throws {
        let preferences = LinkCompassPreferences(globalDefaultBrowserBundleIdentifier: safari.bundleIdentifier)
        XCTAssertThrowsError(try ShareRoutingPolicy.route(try request(.browser(bundleIdentifier: firefox.bundleIdentifier, remember: false)), browsers: [safari], preferences: preferences)) { error in
            XCTAssertEqual(error as? ShareRoutingError, .browserUnavailable(self.firefox.bundleIdentifier))
        }
    }

    func testUnavailableSavedHostDoesNotFallThroughToGlobalOrPicker() throws {
        let preferences = LinkCompassPreferences(globalDefaultBrowserBundleIdentifier: safari.bundleIdentifier, rules: [rule(browser: firefox.bundleIdentifier)])
        XCTAssertThrowsError(try ShareRoutingPolicy.route(try request(.savedChoice), browsers: [safari], preferences: preferences)) { error in
            XCTAssertEqual(error as? ShareRoutingError, .browserUnavailable(self.firefox.bundleIdentifier))
        }
    }

    func testUnavailableGlobalDefaultDoesNotSubstituteFirstBrowser() throws {
        let preferences = LinkCompassPreferences(globalDefaultBrowserBundleIdentifier: firefox.bundleIdentifier)
        XCTAssertThrowsError(try ShareRoutingPolicy.route(try request(.savedChoice), browsers: [safari], preferences: preferences))
    }

    func testUnknownSavedBrowserRejectsEvenIfListedAsInstalled() throws {
        let unknown = Browser(displayName: "Other", bundleIdentifier: "com.unknown.browser", appURL: URL(fileURLWithPath: "/Applications/Other.app"))
        let preferences = LinkCompassPreferences(globalDefaultBrowserBundleIdentifier: unknown.bundleIdentifier)
        XCTAssertThrowsError(try ShareRoutingPolicy.route(try request(.savedChoice), browsers: [unknown, safari], preferences: preferences)) { error in
            XCTAssertEqual(error as? ShareOpenRequestError, .unknownBrowser(unknown.bundleIdentifier))
        }
    }

    private func request(_ selection: ShareOpenRequest.Selection) throws -> ShareOpenRequest {
        try ShareOpenRequest(url: URL(string: "https://www.example.com./private?token=secret")!, selection: selection)
    }

    private func rule(browser: String) -> BrowserChoiceRule {
        BrowserChoiceRule(hostPattern: " WWW.Example.COM. ", browserBundleIdentifier: browser)
    }
}
