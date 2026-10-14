// Concatenated with the production controller by scripts/test-share-layout.sh.
// A detector fixture keeps these offscreen checks independent of installed apps.
struct BrowserDetector {
    static var count = 4
    func installedBrowsers() -> [Browser] {
        (0..<Self.count).map {
            Browser(displayName: "Browser \($0 + 1)", bundleIdentifier: "test.browser.\($0)", appURL: URL(fileURLWithPath: "/tmp/synthetic-browser.app"))
        }
    }
}

extension ShareViewController {
    func probe(_ name: String, ready: Bool, error: String = "", submitting: Bool = false) {
        let originalSize = preferredContentSize
        let originalFrame = view.frame
        if ready {
            webURL = URL(string: "https://example.com/long-shared-link")!
            linkLabel.stringValue = webURL!.absoluteString
            rebuildBrowserButtons()
            phase = submitting ? .submitting : .ready
        } else {
            webURL = nil
            phase = error.isEmpty ? .loading : .loadFailed
        }
        errorLabel.stringValue = error
        updateControls()
        precondition(preferredContentSize == originalSize && view.frame == originalFrame, "presentation size changed")
        let document = contentScrollView.documentView!
        let stack = contentStack!
        precondition(document.isFlipped, "document must start at top")
        precondition(abs(document.frame.width - contentScrollView.contentView.bounds.width) < 0.01, "wrong document width")
        precondition(abs(stack.frame.minY - 20) < 0.01 && abs(document.frame.height - stack.frame.maxY - 20) < 0.01, "wrong document padding")
        validate(stack)
        print("PASS \(name) root=\(view.frame.size) document=\(document.frame.size)")
        if document.frame.height > contentScrollView.contentView.bounds.height {
            let clip = contentScrollView.contentView
            let bottom = document.frame.height - clip.bounds.height
            clip.scroll(to: NSPoint(x: 0, y: bottom))
            contentScrollView.reflectScrolledClipView(clip)
            view.layoutSubtreeIfNeeded()
            precondition(clip.bounds.minY > 0, "overflow cannot scroll")
            precondition(document.frame.minY == 0, "document moved during scrolling")
            print("PASS overflow scroll y=\(clip.bounds.minY)")
            clip.scroll(to: .zero)
            contentScrollView.reflectScrolledClipView(clip)
        } else {
            precondition(contentScrollView.contentView.bounds.minY == 0, "short document not at top")
        }
    }

    private func validate(_ stack: NSStackView) {
        var previous: NSRect?
        for item in stack.arrangedSubviews where !item.isHidden {
            let rect = item.alignmentRect(forFrame: item.frame)
            if stack.orientation == .vertical, let previous {
                precondition(rect.maxY <= previous.minY + 0.01, "overlap")
            }
            if let label = item as? NSTextField {
                precondition(label.frame.height + 0.01 >= label.cell!.cellSize(forBounds: label.bounds).height, "clipped label")
            }
            if let nested = item as? NSStackView { validate(nested) }
            previous = rect
        }
        if stack === browserStack {
            for button in browserButtons {
                precondition(abs(button.alignmentRect(forFrame: button.frame).height - 36) < 0.01, "compressed browser")
            }
        }
    }
}

@main struct ShareLayoutProbe {
    @MainActor static func main() {
        _ = NSApplication.shared
        for count in [0, 4, 9, 15] {
            BrowserDetector.count = count
            let controller = ShareViewController()
            _ = controller.view
            precondition(controller.preferredContentSize == NSSize(width: 500, height: min(680, max(260, 260 + 42 * CGFloat(count)))))
            controller.probe("\(count)-loading", ready: false)
            controller.probe("\(count)-ready", ready: true)
            controller.probe("\(count)-submitting", ready: true, submitting: true)
            controller.probe("\(count)-long-error", ready: true, error: String(repeating: "Unable to hand off the shared link. ", count: 40))
            controller.probe("\(count)-load-error", ready: false, error: "The containing LinkCompass app could not be verified. Reinstall the complete app bundle.")
            controller.probe("\(count)-ready-again", ready: true)
        }
    }
}
