import Foundation
import LinkCompassCore

struct LinkCompassEvalCLI {
    let arguments: [String]

    func run() throws {
        guard let eventsPath = value(after: "--events") else {
            printUsage()
            throw CLIError.missingEventsPath
        }

        let minimumChoices = value(after: "--minimum-choices").flatMap(Int.init) ?? 2
        let eventsURL = URL(fileURLWithPath: eventsPath)
        let data = try Data(contentsOf: eventsURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let events = try decoder.decode([ChoiceEvent].self, from: data)

        let baseline = RankingEvaluator.evaluate(events: events, mode: .baseline, minimumChoices: minimumChoices)
        let learned = RankingEvaluator.evaluate(events: events, mode: .learned, minimumChoices: minimumChoices)

        print("LinkCompass ranking evaluation")
        print("Events: \(eventsURL.path)")
        print("Minimum choices: \(minimumChoices)")
        print("Baseline: empty-preferences first-browser replay; use deltas for model comparison.")
        print("")
        printReport(baseline)
        printReport(learned)
        printDelta(baseline: baseline, learned: learned)
    }

    private func value(after flag: String) -> String? {
        guard let index = arguments.firstIndex(of: flag) else { return nil }
        let valueIndex = arguments.index(after: index)
        guard arguments.indices.contains(valueIndex) else { return nil }
        return arguments[valueIndex]
    }

    private func printUsage() {
        print("Usage: linkcompass-eval --events /path/to/choice-events.json [--minimum-choices 2]")
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
}

enum CLIError: Error {
    case missingEventsPath
}

do {
    try LinkCompassEvalCLI(arguments: Array(CommandLine.arguments.dropFirst())).run()
} catch CLIError.missingEventsPath {
    exit(64)
} catch {
    fputs("linkcompass-eval: \(error.localizedDescription)\n", stderr)
    exit(1)
}
