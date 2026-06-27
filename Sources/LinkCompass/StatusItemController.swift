import AppKit
import LinkCompassCore

@MainActor
final class StatusItemController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let browserDetector = BrowserDetector()
    private let browserWindowOpener = BrowserWindowOpener()
    private let onOpenOnboarding: () -> Void

    init(onOpenOnboarding: @escaping () -> Void) {
        self.onOpenOnboarding = onOpenOnboarding
        configure()
    }

    private func configure() {
        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "location.north.circle.fill", accessibilityDescription: "LinkCompass") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "LC"
            }
            button.toolTip = "LinkCompass"
        }

        let menu = NSMenu()
        menu.addItem(makeOpenBlankWindowItem())
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Open LinkCompass…", action: #selector(openOnboarding), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Open LinkCompass Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit LinkCompass", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    private func makeOpenBlankWindowItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Open Blank Window", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        let browsers = browserDetector.installedBrowsers()

        if browsers.isEmpty {
            let emptyItem = NSMenuItem(title: "No supported browsers found", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            submenu.addItem(emptyItem)
        } else {
            for browser in browsers {
                let browserItem = NSMenuItem(title: browser.displayName, action: #selector(openBlankWindow(_:)), keyEquivalent: "")
                browserItem.target = self
                browserItem.representedObject = browser
                submenu.addItem(browserItem)
            }
        }

        item.submenu = submenu
        return item
    }

    @objc private func openBlankWindow(_ sender: NSMenuItem) {
        guard let browser = sender.representedObject as? Browser else { return }
        browserWindowOpener.openBlankWindow(in: browser)
    }

    @objc private func openOnboarding() {
        onOpenOnboarding()
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
