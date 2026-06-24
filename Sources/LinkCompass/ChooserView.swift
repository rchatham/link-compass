import AppKit
import SwiftUI
import LinkCompassCore

struct ChooserView: View {
    let url: URL
    let displayTitle: String
    let rememberLabel: String?
    let browsers: [Browser]
    let initialSelection: String?
    let onChoose: (Browser, Bool) -> Void
    let onCancel: () -> Void

    @State private var selection = ChooserSelectionState(browserCount: 0)
    @State private var rememberChoice = false
    @State private var keyMonitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Open link with…")
                    .font(.headline)
                Text(displayTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(url.absoluteString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            VStack(spacing: 6) {
                ForEach(Array(browsers.enumerated()), id: \.element.bundleIdentifier) { index, browser in
                    browserRow(browser: browser, index: index)
                }
            }

            if let rememberLabel {
                Toggle("Remember this choice for \(rememberLabel)", isOn: $rememberChoice)
                    .font(.caption)
            }

            HStack {
                Text("Enter opens • Esc cancels • ↑/↓ selects • 1–9 opens")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(18)
        .frame(width: 520)
        .onAppear {
            selection.update(browserCount: browsers.count, preferredIndex: preferredInitialIndex())
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                handleKeyDown(event) ? nil : event
            }
        }
        .onDisappear {
            if let keyMonitor {
                NSEvent.removeMonitor(keyMonitor)
                self.keyMonitor = nil
            }
        }
    }

    private func browserRow(browser: Browser, index: Int) -> some View {
        Button {
            selection.update(browserCount: browsers.count, preferredIndex: index)
            chooseSelected()
        } label: {
            HStack(spacing: 10) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: browser.appURL.path))
                    .resizable()
                    .frame(width: 28, height: 28)
                Text("\(index + 1).")
                    .foregroundStyle(.secondary)
                    .frame(width: 22, alignment: .trailing)
                Text(browser.displayName)
                Spacer()
                if index == selection.selectedIndex {
                    Image(systemName: "return")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(index == selection.selectedIndex ? Color.accentColor.opacity(0.18) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func preferredInitialIndex() -> Int {
        guard let initialSelection,
              let index = browsers.firstIndex(where: { $0.bundleIdentifier == initialSelection }) else {
            return 0
        }
        return index
    }

    private func chooseSelected() {
        guard browsers.indices.contains(selection.selectedIndex) else { return }
        onChoose(browsers[selection.selectedIndex], rememberChoice)
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 36, 76:
            chooseSelected()
            return true
        case 53:
            onCancel()
            return true
        case 125:
            selection.moveDown()
            return true
        case 126:
            selection.moveUp()
            return true
        default:
            if let characters = event.charactersIgnoringModifiers,
               let number = Int(characters),
               selection.selectShortcutNumber(number) {
                chooseSelected()
                return true
            }
            return false
        }
    }
}
