import XCTest
@testable import LinkCompassCore

final class ShareConsentPolicyTests: XCTestCase {
    func testOnlyWireRememberIntentRequiresConfirmation() throws {
        XCTAssertTrue(ShareConsentPolicy.requiresConfirmation(try request(remember: true), origin: .wire))
        XCTAssertFalse(ShareConsentPolicy.requiresConfirmation(try request(remember: false), origin: .wire))
        XCTAssertFalse(ShareConsentPolicy.requiresConfirmation(try request(remember: true), origin: .localPicker))
        XCTAssertFalse(ShareConsentPolicy.requiresConfirmation(try savedRequest(), origin: .wire))
    }

    func testWireRememberDefaultsToOpenOnceAndPreservesOriginalRequest() throws {
        let wire = try request(remember: true)
        let approved = try XCTUnwrap(ShareConsentPolicy.approve(wire, origin: .wire))
        XCTAssertEqual(approved.request.selection, .browser(bundleIdentifier: KnownBrowser.safari.rawValue, remember: false))
        XCTAssertEqual(wire.selection, .browser(bundleIdentifier: KnownBrowser.safari.rawValue, remember: true))
    }

    func testWireRememberRequiresExplicitOpenAndRememberConsent() throws {
        let wire = try request(remember: true)
        let approved = try XCTUnwrap(ShareConsentPolicy.approve(wire, origin: .wire, consent: .openAndRemember))
        XCTAssertEqual(approved.request, wire)
        let openOnce = try XCTUnwrap(ShareConsentPolicy.approve(wire, origin: .wire, consent: .openOnce))
        XCTAssertEqual(openOnce.request, try request(remember: false))
    }

    func testCancelNeverProducesApprovedIntent() throws {
        for wire in [try request(remember: true), try request(remember: false), try savedRequest()] {
            for origin in [ShareRequestOrigin.wire, .localPicker] {
                XCTAssertNil(try ShareConsentPolicy.approve(wire, origin: origin, consent: .cancel))
            }
        }
    }

    func testLocalPickerCheckboxNeedsNoSecondConfirmation() throws {
        for remember in [true, false] {
            let local = try request(remember: remember)
            XCTAssertEqual(try ShareConsentPolicy.approve(local, origin: .localPicker)?.request, local)
        }
    }

    func testConsentCannotPromoteUncheckedOrSavedIntentIntoRemember() throws {
        for wire in [try request(remember: false), try savedRequest()] {
            XCTAssertEqual(try ShareConsentPolicy.approve(wire, origin: .wire, consent: .openAndRemember)?.request, wire)
        }
    }

    private func request(remember: Bool) throws -> ShareOpenRequest {
        try ShareOpenRequest(url: URL(string: "https://example.com")!, selection: .browser(bundleIdentifier: KnownBrowser.safari.rawValue, remember: remember))
    }

    private func savedRequest() throws -> ShareOpenRequest {
        try ShareOpenRequest(url: URL(string: "https://example.com")!, selection: .savedChoice)
    }
}
