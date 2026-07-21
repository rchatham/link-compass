import XCTest
@testable import LinkCompassCore

final class BrowserRankerTests: XCTestCase {
    private let safari = Browser(displayName: "Safari", bundleIdentifier: "com.apple.Safari", appURL: URL(fileURLWithPath: "/Applications/Safari.app"))
    private let firefox = Browser(displayName: "Firefox", bundleIdentifier: "org.mozilla.firefox", appURL: URL(fileURLWithPath: "/Applications/Firefox.app"))
    private let chrome = Browser(displayName: "Chrome", bundleIdentifier: "com.google.Chrome", appURL: URL(fileURLWithPath: "/Applications/Google Chrome.app"))

    func testRanksDomainRuleFirst() {
        let preferences = LinkCompassPreferences(
            globalDefaultBrowserBundleIdentifier: firefox.bundleIdentifier,
            rules: [BrowserChoiceRule(hostPattern: "example.com", browserBundleIdentifier: chrome.bundleIdentifier)]
        )
        let ranker = RuleBasedRanker()

        let ranked = ranker.rankedBrowsers(
            browsers: [safari, firefox, chrome],
            context: RankingContext(rememberHost: "www.example.com", supportsDomainRules: true),
            preferences: preferences
        )

        XCTAssertEqual(ranked.first(where: \.isPreferred)?.browser.bundleIdentifier, chrome.bundleIdentifier)
    }

    func testRanksGlobalDefaultWhenNoDomainRuleMatches() {
        let preferences = LinkCompassPreferences(globalDefaultBrowserBundleIdentifier: firefox.bundleIdentifier)
        let ranker = RuleBasedRanker()

        let ranked = ranker.rankedBrowsers(
            browsers: [safari, firefox, chrome],
            context: RankingContext(rememberHost: "unknown.test", supportsDomainRules: true),
            preferences: preferences
        )

        XCTAssertEqual(ranked.first(where: \.isPreferred)?.browser.bundleIdentifier, firefox.bundleIdentifier)
    }

    func testRanksFirstBrowserWhenNoPreferenceExistsWithoutMarkingItPreferenceBacked() {
        let ranker = RuleBasedRanker()

        let ranked = ranker.rankedBrowsers(
            browsers: [safari, firefox, chrome],
            context: RankingContext(rememberHost: "unknown.test", supportsDomainRules: true),
            preferences: LinkCompassPreferences()
        )

        let preferred = ranked.first(where: \.isPreferred)
        XCTAssertEqual(preferred?.browser.bundleIdentifier, safari.bundleIdentifier)
        XCTAssertEqual(preferred?.isPreferenceBacked, false)
    }

    func testPreferenceBackedSelectionIsMarkedForDomainRule() {
        let preferences = LinkCompassPreferences(
            rules: [BrowserChoiceRule(hostPattern: "example.com", browserBundleIdentifier: chrome.bundleIdentifier)]
        )
        let ranker = RuleBasedRanker()

        let ranked = ranker.rankedBrowsers(
            browsers: [safari, firefox, chrome],
            context: RankingContext(rememberHost: "example.com", supportsDomainRules: true),
            preferences: preferences
        )

        let preferred = ranked.first(where: \.isPreferred)
        XCTAssertEqual(preferred?.browser.bundleIdentifier, chrome.bundleIdentifier)
        XCTAssertEqual(preferred?.isPreferenceBacked, true)
    }

    func testAutoOpenRequiresExplicitDomainRuleAndEnabledSetting() {
        let preferences = LinkCompassPreferences(
            autoOpenKnownHosts: true,
            rules: [BrowserChoiceRule(hostPattern: "example.com", browserBundleIdentifier: chrome.bundleIdentifier)]
        )
        let ranker = RuleBasedRanker()

        let browser = ranker.autoOpenBrowser(
            browsers: [safari, firefox, chrome],
            context: RankingContext(rememberHost: "example.com", supportsDomainRules: true),
            preferences: preferences
        )

        XCTAssertEqual(browser?.bundleIdentifier, chrome.bundleIdentifier)
    }

    func testAutoOpenIgnoresGlobalDefaultAndFileURLs() {
        let preferences = LinkCompassPreferences(
            globalDefaultBrowserBundleIdentifier: firefox.bundleIdentifier,
            autoOpenKnownHosts: true
        )
        let ranker = RuleBasedRanker()

        let browser = ranker.autoOpenBrowser(
            browsers: [safari, firefox, chrome],
            context: RankingContext(rememberHost: nil, supportsDomainRules: false),
            preferences: preferences
        )

        XCTAssertNil(browser)
    }
}
