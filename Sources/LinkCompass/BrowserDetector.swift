import AppKit
import Foundation
import LinkCompassCore

struct BrowserDetector {
    func installedBrowsers() -> [Browser] {
        let currentBundleIdentifier = Bundle.main.bundleIdentifier
        let browsers = KnownBrowser.allCases.compactMap { knownBrowser -> Browser? in
            guard knownBrowser.rawValue != currentBundleIdentifier else { return nil }
            guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: knownBrowser.rawValue) else {
                return nil
            }

            let displayName = FileManager.default.displayName(atPath: appURL.path)
                .replacingOccurrences(of: ".app", with: "")

            return Browser(
                displayName: displayName.isEmpty ? knownBrowser.displayName : displayName,
                bundleIdentifier: knownBrowser.rawValue,
                appURL: appURL
            )
        }

        return browsers.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
}
