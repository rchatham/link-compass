import Foundation

public enum RankingEvaluationMode: String, Codable, Sendable {
    case baseline
    case learned
}

public struct RankingEvaluationMetrics: Codable, Equatable, Sendable {
    public let totalEvents: Int
    public let evaluatedEvents: Int
    public let correctTopPredictions: Int
    public let incorrectTopPredictions: Int

    public var topOneAccuracy: Double {
        guard evaluatedEvents > 0 else { return 0 }
        return Double(correctTopPredictions) / Double(evaluatedEvents)
    }

    public var topOneErrorRate: Double {
        guard evaluatedEvents > 0 else { return 0 }
        return Double(incorrectTopPredictions) / Double(evaluatedEvents)
    }

    public init(totalEvents: Int, evaluatedEvents: Int, correctTopPredictions: Int, incorrectTopPredictions: Int) {
        self.totalEvents = totalEvents
        self.evaluatedEvents = evaluatedEvents
        self.correctTopPredictions = correctTopPredictions
        self.incorrectTopPredictions = incorrectTopPredictions
    }
}

public struct RankingEvaluationReport: Codable, Equatable, Sendable {
    public let mode: RankingEvaluationMode
    public let metrics: RankingEvaluationMetrics
    public let perHostMetrics: [String: RankingEvaluationMetrics]

    public init(
        mode: RankingEvaluationMode,
        metrics: RankingEvaluationMetrics,
        perHostMetrics: [String: RankingEvaluationMetrics]
    ) {
        self.mode = mode
        self.metrics = metrics
        self.perHostMetrics = perHostMetrics
    }
}

public enum RankingEvaluator {
    public static func evaluate(
        events: [ChoiceEvent],
        mode: RankingEvaluationMode,
        minimumChoices: Int = 2,
        halfLifeDays: Double = 30
    ) -> RankingEvaluationReport {
        let orderedEvents = events.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        let browsers = browsersObserved(in: orderedEvents)
        let ranker = RuleBasedRanker()
        let preferences = LinkCompassPreferences()
        var history: [ChoiceEvent] = []
        var aggregate = MutableEvaluationMetrics()
        var perHost: [String: MutableEvaluationMetrics] = [:]

        for event in orderedEvents {
            defer { history.append(event) }
            aggregate.totalEvents += 1

            guard !event.isFileURL,
                  let host = event.normalizedHost,
                  !browsers.isEmpty else {
                continue
            }

            let learnedBundleIdentifier: String?
            switch mode {
            case .baseline:
                learnedBundleIdentifier = nil
            case .learned:
                learnedBundleIdentifier = ChoiceInsights.suggestion(
                    forHost: host,
                    events: history,
                    now: event.createdAt,
                    halfLifeDays: halfLifeDays,
                    minimumChoices: minimumChoices
                )?.bundleIdentifier
            }

            let ranked = ranker.rankedBrowsers(
                browsers: browsers,
                context: RankingContext(
                    rememberHost: host,
                    supportsDomainRules: true,
                    learnedSuggestionBundleIdentifier: learnedBundleIdentifier
                ),
                preferences: preferences
            )
            guard let predictedBundleIdentifier = ranked.first(where: \.isPreferred)?.browser.bundleIdentifier else {
                continue
            }

            let isCorrect = predictedBundleIdentifier == event.chosenBrowserBundleIdentifier
            aggregate.recordEvaluated(isCorrect: isCorrect)
            perHost[host, default: MutableEvaluationMetrics(totalEvents: 0)].totalEvents += 1
            perHost[host]?.recordEvaluated(isCorrect: isCorrect)
        }

        return RankingEvaluationReport(
            mode: mode,
            metrics: aggregate.snapshot(),
            perHostMetrics: perHost.mapValues { $0.snapshot() }
        )
    }

    private static func browsersObserved(in events: [ChoiceEvent]) -> [Browser] {
        let bundleIdentifiers = Set(events.flatMap { event in
            [event.chosenBrowserBundleIdentifier, event.preselectedBrowserBundleIdentifier].compactMap { $0 }
        })
        return bundleIdentifiers.sorted().map { bundleIdentifier in
            Browser(
                displayName: bundleIdentifier,
                bundleIdentifier: bundleIdentifier,
                appURL: URL(fileURLWithPath: "/Applications")
            )
        }
    }
}

private struct MutableEvaluationMetrics {
    var totalEvents: Int
    var evaluatedEvents: Int
    var correctTopPredictions: Int
    var incorrectTopPredictions: Int

    init(totalEvents: Int = 0, evaluatedEvents: Int = 0, correctTopPredictions: Int = 0, incorrectTopPredictions: Int = 0) {
        self.totalEvents = totalEvents
        self.evaluatedEvents = evaluatedEvents
        self.correctTopPredictions = correctTopPredictions
        self.incorrectTopPredictions = incorrectTopPredictions
    }

    mutating func recordEvaluated(isCorrect: Bool) {
        evaluatedEvents += 1
        if isCorrect {
            correctTopPredictions += 1
        } else {
            incorrectTopPredictions += 1
        }
    }

    func snapshot() -> RankingEvaluationMetrics {
        RankingEvaluationMetrics(
            totalEvents: totalEvents,
            evaluatedEvents: evaluatedEvents,
            correctTopPredictions: correctTopPredictions,
            incorrectTopPredictions: incorrectTopPredictions
        )
    }
}
