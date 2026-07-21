import SwiftUI
import LinkCompassCore

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
        .frame(width: 640, height: 560)
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
    @Published var browsers: [Browser] = []
    @Published var errorMessage: String?

    private let browserDetector = BrowserDetector()
    private let defaultBrowserManager = DefaultBrowserManager()

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
            eventCount = try eventStore.load().count
            errorMessage = nil
        } catch {
            errorMessage = "Could not load diagnostics: \(error.localizedDescription)"
        }
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
