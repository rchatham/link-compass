import AppKit
import CoreServices
import Foundation

@MainActor
final class DefaultBrowserManager: ObservableObject {
    @Published private(set) var httpDefaultBundleIdentifier: String?
    @Published private(set) var httpsDefaultBundleIdentifier: String?
    @Published private(set) var lastErrorMessage: String?

    let linkCompassBundleIdentifier = "com.reidchatham.LinkCompass"

    var isLinkCompassDefaultBrowser: Bool {
        httpDefaultBundleIdentifier == linkCompassBundleIdentifier &&
            httpsDefaultBundleIdentifier == linkCompassBundleIdentifier
    }

    init() {
        refresh()
    }

    func refresh() {
        httpDefaultBundleIdentifier = defaultHandler(forScheme: "http")
        httpsDefaultBundleIdentifier = defaultHandler(forScheme: "https")
    }

    func setLinkCompassAsDefaultBrowser() {
        setDefaultBrowser(bundleIdentifier: linkCompassBundleIdentifier)
    }

    func restoreSafariAsDefaultBrowser() {
        setDefaultBrowser(bundleIdentifier: "com.apple.Safari")
    }

    func setDefaultBrowser(bundleIdentifier: String) {
        lastErrorMessage = nil
        let httpStatus = LSSetDefaultHandlerForURLScheme("http" as CFString, bundleIdentifier as CFString)
        let httpsStatus = LSSetDefaultHandlerForURLScheme("https" as CFString, bundleIdentifier as CFString)
        refresh()

        if httpDefaultBundleIdentifier == bundleIdentifier,
           httpsDefaultBundleIdentifier == bundleIdentifier {
            lastErrorMessage = nil
            return
        }

        guard httpStatus == noErr, httpsStatus == noErr else {
            lastErrorMessage = "macOS returned http status \(httpStatus) and https status \(httpsStatus), and the handlers were not fully updated. You may need to choose a default browser manually in System Settings."
            return
        }
    }

    func openDefaultBrowserSettings() {
        let candidateURLs = [
            "x-apple.systempreferences:com.apple.Desktop-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.general"
        ]

        for string in candidateURLs {
            guard let url = URL(string: string) else { continue }
            if NSWorkspace.shared.open(url) {
                return
            }
        }

        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }

    private func defaultHandler(forScheme scheme: String) -> String? {
        LSCopyDefaultHandlerForURLScheme(scheme as CFString)?.takeRetainedValue() as String?
    }
}
