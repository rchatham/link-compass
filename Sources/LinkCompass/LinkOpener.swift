import AppKit
import Foundation
import LinkCompassCore

struct LinkOpener {
    func open(_ url: URL, in browser: Browser) throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open([url], withApplicationAt: browser.appURL, configuration: configuration) { _, error in
            if let error {
                NSAlert(error: error).runModal()
            }
        }
    }
}
