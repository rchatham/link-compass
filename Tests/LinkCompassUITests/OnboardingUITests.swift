import XCTest

final class OnboardingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testOnboardingWindowShowsSetupActions() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Welcome to LinkCompass"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Set Automatically"].exists)
        XCTAssertTrue(app.buttons["Open Default Browser Settings"].exists)
        XCTAssertTrue(app.buttons["Restore Safari"].exists)
        XCTAssertTrue(app.staticTexts["Privacy-first by default"].exists)
    }
}
