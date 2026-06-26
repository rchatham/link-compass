import AppKit
import Foundation
import LinkCompassCore

@MainActor
struct BrowserWindowOpener {
    func openBlankWindow(in browser: Browser) {
        if runAppleScript(command: "make new document", bundleIdentifier: browser.bundleIdentifier) {
            return
        }

        if runAppleScript(command: "make new window", bundleIdentifier: browser.bundleIdentifier) {
            return
        }

        openAboutBlank(in: browser)
    }

    private func runAppleScript(command: String, bundleIdentifier: String) -> Bool {
        let source = """
        tell application id "\(bundleIdentifier)"
            activate
            \(command)
        end tell
        """

        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        return result != nil && error == nil
    }

    private func openAboutBlank(in browser: Browser) {
        guard let url = URL(string: "about:blank") else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open([url], withApplicationAt: browser.appURL, configuration: configuration)
    }
}
