import AppKit
import Foundation
import LinkCompassCore

struct LinkOpener {
    func open(_ url: URL, in browser: Browser, completion: @escaping (Error?) -> Void) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open([url], withApplicationAt: browser.appURL, configuration: configuration) { _, error in
            DispatchQueue.main.async {
                completion(error)
            }
        }
    }
}
