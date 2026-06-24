import XCTest
@testable import LinkCompassCore

final class IncomingURLContextTests: XCTestCase {
    func testCreatesDomainContextForWebURL() throws {
        let url = try XCTUnwrap(URL(string: "https://www.example.com/path"))

        let context = try XCTUnwrap(IncomingURLContext(url: url))

        XCTAssertEqual(context.displayTitle, "example.com")
        XCTAssertEqual(context.rememberHost, "example.com")
        XCTAssertTrue(context.supportsDomainRules)
    }

    func testCreatesFileContextWithoutDomainRules() throws {
        let url = URL(fileURLWithPath: "/tmp/report.html")

        let context = try XCTUnwrap(IncomingURLContext(url: url))

        XCTAssertEqual(context.displayTitle, "report.html")
        XCTAssertNil(context.rememberHost)
        XCTAssertFalse(context.supportsDomainRules)
    }

    func testRejectsUnsupportedURL() throws {
        let url = try XCTUnwrap(URL(string: "mailto:test@example.com"))

        XCTAssertNil(IncomingURLContext(url: url))
    }
}
