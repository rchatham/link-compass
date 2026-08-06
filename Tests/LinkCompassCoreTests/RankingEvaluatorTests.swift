import XCTest
@testable import LinkCompassCore

final class RankingEvaluatorTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    func testLearnedEvaluationImprovesAfterHostHistoryIsAvailable() {
        let events = [
            event(host: "example.com", browser: "org.mozilla.firefox", offset: 0),
            event(host: "example.com", browser: "org.mozilla.firefox", offset: 1),
            event(host: "example.com", browser: "org.mozilla.firefox", offset: 2),
            event(host: "other.com", browser: "com.apple.Safari", offset: 3)
        ]

        let baseline = RankingEvaluator.evaluate(events: events, mode: .baseline)
        let learned = RankingEvaluator.evaluate(events: events, mode: .learned)

        XCTAssertEqual(baseline.metrics.evaluatedEvents, 4)
        XCTAssertLessThan(baseline.metrics.topOneAccuracy, learned.metrics.topOneAccuracy)
        XCTAssertEqual(learned.metrics.correctTopPredictions, 2)
    }

    func testEvaluationIgnoresFileEventsAndNilHosts() {
        let events = [
            event(host: "example.com", browser: "com.apple.Safari", offset: 0),
            event(host: nil, browser: "com.apple.Safari", offset: 1),
            event(host: nil, browser: "com.apple.Safari", offset: 2, isFileURL: true)
        ]

        let report = RankingEvaluator.evaluate(events: events, mode: .learned)

        XCTAssertEqual(report.metrics.totalEvents, 3)
        XCTAssertEqual(report.metrics.evaluatedEvents, 1)
    }

    func testLearnedEvaluationUsesOnlyPastEvents() {
        let events = [
            event(host: "example.com", browser: "org.mozilla.firefox", offset: 0),
            event(host: "example.com", browser: "org.mozilla.firefox", offset: 1),
            event(host: "other.com", browser: "com.apple.Safari", offset: 2)
        ]

        let learned = RankingEvaluator.evaluate(events: events, mode: .learned, minimumChoices: 2)

        XCTAssertEqual(learned.metrics.evaluatedEvents, 3)
        XCTAssertEqual(learned.metrics.correctTopPredictions, 1)
    }

    func testPerHostMetricsAreReported() {
        let events = [
            event(host: "example.com", browser: "com.apple.Safari", offset: 0),
            event(host: "example.com", browser: "com.apple.Safari", offset: 1),
            event(host: "other.com", browser: "org.mozilla.firefox", offset: 2)
        ]

        let report = RankingEvaluator.evaluate(events: events, mode: .learned)

        XCTAssertEqual(report.perHostMetrics["example.com"]?.totalEvents, 2)
        XCTAssertEqual(report.perHostMetrics["other.com"]?.totalEvents, 1)
    }

    private func event(host: String?, browser: String, offset: TimeInterval, isFileURL: Bool = false) -> ChoiceEvent {
        ChoiceEvent(
            createdAt: start.addingTimeInterval(offset),
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
