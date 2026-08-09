import Foundation
import LinkCompassCore

struct LinkCompassEvalCLI {
    let arguments: [String]

    func run() throws {
        if arguments.contains("--help") || arguments.contains("-h") {
            printUsage()
            return
        }

        let eventsPath = try value(after: "--events") ?? defaultEventsPath()
        let minimumChoices = try intValue(after: "--minimum-choices", default: 2)
        let halfLifeDays = try doubleValue(after: "--half-life-days", default: 30)
        guard minimumChoices > 0 else { throw CLIError.invalidValue("--minimum-choices must be greater than 0") }
        guard halfLifeDays > 0 else { throw CLIError.invalidValue("--half-life-days must be greater than 0") }

        let eventsURL = URL(fileURLWithPath: NSString(string: eventsPath).expandingTildeInPath)
        let data = try Data(contentsOf: eventsURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let events = try decoder.decode([ChoiceEvent].self, from: data)

        let baseline = RankingEvaluator.evaluate(
            events: events,
            mode: .baseline,
            minimumChoices: minimumChoices,
            halfLifeDays: halfLifeDays
        )
        let learned = RankingEvaluator.evaluate(
            events: events,
            mode: .learned,
            minimumChoices: minimumChoices,
            halfLifeDays: halfLifeDays
        )

        print("LinkCompass ranking evaluation")
        print("Events: \(eventsURL.path)")
        print("Minimum choices: \(minimumChoices)")
        print("Half-life days: \(formatNumber(halfLifeDays))")
        print("Baseline: empty-preferences first-browser replay; use deltas for model comparison.")
        print("")
        printReport(baseline)
        printReport(learned)
        printDelta(baseline: baseline, learned: learned)
    }

    private func value(after flag: String) throws -> String? {
        guard let index = arguments.firstIndex(of: flag) else { return nil }
        let valueIndex = arguments.index(after: index)
        guard arguments.indices.contains(valueIndex), !arguments[valueIndex].hasPrefix("--") else {
            throw CLIError.invalidValue("Missing value for \(flag)")
        }
        return arguments[valueIndex]
    }

    private func intValue(after flag: String, default defaultValue: Int) throws -> Int {
        guard let rawValue = try value(after: flag) else { return defaultValue }
        guard let value = Int(rawValue) else { throw CLIError.invalidValue("\(flag) must be an integer") }
        return value
    }

    private func doubleValue(after flag: String, default defaultValue: Double) throws -> Double {
        guard let rawValue = try value(after: flag) else { return defaultValue }
        guard let value = Double(rawValue) else { throw CLIError.invalidValue("\(flag) must be a number") }
        return value
    }

    private func defaultEventsPath() throws -> String {
        try JSONEventStore().fileURL.path
    }

    private func printUsage() {
        print("""
        Usage: linkcompass-eval [--events /path/to/choice-events.json] [--minimum-choices 2] [--half-life-days 30]

        If --events is omitted, LinkCompass uses the local app event log:
          ~/Library/Application Support/LinkCompass/choice-events.json
        """)
    }

    private func printReport(_ report: RankingEvaluationReport) {
        let metrics = report.metrics
        print("\(report.mode.rawValue):")
        print("  evaluated: \(metrics.evaluatedEvents)/\(metrics.totalEvents)")
        print("  top-1 accuracy: \(formatPercent(metrics.topOneAccuracy))")
        print("  top-1 error rate: \(formatPercent(metrics.topOneErrorRate))")
        print("  correct: \(metrics.correctTopPredictions)")
        print("  incorrect: \(metrics.incorrectTopPredictions)")
        print("")
    }

    private func printDelta(baseline: RankingEvaluationReport, learned: RankingEvaluationReport) {
        let accuracyDelta = learned.metrics.topOneAccuracy - baseline.metrics.topOneAccuracy
        let errorRateDelta = learned.metrics.topOneErrorRate - baseline.metrics.topOneErrorRate
        print("delta learned vs baseline:")
        print("  top-1 accuracy: \(formatSignedPercent(accuracyDelta))")
        print("  top-1 error rate: \(formatSignedPercent(errorRateDelta))")
    }

    private func formatPercent(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }

    private func formatSignedPercent(_ value: Double) -> String {
        String(format: "%+.1f%%", value * 100)
    }

    private func formatNumber(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

enum CLIError: LocalizedError {
    case invalidValue(String)

    var errorDescription: String? {
        switch self {
        case let .invalidValue(message):
            return message
        }
    }
}

do {
    try LinkCompassEvalCLI(arguments: Array(CommandLine.arguments.dropFirst())).run()
} catch {
    fputs("linkcompass-eval: \(error.localizedDescription)\n", stderr)
    exit(1)
}
