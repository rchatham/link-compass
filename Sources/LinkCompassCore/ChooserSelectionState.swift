import Foundation

public struct ChooserSelectionState: Equatable, Sendable {
    public private(set) var selectedIndex: Int
    public private(set) var browserCount: Int

    public init(browserCount: Int, selectedIndex: Int = 0) {
        self.browserCount = max(0, browserCount)
        self.selectedIndex = Self.clamp(selectedIndex, browserCount: self.browserCount)
    }

    public mutating func update(browserCount: Int, preferredIndex: Int?) {
        self.browserCount = max(0, browserCount)
        self.selectedIndex = Self.clamp(preferredIndex ?? selectedIndex, browserCount: self.browserCount)
    }

    public mutating func moveDown() {
        selectedIndex = Self.clamp(selectedIndex + 1, browserCount: browserCount)
    }

    public mutating func moveUp() {
        selectedIndex = Self.clamp(selectedIndex - 1, browserCount: browserCount)
    }

    public mutating func selectShortcutNumber(_ number: Int) -> Bool {
        guard number >= 1, number <= min(9, browserCount) else { return false }
        selectedIndex = number - 1
        return true
    }

    private static func clamp(_ index: Int, browserCount: Int) -> Int {
        guard browserCount > 0 else { return 0 }
        return min(max(index, 0), browserCount - 1)
    }
}
