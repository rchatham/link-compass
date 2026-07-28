import Foundation

public struct BrowserScore: Equatable, Sendable {
    public let bundleIdentifier: String
    public let score: Double
    public let choiceCount: Int

    public init(bundleIdentifier: String, score: Double, choiceCount: Int) {
        self.bundleIdentifier = bundleIdentifier
        self.score = score
        self.choiceCount = choiceCount
    }
}

public struct HostSuggestion: Equatable, Sendable {
    public let normalizedHost: String
    public let bundleIdentifier: String
    public let score: Double
    public let choiceCount: Int

    public init(normalizedHost: String, bundleIdentifier: String, score: Double, choiceCount: Int) {
        self.normalizedHost = normalizedHost
        self.bundleIdentifier = bundleIdentifier
        self.score = score
        self.choiceCount = choiceCount
    }
}

public enum ChoiceInsights {
    public static func scores(
        forHost host: String,
        events: [ChoiceEvent],
        now: Date = Date(),
        halfLifeDays: Double = 30
    ) -> [BrowserScore] {
        guard halfLifeDays > 0 else { return [] }
        let normalizedHost = normalizeHost(host)
        var scoresByBundleIdentifier: [String: Double] = [:]
        var countsByBundleIdentifier: [String: Int] = [:]

        for event in events where event.normalizedHost.map(normalizeHost) == normalizedHost && !event.isFileURL {
            let ageSeconds = max(0, now.timeIntervalSince(event.createdAt))
            let ageDays = ageSeconds / 86_400
            let weight = pow(0.5, ageDays / halfLifeDays)
            scoresByBundleIdentifier[event.chosenBrowserBundleIdentifier, default: 0] += weight
            countsByBundleIdentifier[event.chosenBrowserBundleIdentifier, default: 0] += 1
        }

        return scoresByBundleIdentifier.map { bundleIdentifier, score in
            BrowserScore(
                bundleIdentifier: bundleIdentifier,
                score: score,
                choiceCount: countsByBundleIdentifier[bundleIdentifier, default: 0]
            )
        }
        .sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if lhs.choiceCount != rhs.choiceCount { return lhs.choiceCount > rhs.choiceCount }
            return lhs.bundleIdentifier < rhs.bundleIdentifier
        }
    }

    public static func suggestion(
        forHost host: String,
        events: [ChoiceEvent],
        now: Date = Date(),
        halfLifeDays: Double = 30,
        minimumChoices: Int = 2
    ) -> HostSuggestion? {
        let normalizedHost = normalizeHost(host)
        let hostEvents = events.filter { event in
            event.normalizedHost.map(normalizeHost) == normalizedHost && !event.isFileURL
        }
        guard let topScore = scores(forHost: normalizedHost, events: hostEvents, now: now, halfLifeDays: halfLifeDays).first,
              topScore.choiceCount >= minimumChoices else {
            return nil
        }

        return HostSuggestion(
            normalizedHost: normalizedHost,
            bundleIdentifier: topScore.bundleIdentifier,
            score: topScore.score,
            choiceCount: topScore.choiceCount
        )
    }

    private static func normalizeHost(_ host: String) -> String {
        var normalized = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.hasSuffix(".") {
            normalized.removeLast()
        }
        if normalized.hasPrefix("www.") {
            normalized.removeFirst(4)
        }
        return normalized
    }
}
