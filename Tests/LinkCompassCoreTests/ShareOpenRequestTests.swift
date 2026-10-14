import XCTest
@testable import LinkCompassCore

final class ShareOpenRequestTests: XCTestCase {
    func testExplicitBrowserRoundTripsEveryKnownBrowserAndRememberFlag() throws {
        let url = try WebURLValidator.validatedURL(from: "https://example.com/a%20b?x=1&redirect=https%3A%2F%2Fother.example%2F%3Fa%3Db&plus=a+b#section")
        for browser in KnownBrowser.allCases {
            for remember in [false, true] {
                let request = try ShareOpenRequest(url: url, selection: .browser(bundleIdentifier: browser.rawValue, remember: remember))
                XCTAssertEqual(try ShareOpenRequest.decode(request.encodedURL()), request)
            }
        }
    }

    func testSavedChoiceRoundTripsWithExactlyThreeFields() throws {
        let request = try ShareOpenRequest(url: URL(string: "https://example.com/")!, selection: .savedChoice)
        let encoded = try request.encodedURL()
        let components = try XCTUnwrap(URLComponents(url: encoded, resolvingAgainstBaseURL: false))
        XCTAssertEqual(Set(components.queryItems?.map(\.name) ?? []), Set(["v", "url", "mode"]))
        XCTAssertEqual(try ShareOpenRequest.decode(encoded), request)
    }

    func testInitializerRejectsUnknownBrowserAndNonWebURL() {
        XCTAssertThrowsError(try ShareOpenRequest(url: URL(string: "https://example.com")!, selection: .browser(bundleIdentifier: "com.attacker.browser", remember: false)))
        XCTAssertThrowsError(try ShareOpenRequest(url: URL(fileURLWithPath: "/tmp/page.html"), selection: .savedChoice))
    }

    func testRejectsOuterCredentialsPortsPathsFragmentsAndWrongCommand() throws {
        for prefix in [
            "https://share", "linkcompass:share", "linkcompass://other", "linkcompass://user@share",
            "linkcompass://user:pass@share", "linkcompass://@share", "linkcompass://share:443",
            "linkcompass://share:", "linkcompass://%73hare",
            "linkcompass://share/", "linkcompass://share/path"
        ] {
            XCTAssertThrowsError(try ShareOpenRequest.decode(try rawURL("\(prefix)?v=1&url=https%3A%2F%2Fexample.com&mode=saved")), prefix)
        }
        for fragment in ["#", "#fragment"] {
            XCTAssertThrowsError(try ShareOpenRequest.decode(try rawURL("linkcompass://share?v=1&url=https%3A%2F%2Fexample.com&mode=saved\(fragment)")))
        }
    }

    func testRejectsMissingDuplicateUnknownAndEmptyFields() throws {
        for query in [
            "", "v=1", "v=2&url=https%3A%2F%2Fexample.com&mode=saved",
            "url=https%3A%2F%2Fexample.com&mode=saved", "v=1&mode=saved",
            "v=1&url=https%3A%2F%2Fexample.com", "v=1&url=https%3A%2F%2Fexample.com&mode=other",
            "v=1&url=https%3A%2F%2Fexample.com&mode=", "v=1&url=&mode=saved",
            "v=1&url=https%3A%2F%2Fexample.com&mode=saved&v=1",
            "v=1&url=https%3A%2F%2Fexample.com&mode=saved&url=https%3A%2F%2Fother.example",
            "v=1&url=https%3A%2F%2Fexample.com&mode=saved&mode=saved",
            "v=1&url=https%3A%2F%2Fexample.com&mode=saved&unknown=x",
            "v=1&url=https%3A%2F%2Fexample.com&mode=saved&unknown",
            "v&url=https%3A%2F%2Fexample.com&mode=saved",
            "v=1&url=https%3A%2F%2Fexample.com&mode=saved&remember=0",
            "v=1&url=https%3A%2F%2Fexample.com&mode=saved&browser=com.apple.Safari"
        ] {
            XCTAssertThrowsError(try ShareOpenRequest.decode(try rawURL("linkcompass://share?\(query)")), query)
        }
    }

    func testRejectsInvalidBrowserModeFields() throws {
        let base = "linkcompass://share?v=1&url=https%3A%2F%2Fexample.com&mode=browser"
        for fields in [
            "", "&browser=com.apple.Safari", "&remember=0", "&browser=&remember=0",
            "&browser=unknown&remember=0", "&browser=com.apple.Safari&remember=true",
            "&browser=com.apple.Safari&remember=2", "&browser=com.apple.Safari&remember=",
            "&browser=com.apple.Safari&remember=0&remember=1",
            "&browser=com.apple.Safari&remember=0&browser=org.mozilla.firefox"
        ] {
            XCTAssertThrowsError(try ShareOpenRequest.decode(try rawURL(base + fields)), fields)
        }
    }

    func testRejectsNestedNonWebCredentialsWhitespaceAndMalformedEscapes() throws {
        for text in [
            "file:///tmp/page.html", "javascript:alert(1)", "linkcompass://share",
            "https://user:pass@example.com/", "https://example.com/a b",
            "https://example.com/%GG", "https://example.com/%", "https://example.com/%0A",
            "Here is https://example.com", "https://example.com\nhttps://other.example"
        ] {
            var components = URLComponents(string: "linkcompass://share")!
            components.queryItems = [URLQueryItem(name: "v", value: "1"), URLQueryItem(name: "url", value: text), URLQueryItem(name: "mode", value: "saved")]
            XCTAssertThrowsError(try ShareOpenRequest.decode(try XCTUnwrap(components.url)), text)
        }
    }

    func testBrowserRetryUsesCurrentRememberChoiceInBothDirections() {
        let identifier = KnownBrowser.safari.rawValue
        XCTAssertEqual(
            ShareOpenRequest.Selection.browser(bundleIdentifier: identifier, remember: true).updatingRemember(false),
            .browser(bundleIdentifier: identifier, remember: false)
        )
        XCTAssertEqual(
            ShareOpenRequest.Selection.browser(bundleIdentifier: identifier, remember: false).updatingRemember(true),
            .browser(bundleIdentifier: identifier, remember: true)
        )
    }

    func testSavedChoiceRetryIgnoresRememberToggle() {
        XCTAssertEqual(ShareOpenRequest.Selection.savedChoice.updatingRemember(true), .savedChoice)
        XCTAssertEqual(ShareOpenRequest.Selection.savedChoice.updatingRemember(false), .savedChoice)
    }

    private func rawURL(_ text: String) throws -> URL {
        try XCTUnwrap(URL(string: text))
    }
}
