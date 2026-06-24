import AppKit
import Foundation
import LinkCompassCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let browserDetector = BrowserDetector()
    private let chooserWindowController = ChooserWindowController()
    private let linkOpener = LinkOpener()
    private let ruleStore: RuleStore
    private var statusItemController: StatusItemController?

    override init() {
        do {
            self.ruleStore = RuleStore(persistence: try JSONPreferencesStore())
        } catch {
            let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent("LinkCompass-preferences.json")
            self.ruleStore = RuleStore(persistence: try! JSONPreferencesStore(fileURL: temporaryURL))
        }
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        statusItemController = StatusItemController()
        NSApp.activate(ignoringOtherApps: true)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach { handleIncomingURL($0) }
    }

    private func handleIncomingURL(_ url: URL) {
        guard let context = IncomingURLContext(url: url) else {
            showAlert(message: "Unsupported URL", informativeText: url.absoluteString)
            return
        }

        ruleStore.reload()

        let browsers = browserDetector.installedBrowsers()
        guard !browsers.isEmpty else {
            showAlert(message: "No supported browsers found", informativeText: "Install Safari, Chrome, Firefox, Brave, DuckDuckGo, Chromium, or Edge to use LinkCompass.")
            return
        }

        if context.supportsDomainRules,
           ruleStore.autoOpenKnownHosts,
           let rememberHost = context.rememberHost,
           let domainRuleBundleIdentifier = ruleStore.domainRuleBrowserBundleIdentifier(forHost: rememberHost),
           let browser = browsers.first(where: { $0.bundleIdentifier == domainRuleBundleIdentifier }) {
            open(url: url, in: browser)
            return
        }

        let preferredBundleIdentifier = context.rememberHost.flatMap { ruleStore.preferredBrowserBundleIdentifier(forHost: $0) }
        let initialSelection = preferredBundleIdentifier ?? ruleStore.globalDefaultBrowserBundleIdentifier ?? browsers.first?.bundleIdentifier

        chooserWindowController.show(
            url: url,
            displayTitle: context.displayTitle,
            rememberLabel: context.rememberHost,
            browsers: browsers,
            initialSelection: initialSelection,
            onChoose: { [weak self] browser, remember in
                self?.handleChoice(url: url, rememberHost: context.rememberHost, browser: browser, remember: remember)
            },
            onCancel: {}
        )
    }

    private func handleChoice(url: URL, rememberHost: String?, browser: Browser, remember: Bool) {
        if ruleStore.globalDefaultBrowserBundleIdentifier == nil {
            ruleStore.globalDefaultBrowserBundleIdentifier = browser.bundleIdentifier
        }

        if remember, let rememberHost {
            do {
                try ruleStore.recordChoice(host: rememberHost, browserBundleIdentifier: browser.bundleIdentifier)
            } catch {
                showAlert(message: "Could not save browser preference", informativeText: error.localizedDescription)
            }
        }

        open(url: url, in: browser)
    }

    private func open(url: URL, in browser: Browser) {
        do {
            try linkOpener.open(url, in: browser)
        } catch {
            showAlert(message: "Could not open link", informativeText: error.localizedDescription)
        }
    }

    private func showAlert(message: String, informativeText: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = informativeText
        alert.runModal()
    }
}
