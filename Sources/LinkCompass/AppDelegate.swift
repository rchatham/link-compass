import AppKit
import Foundation
import LinkCompassCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let browserDetector = BrowserDetector()
    private let chooserWindowController = ChooserWindowController()
    private let onboardingWindowController = OnboardingWindowController()
    private let aboutWindowController = AboutWindowController()
    private let linkOpener = LinkOpener()
    private let ruleStore: RuleStore
    private let eventStore: EventStore
    private let ranker = RuleBasedRanker()
    private var openOnboardingObserver: NSObjectProtocol?
    private var openAboutObserver: NSObjectProtocol?
    private var pendingOnboardingLaunch: DispatchWorkItem?
    private var hasHandledIncomingURL = false

    override init() {
        do {
            self.ruleStore = RuleStore(persistence: try JSONPreferencesStore())
        } catch {
            let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent("LinkCompass-preferences.json")
            self.ruleStore = RuleStore(persistence: try! JSONPreferencesStore(fileURL: temporaryURL))
        }

        do {
            self.eventStore = EventStore(persistence: try JSONEventStore())
        } catch {
            let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent("LinkCompass-choice-events.json")
            self.eventStore = EventStore(persistence: try! JSONEventStore(fileURL: temporaryURL))
        }
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.disableAutomaticTermination("LinkCompass keeps a menu bar item available for browser routing.")
        openOnboardingObserver = NotificationCenter.default.addObserver(
            forName: .linkCompassOpenOnboarding,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.showOnboarding()
            }
        }
        openAboutObserver = NotificationCenter.default.addObserver(
            forName: .linkCompassOpenAbout,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.showAbout()
            }
        }
        scheduleOnboardingForNormalLaunch()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let openOnboardingObserver {
            NotificationCenter.default.removeObserver(openOnboardingObserver)
        }
        if let openAboutObserver {
            NotificationCenter.default.removeObserver(openAboutObserver)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showOnboarding()
        }
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        hasHandledIncomingURL = true
        pendingOnboardingLaunch?.cancel()
        onboardingWindowController.close()
        urls.forEach { handleIncomingURL($0) }
    }

    private func scheduleOnboardingForNormalLaunch() {
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, !self.hasHandledIncomingURL else { return }
            self.showOnboarding()
        }
        pendingOnboardingLaunch = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: workItem)
    }

    private func showOnboarding() {
        onboardingWindowController.show()
    }

    private func showAbout() {
        aboutWindowController.show()
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

        let rankingContext = RankingContext(incomingURLContext: context)
        let preferences = ruleStore.currentPreferences

        if let browser = ranker.autoOpenBrowser(
            browsers: browsers,
            context: rankingContext,
            preferences: preferences
        ) {
            open(url: url, in: browser)
            return
        }

        let rankedBrowsers = ranker.rankedBrowsers(
            browsers: browsers,
            context: rankingContext,
            preferences: preferences
        )
        let initialSelection = rankedBrowsers.first(where: \.isPreferred)?.browser.bundleIdentifier
        let preselectedBundleIdentifier = rankedBrowsers.first { rankedBrowser in
            rankedBrowser.isPreferred && rankedBrowser.isPreferenceBacked
        }?.browser.bundleIdentifier

        chooserWindowController.show(
            url: url,
            displayTitle: context.displayTitle,
            rememberLabel: context.rememberHost,
            browsers: browsers,
            initialSelection: initialSelection,
            onChoose: { [weak self] browser, remember in
                self?.handleChoice(
                    url: url,
                    rememberHost: context.rememberHost,
                    browser: browser,
                    remember: remember,
                    preselectedBundleIdentifier: preselectedBundleIdentifier
                )
            },
            onCancel: {}
        )
    }

    private func handleChoice(
        url: URL,
        rememberHost: String?,
        browser: Browser,
        remember: Bool,
        preselectedBundleIdentifier: String?
    ) {
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

        logChoiceIfEnabled(
            url: url,
            chosenBrowserBundleIdentifier: browser.bundleIdentifier,
            preselectedBrowserBundleIdentifier: preselectedBundleIdentifier
        )

        open(url: url, in: browser)
    }

    private func logChoiceIfEnabled(
        url: URL,
        chosenBrowserBundleIdentifier: String,
        preselectedBrowserBundleIdentifier: String?
    ) {
        ruleStore.reload()
        guard ruleStore.currentPreferences.learningEnabled else { return }

        let event = ChoiceEvent(
            url: url,
            chosenBrowserBundleIdentifier: chosenBrowserBundleIdentifier,
            preselectedBrowserBundleIdentifier: preselectedBrowserBundleIdentifier
        )

        do {
            try eventStore.append(event)
        } catch {
            showAlert(message: "Could not save learning event", informativeText: error.localizedDescription)
        }
    }

    private func open(url: URL, in browser: Browser) {
        linkOpener.open(url, in: browser) { [weak self] error in
            if let error {
                self?.showAlert(message: "Could not open link", informativeText: error.localizedDescription)
                return
            }

            self?.closeLinkCompassWindows()
        }
    }

    private func closeLinkCompassWindows() {
        chooserWindowController.close()
        onboardingWindowController.close()
        aboutWindowController.close()
        NSApp.windows.forEach { window in
            window.orderOut(nil)
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
