import XCTest
@testable import LinkCompassCore

final class URLNormalizerTests: XCTestCase {
    func testNormalizesHTTPHost() throws {
        let url = try XCTUnwrap(URL(string: "https://WWW.Example.COM/path?token=secret"))
        XCTAssertEqual(URLNormalizer.normalizedHost(from: url), "example.com")
    }

    func testRejectsUnsupportedSchemes() throws {
        let url = try XCTUnwrap(URL(string: "file:///tmp/example"))
        XCTAssertNil(URLNormalizer.normalizedHost(from: url))
    }

    func testTrimsTrailingDot() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com./"))
        XCTAssertEqual(URLNormalizer.normalizedHost(from: url), "example.com")
    }
}
