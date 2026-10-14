import XCTest
@testable import LinkCompassCore

final class WebURLValidatorTests: XCTestCase {
    func testAcceptsCompleteWebURLsAndTrimsSurroundingWhitespace() throws {
        for text in [
            "https://example.com/path?x=one+two#fragment",
            "http://localhost:8080/",
            "https://[::1]:443/path",
            "HTTPS://www.Example.com./path",
            "https://example.com/a%20b?value=%2520",
            "https://例え.テスト/記事"
        ] {
            let url = try WebURLValidator.validatedURL(from: " \n\t\(text)\r\n ")
            XCTAssertEqual(try WebURLValidator.validatedURL(url), url)
        }
    }

    func testRejectsUnsupportedSchemesMissingHostsAndCredentials() {
        for text in [
            "", "example.com", "/path", "file:///tmp/test.html", "javascript:alert(1)",
            "mailto:user@example.com", "linkcompass://share", "https:///path", "https://",
            "https://user@example.com/", "https://user:pass@example.com/", "https://@example.com/"
        ] {
            XCTAssertThrowsError(try WebURLValidator.validatedURL(from: text), text)
        }
    }

    func testRejectsProseMultipleURLsWhitespaceAndControls() {
        for text in [
            "Visit https://example.com", "https://example.com is a website",
            "https://example.com\nhttps://other.example", "https://example.com/a b",
            "https://example.com/a\tb", "https://exam ple.com/", "https://example.com/\u{0000}",
            "https://example.com/a%00b", "https://example.com/%0A", "https://example.com/%7F",
            "https://exa%20mple.com/"
        ] {
            XCTAssertThrowsError(try WebURLValidator.validatedURL(from: text), text)
        }
    }

    func testRejectsMalformedPercentEncodingBeforeFoundationRepairsIt() {
        for text in ["https://example.com/%", "https://example.com/%1", "https://example.com/%GG", "https://example.com/?q=%2z"] {
            XCTAssertThrowsError(try WebURLValidator.validatedURL(from: text), text)
        }
    }

    func testRejectsAmbiguousAuthoritiesAndHostsWithoutRoutingContext() {
        for text in [
            "https://example.com%2F.attacker/path", "https://example.com%5C.attacker/path",
            "https://example.com%3F.attacker/path", "https://example.com%23.attacker/path",
            "https://example.com%40.attacker/path", "https://example.com\\attacker/path",
            "https://./path"
        ] {
            XCTAssertThrowsError(try WebURLValidator.validatedURL(from: text), text)
        }
    }

    func testURLOverloadRejectsCredentialsControlsAndUnsupportedSchemes() throws {
        for text in ["https://user:pass@example.com/", "https://example.com/%0D", "file:///tmp/test.html"] {
            let url = try XCTUnwrap(URL(string: text))
            XCTAssertThrowsError(try WebURLValidator.validatedURL(url), text)
        }
    }
}
