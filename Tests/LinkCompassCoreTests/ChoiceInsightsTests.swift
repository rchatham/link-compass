import XCTest
@testable import LinkCompassCore

final class ChoiceInsightsTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testScoresChooseFrequencyWinner() {
        let events = [
            event(host: "example.com", browser: "safari", daysAgo: 1),
            event(host: "example.com", browser: "safari", daysAgo: 2),
            event(host: "example.com", browser: "firefox", daysAgo: 1)
        ]

        let scores = ChoiceInsights.scores(forHost: "example.com", events: events, now: now)

        XCTAssertEqual(scores.first?.bundleIdentifier, "safari")
        XCTAssertEqual(scores.first?.choiceCount, 2)
    }

    func testScoresAllowRecentMinorityToOutrankStaleMajority() {
        let events = [
            event(host: "example.com", browser: "safari", daysAgo: 120),
            event(host: "example.com", browser: "safari", daysAgo: 120),
            event(host: "example.com", browser: "safari", daysAgo: 120),
            event(host: "example.com", browser: "firefox", daysAgo: 0)
        ]

        let scores = ChoiceInsights.scores(forHost: "example.com", events: events, now: now, halfLifeDays: 10)

        XCTAssertEqual(scores.first?.bundleIdentifier, "firefox")
    }

    func testSuggestionRequiresMinimumChoices() {
        let events = [event(host: "example.com", browser: "safari", daysAgo: 0)]

        let suggestion = ChoiceInsights.suggestion(forHost: "example.com", events: events, now: now, minimumChoices: 2)

        XCTAssertNil(suggestion)
    }

    func testSuggestionRequiresWinningBrowserToMeetMinimumChoices() {
        let events = [
            event(host: "example.com", browser: "safari", daysAgo: 0),
            event(host: "example.com", browser: "firefox", daysAgo: 0)
        ]

        let suggestion = ChoiceInsights.suggestion(forHost: "example.com", events: events, now: now, minimumChoices: 2)

        XCTAssertNil(suggestion)
    }

    func testSuggestionReturnsTopScoreWhenThresholdIsMet() throws {
        let events = [
            event(host: "example.com", browser: "safari", daysAgo: 2),
            event(host: "example.com", browser: "safari", daysAgo: 1)
        ]

        let suggestion = try XCTUnwrap(ChoiceInsights.suggestion(forHost: "example.com", events: events, now: now))

        XCTAssertEqual(suggestion.normalizedHost, "example.com")
        XCTAssertEqual(suggestion.bundleIdentifier, "safari")
        XCTAssertEqual(suggestion.choiceCount, 2)
    }

    func testScoresUseDeterministicTieBreaks() {
        let events = [
            event(host: "example.com", browser: "z-browser", daysAgo: 0),
            event(host: "example.com", browser: "a-browser", daysAgo: 0)
        ]

        let scores = ChoiceInsights.scores(forHost: "example.com", events: events, now: now)

        XCTAssertEqual(scores.map(\.bundleIdentifier), ["a-browser", "z-browser"])
    }

    func testScoresIgnoreOtherHostsFileURLsAndNilHosts() {
        let events = [
            event(host: "example.com", browser: "safari", daysAgo: 0),
            event(host: "other.com", browser: "firefox", daysAgo: 0),
            event(host: "example.com", browser: "chrome", daysAgo: 0, isFileURL: true),
            event(host: nil, browser: "brave", daysAgo: 0)
        ]

        let scores = ChoiceInsights.scores(forHost: "example.com", events: events, now: now)

        XCTAssertEqual(scores.map(\.bundleIdentifier), ["safari"])
    }

    func testScoresNormalizeWWWAndTrailingDot() {
        let events = [
            event(host: "www.example.com.", browser: "safari", daysAgo: 0),
            event(host: "example.com", browser: "safari", daysAgo: 0)
        ]

        let suggestion = ChoiceInsights.suggestion(forHost: "WWW.EXAMPLE.COM", events: events, now: now)

        XCTAssertEqual(suggestion?.bundleIdentifier, "safari")
        XCTAssertEqual(suggestion?.choiceCount, 2)
    }

    private func event(host: String?, browser: String, daysAgo: Double, isFileURL: Bool = false) -> ChoiceEvent {
        ChoiceEvent(
            createdAt: now.addingTimeInterval(-daysAgo * 86_400),
            normalizedHost: host,
            chosenBrowserBundleIdentifier: browser,
            preselectedBrowserBundleIdentifier: nil,
            wasOverride: false,
            hourOfDay: 12,
            weekday: 2,
            isFileURL: isFileURL
        )
    }
}
