import AppKit
import SwiftUI

@MainActor
final class AboutWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func show() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hostingView = NSHostingView(rootView: AboutView())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "About LinkCompass"
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.delegate = self
        window.center()
        window.setFrameAutosaveName("LinkCompassAbout")
        window.makeKeyAndOrderFront(nil)

        self.window = window
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        guard let window else { return }
        window.orderOut(nil)
        self.window = nil
    }

    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === window else { return }
        window = nil
    }
}
