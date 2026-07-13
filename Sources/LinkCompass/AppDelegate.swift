import AppKit
import Foundation
import LinkCompassCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let browserDetector = BrowserDetector()
    private let chooserWindowController = ChooserWindowController()
    private let onboardingWindowController = OnboardingWindowController()
    private let linkOpener = LinkOpener()
    private let ruleStore: RuleStore
    private var fallbackStatusItem: NSStatusItem?
    private var openOnboardingObserver: NSObjectProtocol?
    private var pendingOnboardingLaunch: DispatchWorkItem?
    private var hasHandledIncomingURL = false

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
        ProcessInfo.processInfo.disableAutomaticTermination("LinkCompass keeps a menu bar item available for browser routing.")
        configureFallbackStatusItem()
        openOnboardingObserver = NotificationCenter.default.addObserver(
            forName: .linkCompassOpenOnboarding,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.showOnboarding()
            }
        }
        scheduleOnboardingForNormalLaunch()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let openOnboardingObserver {
            NotificationCenter.default.removeObserver(openOnboardingObserver)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func configureFallbackStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.isVisible = true

        if let button = statusItem.button {
            button.title = ""
            button.image = NSImage(systemSymbolName: "safari", accessibilityDescription: "LinkCompass")
            button.image?.isTemplate = true
            button.toolTip = "LinkCompass"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open LinkCompass…", action: #selector(openOnboardingFromMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit LinkCompass", action: #selector(quitFromMenu), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu

        fallbackStatusItem = statusItem
    }

    @objc private func openOnboardingFromMenu() {
        showOnboarding()
    }

    @objc private func quitFromMenu() {
        NSApp.terminate(nil)
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
