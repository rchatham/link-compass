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
    private let pendingRouteStore: PendingRouteStore
    private lazy var shareRouter = ShareRouter(ruleStore: ruleStore)
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

        do {
            self.pendingRouteStore = PendingRouteStore(persistence: try JSONPendingRoutePersistence())
        } catch {
            let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent("LinkCompass-pending-routes.json")
            self.pendingRouteStore = PendingRouteStore(persistence: try! JSONPendingRoutePersistence(fileURL: temporaryURL))
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
        // Custom commands must never fall through to ordinary URL routing.
        if url.scheme?.lowercased() == "linkcompass" {
            do {
                handleShareRequest(try ShareOpenRequest.decode(url))
            } catch {
                showAlert(message: "Invalid share request", informativeText: error.localizedDescription)
            }
            return
        }

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

        let preferences = ruleStore.currentPreferences
        let learnedSuggestionBundleIdentifier = learnedSuggestionBundleIdentifier(
            for: context,
            preferences: preferences,
            installedBrowsers: browsers
        )
        let rankingContext = RankingContext(
            incomingURLContext: context,
            learnedSuggestionBundleIdentifier: learnedSuggestionBundleIdentifier
        )

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
            rankedBrowser.isPreferred && (rankedBrowser.isPreferenceBacked || rankedBrowser.isLearnedSuggestion)
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

    private func handleShareRequest(_ request: ShareOpenRequest, origin: ShareRequestOrigin = .wire) {
        let browsers = browserDetector.installedBrowsers()
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                ruleStore.reload()
                let proposedRoute = try ShareRoutingPolicy.route(request, browsers: browsers, preferences: ruleStore.currentPreferences)
                var consent = ShareRememberConsent.openOnce
                if ShareConsentPolicy.requiresConfirmation(request, origin: origin),
                   case .browser(let browser, _) = proposedRoute {
                    consent = confirmShareRemember(request, browser: browser)
                }
                guard let approved = try ShareConsentPolicy.approve(request, origin: origin, consent: consent) else { return }
                let route = try await shareRouter.open(approved, browsers: browsers) { url, browser in
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        self.linkOpener.open(url, in: browser) { error in
                            if let error {
                                continuation.resume(throwing: error)
                            } else {
                                continuation.resume()
                            }
                        }
                    }
                }
                switch route {
                case .browser:
                    closeLinkCompassWindows()
                case .picker:
                    showSharePicker(for: request, browsers: browsers)
                }
            } catch {
                showAlert(message: "Could not complete share request", informativeText: error.localizedDescription)
            }
        }
    }

    private func confirmShareRemember(_ request: ShareOpenRequest, browser: Browser) -> ShareRememberConsent {
        guard let host = URLNormalizer.normalizedHost(from: request.url) else { return .cancel }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Always open \(host) in \(browser.displayName)?"
        alert.informativeText = "This request came from outside LinkCompass. Remember only if you want to change this site's saved browser."
        alert.addButton(withTitle: "Open once").keyEquivalent = "\r"
        alert.addButton(withTitle: "Open & remember")
        alert.addButton(withTitle: "Cancel").keyEquivalent = "\u{1b}"
        switch alert.runModal() {
        case .alertFirstButtonReturn: return .openOnce
        case .alertSecondButtonReturn: return .openAndRemember
        default: return .cancel
        }
    }

    private func showSharePicker(for request: ShareOpenRequest, browsers: [Browser]) {
        guard !browsers.isEmpty else {
            showAlert(message: "No supported browsers found", informativeText: "Install a supported browser to open this shared link.")
            return
        }
        guard let context = IncomingURLContext(url: request.url) else {
            showAlert(message: "Invalid share request", informativeText: "The shared link has no valid web host.")
            return
        }
        chooserWindowController.show(
            url: request.url,
            displayTitle: context.displayTitle,
            rememberLabel: context.rememberHost,
            browsers: browsers,
            initialSelection: nil,
            onChoose: { [weak self] browser, remember in
                do {
                    let choice = try ShareOpenRequest(
                        url: request.url,
                        selection: .browser(bundleIdentifier: browser.bundleIdentifier, remember: remember)
                    )
                    self?.handleShareRequest(choice, origin: .localPicker)
                } catch {
                    self?.showAlert(message: "Invalid share request", informativeText: error.localizedDescription)
                }
            },
            onCancel: {}
        )
    }

    private func learnedSuggestionBundleIdentifier(
        for context: IncomingURLContext,
        preferences: LinkCompassPreferences,
        installedBrowsers: [Browser]
    ) -> String? {
        guard preferences.learningEnabled,
              let host = context.rememberHost,
              let events = try? eventStore.events(),
              let suggestion = ChoiceInsights.suggestion(forHost: host, events: events),
              installedBrowsers.contains(where: { $0.bundleIdentifier == suggestion.bundleIdentifier }) else {
            return nil
        }
        return suggestion.bundleIdentifier
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

            self?.recordPendingRoute(url: url, browser: browser)
            self?.closeLinkCompassWindows()
        }
    }

    private func recordPendingRoute(url: URL, browser: Browser) {
        do {
            try pendingRouteStore.recordRoute(
                url: url,
                browserBundleIdentifier: browser.bundleIdentifier,
                browserDisplayName: browser.displayName
            )
        } catch {
            showAlert(message: "Could not save pending route", informativeText: error.localizedDescription)
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
