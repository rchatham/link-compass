import AppKit
import LinkCompassCore

@objc(ShareViewController)
final class ShareViewController: NSViewController {
    private enum Phase {
        case initial, loading, loadFailed, ready, submitting, finished
    }

    private var phase: Phase = .initial
    private var generation = UUID()
    private var webURL: URL?
    private var browsers: [Browser] = []
    private var selectedIndex = 0
    private var retrySelection: ShareOpenRequest.Selection?
    private var keyMonitor: Any?
    private var contentStack: NSStackView?
    private let contentScrollView = NSScrollView()

    private let heading = NSTextField(labelWithString: "Open link with…")
    private let linkLabel = NSTextField(wrappingLabelWithString: "")
    private let statusLabel = NSTextField(wrappingLabelWithString: "Loading shared link…")
    private let errorLabel = NSTextField(wrappingLabelWithString: "")
    private let browserStack = NSStackView()
    private var browserButtons: [NSButton] = []
    private let rememberButton = NSButton(checkboxWithTitle: "Remember this choice for this host", target: nil, action: nil)
    private let savedButton = NSButton(title: "Use saved choice", target: nil, action: nil)
    private let retryButton = NSButton(title: "Retry", target: nil, action: nil)
    private let cancelButton = NSButton(title: "Cancel", target: nil, action: nil)
    private let spinner = NSProgressIndicator()

