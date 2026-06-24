import SwiftUI
import LinkCompassCore

struct OnboardingView: View {
    @StateObject private var defaultBrowserManager = DefaultBrowserManager()
    @State private var browsers: [Browser] = BrowserDetector().installedBrowsers()

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            defaultBrowserCard
            browserDetectionCard
            privacyCard
            footer
        }
        .padding(28)
        .frame(width: 720, height: 620)
        .onAppear {
            defaultBrowserManager.refresh()
            browsers = BrowserDetector().installedBrowsers()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "safari")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome to LinkCompass")
                    .font(.largeTitle)
                    .bold()
                Text("LinkCompass sits between apps and your browsers. When a link opens, it asks which browser should handle it and can remember your domain choices.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var defaultBrowserCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: defaultBrowserManager.isLinkCompassDefaultBrowser ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(defaultBrowserManager.isLinkCompassDefaultBrowser ? .green : .orange)
                    Text(defaultBrowserManager.isLinkCompassDefaultBrowser ? "LinkCompass is your default browser" : "Set LinkCompass as your default browser")
                        .font(.headline)
                }

                Text("Current handlers: http = \(defaultBrowserManager.httpDefaultBundleIdentifier ?? "unknown"), https = \(defaultBrowserManager.httpsDefaultBundleIdentifier ?? "unknown")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                if let lastErrorMessage = defaultBrowserManager.lastErrorMessage {
                    Text(lastErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Button("Set Automatically") {
                        defaultBrowserManager.setLinkCompassAsDefaultBrowser()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Open Default Browser Settings") {
                        defaultBrowserManager.openDefaultBrowserSettings()
                    }

                    Button("Refresh Status") {
                        defaultBrowserManager.refresh()
                    }

                    Button("Restore Safari") {
                        defaultBrowserManager.restoreSafariAsDefaultBrowser()
                    }
                }

                Text("If you get stuck while testing, click Restore Safari to put normal browser behavior back. If LinkCompass does not appear in System Settings, use Set Automatically. Local development builds may be hidden by System Settings because they are ad-hoc signed, even though macOS can still use them as URL handlers.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
        } label: {
            Text("Step 1")
        }
    }

    private var browserDetectionCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text("Detected browsers")
                    .font(.headline)

                if browsers.isEmpty {
                    Text("No supported browsers were detected. Install Safari, Chrome, Chromium, Brave, Firefox, DuckDuckGo Browser, or Edge.")
                        .foregroundStyle(.secondary)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), alignment: .leading)], alignment: .leading, spacing: 8) {
                        ForEach(browsers) { browser in
                            HStack(spacing: 8) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: browser.appURL.path))
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                Text(browser.displayName)
                                    .lineLimit(1)
                            }
                        }
                    }
                }

                Button("Refresh Browsers") {
                    browsers = BrowserDetector().installedBrowsers()
                }
            }
            .padding(.vertical, 4)
        } label: {
            Text("Step 2")
        }
    }

    private var privacyCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("Privacy-first by default")
                    .font(.headline)
                Text("LinkCompass stores browser preferences by normalized domain only. It does not store full URLs, paths, query strings, or tokens.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
        } label: {
            Text("Step 3")
        }
    }

    private var footer: some View {
        HStack {
            Text("Once setup is complete, open any web link from another app to show the chooser.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Open Settings") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        }
    }
}
