import AppKit
import SwiftUI
import LinkCompassCore

@MainActor
final class ChooserWindowController {
    private var window: NSWindow?

    func show(
        url: URL,
        host: String,
        browsers: [Browser],
        initialSelection: String?,
        onChoose: @escaping (Browser, Bool) -> Void,
        onCancel: @escaping () -> Void
    ) {
        close()

        let rootView = ChooserView(
            url: url,
            host: host,
            browsers: browsers,
            initialSelection: initialSelection,
            onChoose: { [weak self] browser, remember in
                self?.close()
                onChoose(browser, remember)
            },
            onCancel: { [weak self] in
                self?.close()
                onCancel()
            }
        )

        let hostingView = NSHostingView(rootView: rootView)
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 340),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "LinkCompass"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace, .transient]
        panel.contentView = hostingView
        panel.center()

        window = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    func close() {
        window?.close()
        window = nil
    }
}

private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
