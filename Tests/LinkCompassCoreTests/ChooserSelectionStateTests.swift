import XCTest
@testable import LinkCompassCore

final class ChooserSelectionStateTests: XCTestCase {
    func testInitialSelectionIsClamped() {
        XCTAssertEqual(ChooserSelectionState(browserCount: 3, selectedIndex: 99).selectedIndex, 2)
        XCTAssertEqual(ChooserSelectionState(browserCount: 0, selectedIndex: 99).selectedIndex, 0)
    }

    func testArrowMovementStaysInBounds() {
        var state = ChooserSelectionState(browserCount: 2)
        state.moveUp()
        XCTAssertEqual(state.selectedIndex, 0)

        state.moveDown()
        state.moveDown()
        XCTAssertEqual(state.selectedIndex, 1)
    }

    func testNumberShortcutsSelectVisibleBrowser() {
        var state = ChooserSelectionState(browserCount: 10)
        XCTAssertTrue(state.selectShortcutNumber(9))
        XCTAssertEqual(state.selectedIndex, 8)
        XCTAssertFalse(state.selectShortcutNumber(10))
        XCTAssertEqual(state.selectedIndex, 8)
    }

    func testUpdateUsesPreferredIndex() {
        var state = ChooserSelectionState(browserCount: 3)
        state.update(browserCount: 3, preferredIndex: 2)
        XCTAssertEqual(state.selectedIndex, 2)
    }
}
