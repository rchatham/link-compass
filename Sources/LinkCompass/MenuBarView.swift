import AppKit
import SwiftUI

struct MenuBarView: View {
    private let browserDetector = BrowserDetector()
    private let browserWindowOpener = BrowserWindowOpener()

    var body: some View {
        Button("Open LinkCompass…") {
            NotificationCenter.default.post(name: .linkCompassOpenOnboarding, object: nil)
        }

        Button("About LinkCompass…") {
            NotificationCenter.default.post(name: .linkCompassOpenAbout, object: nil)
        }

        Menu("Open Blank Window") {
            let browsers = browserDetector.installedBrowsers()
            if browsers.isEmpty {
                Text("No supported browsers found")
            } else {
                ForEach(browsers, id: \.bundleIdentifier) { browser in
                    Button(browser.displayName) {
                        browserWindowOpener.openBlankWindow(in: browser)
                    }
                }
            }
        }

        Divider()

        Button("Quit LinkCompass") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

extension Notification.Name {
    static let linkCompassOpenOnboarding = Notification.Name("LinkCompassOpenOnboarding")
    static let linkCompassOpenAbout = Notification.Name("LinkCompassOpenAbout")
}
