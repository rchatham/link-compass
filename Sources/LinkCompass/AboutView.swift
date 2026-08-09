import SwiftUI
import LinkCompassCore

private struct EvaluationSummary: Sendable {
    let baselineAccuracy: String
    let learnedAccuracy: String
    let accuracyDelta: String
    let errorDelta: String
}

struct AboutView: View {
    @StateObject private var viewModel = AboutViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("LinkCompass")
                    .font(.largeTitle)
                    .bold()
                Text("Version \(viewModel.versionSummary)")
                    .foregroundStyle(.secondary)
            }

            GroupBox("Diagnostics") {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    diagnosticRow("macOS", viewModel.macOSVersion)
                    diagnosticRow("HTTP default", viewModel.httpDefaultBundleIdentifier ?? "Not set")
                    diagnosticRow("HTTPS default", viewModel.httpsDefaultBundleIdentifier ?? "Not set")
                    diagnosticRow("Learning", viewModel.learningEnabled ? "Enabled" : "Disabled")
                    diagnosticRow("Choice events", "\(viewModel.eventCount)")
                    diagnosticRow("Preferences", viewModel.preferencesPath)
                    diagnosticRow("Events", viewModel.eventsPath)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }

            GroupBox("Ranking evaluation") {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    diagnosticRow("Baseline accuracy", viewModel.baselineAccuracy)
                    diagnosticRow("Learned accuracy", viewModel.learnedAccuracy)
                    diagnosticRow("Accuracy delta", viewModel.accuracyDelta)
                    diagnosticRow("Learned error delta", viewModel.errorDelta)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)

                Text("Evaluation replays local choice events causally. Baseline uses an empty-preferences first-browser replay; use deltas for heuristic/ML decisions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GroupBox("Detected browsers") {
                if viewModel.browsers.isEmpty {
                    Text("No supported browsers detected.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    List(viewModel.browsers) { browser in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(browser.displayName)
                            Text(browser.bundleIdentifier)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(minHeight: 140)
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Refresh") { viewModel.reload() }
                Spacer()
                Text("Diagnostics are local only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 680, height: 680)
        .onAppear { viewModel.reload() }
    }

    private func diagnosticRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
        }
    }
}

@MainActor
final class AboutViewModel: ObservableObject {
    @Published var versionSummary = "Unknown"
    @Published var macOSVersion = "Unknown"
    @Published var httpDefaultBundleIdentifier: String?
    @Published var httpsDefaultBundleIdentifier: String?
    @Published var learningEnabled = false
    @Published var eventCount = 0
    @Published var preferencesPath = "Unknown"
    @Published var eventsPath = "Unknown"
    @Published var baselineAccuracy = "Not enough data"
    @Published var learnedAccuracy = "Not enough data"
    @Published var accuracyDelta = "Not enough data"
    @Published var errorDelta = "Not enough data"
    @Published var browsers: [Browser] = []
    @Published var errorMessage: String?

    private let browserDetector = BrowserDetector()
    private let defaultBrowserManager = DefaultBrowserManager()
    private var evaluationTask: Task<Void, Never>?

    init() {
        reload()
    }

    func reload() {
        versionSummary = Self.bundleVersionSummary()
        macOSVersion = ProcessInfo.processInfo.operatingSystemVersionString
        defaultBrowserManager.refresh()
        httpDefaultBundleIdentifier = defaultBrowserManager.httpDefaultBundleIdentifier
        httpsDefaultBundleIdentifier = defaultBrowserManager.httpsDefaultBundleIdentifier
        browsers = browserDetector.installedBrowsers()

        do {
            let preferencesStore = try JSONPreferencesStore()
            preferencesPath = preferencesStore.fileURL.path
            let preferences = try preferencesStore.load()
            learningEnabled = preferences.learningEnabled

            let eventStore = try JSONEventStore()
            eventsPath = eventStore.fileURL.path
            let events = try eventStore.load()
            eventCount = events.count
            scheduleEvaluationSummary(events: events)
            errorMessage = nil
        } catch {
            errorMessage = "Could not load diagnostics: \(error.localizedDescription)"
        }
    }

    private func scheduleEvaluationSummary(events: [ChoiceEvent]) {
        evaluationTask?.cancel()
        baselineAccuracy = "Calculating…"
        learnedAccuracy = "Calculating…"
        accuracyDelta = "Calculating…"
        errorDelta = "Calculating…"

        evaluationTask = Task { [weak self] in
            let summary = await Task.detached(priority: .utility) {
                Self.evaluationSummary(events: events)
            }.value
            guard !Task.isCancelled else { return }
            self?.baselineAccuracy = summary.baselineAccuracy
            self?.learnedAccuracy = summary.learnedAccuracy
            self?.accuracyDelta = summary.accuracyDelta
            self?.errorDelta = summary.errorDelta
        }
    }

    nonisolated private static func evaluationSummary(events: [ChoiceEvent]) -> EvaluationSummary {
        let baseline = RankingEvaluator.evaluate(events: events, mode: .baseline)
        let learned = RankingEvaluator.evaluate(events: events, mode: .learned)
        guard baseline.metrics.evaluatedEvents > 0 || learned.metrics.evaluatedEvents > 0 else {
            return EvaluationSummary(
                baselineAccuracy: "Not enough data",
                learnedAccuracy: "Not enough data",
                accuracyDelta: "Not enough data",
                errorDelta: "Not enough data"
            )
        }

        return EvaluationSummary(
            baselineAccuracy: formatPercent(baseline.metrics.topOneAccuracy),
            learnedAccuracy: formatPercent(learned.metrics.topOneAccuracy),
            accuracyDelta: formatSignedPercent(learned.metrics.topOneAccuracy - baseline.metrics.topOneAccuracy),
            errorDelta: formatSignedPercent(learned.metrics.topOneErrorRate - baseline.metrics.topOneErrorRate)
        )
    }

    nonisolated private static func formatPercent(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }

    nonisolated private static func formatSignedPercent(_ value: Double) -> String {
        String(format: "%+.1f%%", value * 100)
    }

    private static func bundleVersionSummary() -> String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String
        let build = info["CFBundleVersion"] as? String

        switch (version, build) {
        case let (version?, build?):
            return "\(version) (\(build))"
        case let (version?, nil):
            return version
        case let (nil, build?):
            return build
        case (nil, nil):
            return "Unknown"
        }
    }
}