    override func loadView() {
        browsers = BrowserDetector().installedBrowsers()
        // ShareKit may retain the size supplied before presentation. Keep it stable
        // across provider/handoff callbacks; overflow belongs in the scroll view.
        let size = NSSize(width: 500, height: min(680, max(260, 260 + 42 * CGFloat(browsers.count))))
        view = ShareRootView(frame: NSRect(origin: .zero, size: size))
        preferredContentSize = size
        heading.font = .boldSystemFont(ofSize: 17)
        linkLabel.font = .systemFont(ofSize: 12)
        linkLabel.textColor = .secondaryLabelColor
        linkLabel.maximumNumberOfLines = 2
        linkLabel.lineBreakMode = .byTruncatingMiddle
        errorLabel.textColor = .systemRed
        errorLabel.font = .systemFont(ofSize: 12)
        browserStack.orientation = .vertical
        browserStack.alignment = .leading
        browserStack.spacing = 6
        rememberButton.state = .off
        rememberButton.font = .systemFont(ofSize: 12)
        savedButton.target = self
        savedButton.action = #selector(useSavedChoice)
        savedButton.bezelStyle = .rounded
        savedButton.toolTip = "Use a remembered host rule, then the global default, otherwise the app's picker."
        retryButton.target = self
        retryButton.action = #selector(retry)
        retryButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancel)
        cancelButton.bezelStyle = .rounded
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false
        let statusRow = NSStackView(views: [spinner, statusLabel])
        statusRow.orientation = .horizontal
        statusRow.spacing = 8
        let actions = NSStackView(views: [savedButton, retryButton, cancelButton])
        actions.orientation = .horizontal
        actions.spacing = 8
        let help = NSTextField(wrappingLabelWithString: "Click a browser to open • 1–9 opens • ↑/↓ selects • Enter opens • Esc cancels")
        help.font = .systemFont(ofSize: 11)
        help.textColor = .secondaryLabelColor
        let privacy = NSTextField(wrappingLabelWithString: "Remember is off by default. Saving a host choice requires confirmation in LinkCompass.")
        privacy.font = .systemFont(ofSize: 11)
        privacy.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [heading, linkLabel, statusRow, errorLabel, browserStack, rememberButton, actions, help, privacy])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentStack = stack
        contentScrollView.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.drawsBackground = false
        contentScrollView.contentView.drawsBackground = false
        contentScrollView.borderType = .noBorder
        contentScrollView.hasVerticalScroller = true
        contentScrollView.hasHorizontalScroller = false
        contentScrollView.autohidesScrollers = true
        let document = ShareDocumentView()
        document.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.documentView = document
        document.addSubview(stack)
        view.addSubview(contentScrollView)
        let clip = contentScrollView.contentView
        NSLayoutConstraint.activate([
            contentScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentScrollView.topAnchor.constraint(equalTo: view.topAnchor),
            contentScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            document.leadingAnchor.constraint(equalTo: clip.leadingAnchor),
            document.topAnchor.constraint(equalTo: clip.topAnchor),
            document.widthAnchor.constraint(equalTo: clip.widthAnchor),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 20),
            // The stack determines document height, never the viewport's height.
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -20),
            browserStack.widthAnchor.constraint(equalTo: stack.widthAnchor),
            statusRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            linkLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            errorLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            help.widthAnchor.constraint(equalTo: stack.widthAnchor),
            privacy.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        updateControls()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if keyMonitor == nil {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                return self.handleKeyDown(event) ? nil : event
            }
        }
        if phase == .initial {
            loadSharedLink()
        }
        view.window?.makeFirstResponder(view)
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        // Ignore item-provider and workspace callbacks after the host dismisses us.
        generation = UUID()
        phase = .finished
        removeKeyMonitor()
    }

    deinit {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
    }

    private func loadSharedLink() {
        guard phase == .initial || phase == .loadFailed else { return }
        phase = .loading
        webURL = nil
        retrySelection = nil
        errorLabel.stringValue = ""
        let token = UUID()
        generation = token
        updateControls()
        ShareInputLoader.load(from: extensionContext) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.generation == token, self.phase == .loading else { return }
                switch result {
                case .success(let url):
                    self.webURL = url
                    self.linkLabel.stringValue = url.absoluteString
                    self.rememberButton.title = "Remember this choice for \(url.host ?? "this host")"
                    self.rememberButton.state = .off
                    self.selectedIndex = 0
                    self.rebuildBrowserButtons()
                    self.phase = .ready
                case .failure(let error):
                    self.phase = .loadFailed
                    self.errorLabel.stringValue = error.localizedDescription
                }
                self.updateControls()
            }
        }
    }

    private func rebuildBrowserButtons() {
        for button in browserButtons {
            browserStack.removeArrangedSubview(button)
            button.removeFromSuperview()
        }
        browserButtons = browsers.enumerated().map { index, browser in
            let button = NSButton(title: browser.displayName, target: self, action: #selector(chooseBrowser(_:)))
            button.tag = index
            button.bezelStyle = .rounded
            button.alignment = .left
            button.image = NSWorkspace.shared.icon(forFile: browser.appURL.path)
            button.image?.size = NSSize(width: 24, height: 24)
            button.imagePosition = .imageLeading
            button.setAccessibilityLabel("Open with \(browser.displayName)")
            button.translatesAutoresizingMaskIntoConstraints = false
            browserStack.addArrangedSubview(button)
            button.widthAnchor.constraint(equalTo: browserStack.widthAnchor).isActive = true
            button.heightAnchor.constraint(equalToConstant: 36).isActive = true
            return button
        }
        updateSelection()
    }

    private func updateSelection() {
        for (index, button) in browserButtons.enumerated() {
            button.title = "\(index + 1). \(browsers[index].displayName)\(index == selectedIndex ? "  ↵" : "")"
            button.contentTintColor = index == selectedIndex ? .controlAccentColor : .labelColor
        }
    }

    private func updateControls() {
        let busy = phase == .loading || phase == .submitting
        if busy { spinner.startAnimation(nil) } else { spinner.stopAnimation(nil) }
        statusLabel.stringValue = phase == .submitting ? "Handing off to LinkCompass…" :
            (phase == .ready && browsers.isEmpty ? "No supported browsers detected. Use saved choice to continue in LinkCompass." : "Loading shared link…")
        statusLabel.superview?.isHidden = !busy && !(phase == .ready && browsers.isEmpty)
        linkLabel.isHidden = webURL == nil
        browserStack.isHidden = webURL == nil
        rememberButton.isHidden = webURL == nil || browsers.isEmpty
        rememberButton.isEnabled = phase == .ready
        savedButton.isEnabled = phase == .ready
        browserButtons.forEach { $0.isEnabled = phase == .ready }
        errorLabel.isHidden = errorLabel.stringValue.isEmpty
        retryButton.isHidden = errorLabel.stringValue.isEmpty
        retryButton.isEnabled = phase == .loadFailed || phase == .ready
        // Once submitted, cancellation cannot undo delivery to the containing app.
        cancelButton.isEnabled = phase != .submitting && phase != .finished
        view.layoutSubtreeIfNeeded()
    }

    @objc private func chooseBrowser(_ sender: NSButton) {
        guard phase == .ready, browsers.indices.contains(sender.tag) else { return }
        selectedIndex = sender.tag
        updateSelection()
        submitSelectedBrowser()
    }

    private func submitSelectedBrowser() {
        guard browsers.indices.contains(selectedIndex) else { return }
        submit(.browser(bundleIdentifier: browsers[selectedIndex].bundleIdentifier, remember: rememberButton.state == .on))
    }

    @objc private func useSavedChoice() {
        submit(.savedChoice)
    }

    private func submit(_ selection: ShareOpenRequest.Selection) {
        guard phase == .ready, let webURL else { return }
        phase = .submitting
        retrySelection = selection
        errorLabel.stringValue = ""
        let token = UUID()
        generation = token
        updateControls()
        do {
            let request = try ShareOpenRequest(url: webURL, selection: selection)
            try ContainingAppHandoff.open(request) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self, self.generation == token, self.phase == .submitting else { return }
                    switch result {
                    case .success:
                        self.phase = .finished
                        self.generation = UUID()
                        self.removeKeyMonitor()
                        self.updateControls()
                        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                    case .failure(let error):
                        self.showHandoffError(error)
                    }
                }
            }
        } catch {
            showHandoffError(error)
        }
    }

    private func showHandoffError(_ error: Error) {
        phase = .ready
        errorLabel.stringValue = error.localizedDescription
        updateControls()
    }

    @objc private func retry() {
        if phase == .loadFailed {
            loadSharedLink()
        } else if phase == .ready, let retrySelection {
            submit(retrySelection.updatingRemember(rememberButton.state == .on))
        }
    }

    @objc private func cancel() {
        guard phase != .submitting && phase != .finished else { return }
        phase = .finished
        generation = UUID()
        removeKeyMonitor()
        updateControls()
        extensionContext?.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        // Scope to our view/window; leave shortcuts, accessibility navigation and
        // all events focused on the remember checkbox to AppKit.
        guard phase == .ready, event.window === view.window,
              event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty,
              let responder = view.window?.firstResponder as? NSView,
              responder === view || responder.isDescendant(of: view),
              responder !== rememberButton,
              !responder.isDescendant(of: rememberButton),
              !(responder is NSTextView) else { return false }
        switch event.keyCode {
        case 53:
            cancel()
        case 36, 76:
            // Enter on other action buttons must retain that button's meaning.
            if responder === savedButton || responder === retryButton || responder === cancelButton { return false }
            submitSelectedBrowser()
        case 125, 126:
            guard !browsers.isEmpty else { return false }
            selectedIndex = (selectedIndex + (event.keyCode == 125 ? 1 : browsers.count - 1)) % browsers.count
            updateSelection()
        default:
            guard let text = event.charactersIgnoringModifiers, text.count == 1,
                  let number = Int(text), (1...9).contains(number),
                  browsers.indices.contains(number - 1) else { return false }
            selectedIndex = number - 1
            updateSelection()
            submitSelectedBrowser()
        }
        return true
    }
}

private final class ShareRootView: NSView {
    override var acceptsFirstResponder: Bool { true }
}

private final class ShareDocumentView: NSView {
    override var isFlipped: Bool { true }
}
