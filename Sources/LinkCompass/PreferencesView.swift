import SwiftUI
import LinkCompassCore

struct PreferencesView: View {
    @StateObject private var viewModel = PreferencesViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("LinkCompass Settings")
                .font(.title2)
                .bold()

            GroupBox("Default routing") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Global default browser", selection: $viewModel.globalDefaultBrowserBundleIdentifier) {
                        Text("No default").tag(Optional<String>.none)
                        ForEach(viewModel.browsers) { browser in
                            Text(browser.displayName).tag(Optional(browser.bundleIdentifier))
                        }
                    }
                    .onChange(of: viewModel.globalDefaultBrowserBundleIdentifier) { newValue in
                        viewModel.setGlobalDefault(newValue)
                    }

                    Toggle("Automatically open links when a domain rule matches", isOn: $viewModel.autoOpenKnownHosts)
                        .onChange(of: viewModel.autoOpenKnownHosts) { newValue in
                            viewModel.setAutoOpenKnownHosts(newValue)
                        }

                    Text("Auto-open only applies to explicit domain rules, not the global default.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            GroupBox("Remembered domains") {
                if viewModel.rules.isEmpty {
                    Text("No domain rules yet. Use the chooser's remember option to add one.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    Table(viewModel.rules) {
                        TableColumn("Domain") { rule in
                            Text(rule.hostPattern)
                        }
                        TableColumn("Browser") { rule in
                            Text(viewModel.browserName(for: rule.browserBundleIdentifier))
                        }
                        TableColumn("Uses") { rule in
                            Text("\(rule.usageCount)")
                        }
                        TableColumn("") { rule in
                            Button("Delete") {
                                viewModel.deleteRule(id: rule.id)
                            }
                        }
                    }
                    .frame(minHeight: 180)
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
                Text("Preferences store domains only, never full URLs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 680, height: 520)
        .onAppear { viewModel.reload() }
    }
}

@MainActor
final class PreferencesViewModel: ObservableObject {
    @Published var browsers: [Browser] = []
    @Published var rules: [BrowserChoiceRule] = []
    @Published var globalDefaultBrowserBundleIdentifier: String?
    @Published var autoOpenKnownHosts = false
    @Published var errorMessage: String?

    private let browserDetector = BrowserDetector()
    private var ruleStore: RuleStore?

    init() {
        reload()
    }

    func reload() {
        do {
            let store = RuleStore(persistence: try JSONPreferencesStore())
            store.reload()
            ruleStore = store
            browsers = browserDetector.installedBrowsers()
            let preferences = store.currentPreferences
            globalDefaultBrowserBundleIdentifier = preferences.globalDefaultBrowserBundleIdentifier
            autoOpenKnownHosts = preferences.autoOpenKnownHosts
            rules = preferences.rules.sorted { $0.hostPattern < $1.hostPattern }
            errorMessage = nil
        } catch {
            errorMessage = "Could not load preferences: \(error.localizedDescription)"
        }
    }

    func setGlobalDefault(_ bundleIdentifier: String?) {
        ruleStore?.globalDefaultBrowserBundleIdentifier = bundleIdentifier
        reload()
    }

    func setAutoOpenKnownHosts(_ enabled: Bool) {
        ruleStore?.autoOpenKnownHosts = enabled
        reload()
    }

    func deleteRule(id: UUID) {
        do {
            try ruleStore?.deleteRule(id: id)
            reload()
        } catch {
            errorMessage = "Could not delete rule: \(error.localizedDescription)"
        }
    }

    func browserName(for bundleIdentifier: String) -> String {
        browsers.first { $0.bundleIdentifier == bundleIdentifier }?.displayName ?? bundleIdentifier
    }
}
