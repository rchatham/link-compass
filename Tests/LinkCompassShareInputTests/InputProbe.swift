import AppKit
import LinkCompassCore
import UniformTypeIdentifiers

// Runs the actual loader without NSApplication, windows, services or preferences.
// NSSharingService.h accepts NSString input; NSExtensionItem.h documents nullable
// attachments and independent attributedContentText. This fixture models the
// attachment-free text delivery observed by the scratch ShareKit QA host, not
// ShareKit's separate activation/enumeration metadata.
private final class FixtureContext: NSExtensionContext {
    private let items: [Any]

    init(_ items: [Any]) {
        self.items = items
        super.init()
    }

    override var inputItems: [Any] { items }
}

private final class Locked<Value> {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) { self.value = value }

    func read() -> Value {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func update(_ body: (inout Value) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        body(&value)
    }
}

private enum Expected {
    case url(String)
    case singleLinkRequired
    case unsupportedRepresentation
    case invalidURL
    case providerError
}

private struct ProbeFailure: Error, CustomStringConvertible {
    let description: String
}

private let goodURL = "https://example.com/link-compass-consent-check?source=share"
private let otherURL = "https://other.example/path#fragment"
private let providerError = NSError(domain: "LinkCompassInputProbe.Provider", code: 17)

private func item(_ attachments: [NSItemProvider]? = nil, text: String? = nil) -> NSExtensionItem {
    let item = NSExtensionItem()
    item.attachments = attachments
    item.attributedContentText = text.map { NSAttributedString(string: $0) }
    return item
}

private func urlProvider(_ text: String) -> NSItemProvider {
    NSItemProvider(item: URL(string: text)! as NSURL, typeIdentifier: UTType.url.identifier)
}

private func textProvider(_ text: String) -> NSItemProvider {
    NSItemProvider(item: text as NSString, typeIdentifier: UTType.plainText.identifier)
}

// Real registered providers exercise async loading and bridge NSURL/NSString/NSData.
// Tracking proves failures never request the alternate plain-text representation.
private func registeredProvider(
    url: NSSecureCoding? = nil,
    text: NSSecureCoding? = nil,
    error: Error? = nil,
    advertiseURL: Bool = true,
    requests: Locked<[String]> = Locked([])
) -> NSItemProvider {
    let provider = NSItemProvider()
    if advertiseURL {
        provider.registerItem(forTypeIdentifier: UTType.url.identifier) { completion, _, _ in
            requests.update { $0.append(UTType.url.identifier) }
            DispatchQueue.main.async { completion?(url, error) }
        }
    }
    provider.registerItem(forTypeIdentifier: UTType.plainText.identifier) { completion, _, _ in
        requests.update { $0.append(UTType.plainText.identifier) }
        DispatchQueue.main.async { completion?(text, error) }
    }
    return provider
}

private func matches(_ result: Result<URL, Error>, _ expected: Expected) -> Bool {
    switch (result, expected) {
    case (.success(let url), .url(let text)):
        return url.absoluteString == text
    case (.failure(let error), .invalidURL):
        return (error as? WebURLValidationError) == .invalidURL
    case (.failure(let error), .singleLinkRequired):
        return error.localizedDescription == "Share exactly one link or one piece of text containing only a web URL."
    case (.failure(let error), .unsupportedRepresentation):
        return error.localizedDescription == "This item does not provide a web URL or plain-text URL."
    case (.failure(let error), .providerError):
        // NSItemProvider wraps registered-handler errors in its own NSError.
        let error = error as NSError
        let underlying = (error.userInfo[NSUnderlyingErrorKey] as? NSError) ?? error
        return underlying.domain == providerError.domain && underlying.code == providerError.code
    default:
        return false
    }
}

private func check(
    _ name: String,
    items: [Any],
    expected: Expected,
    requests: Locked<[String]>? = nil,
    expectedTypes: [String] = [],
    useContext: Bool = false
) throws {
    let responses = Locked<[Result<URL, Error>]>([])
    let completion: (Result<URL, Error>) -> Void = { result in
        responses.update { $0.append(result) }
    }
    if useContext {
        ShareInputLoader.load(from: FixtureContext(items), completion: completion)
    } else {
        ShareInputLoader.load(inputItems: items, completion: completion)
    }
    // Pump the main run loop rather than blocking provider callbacks with a semaphore.
    // Lock every response access because NSItemProvider can finish on any queue.
    let deadline = ProcessInfo.processInfo.systemUptime + 5
    while responses.read().isEmpty && ProcessInfo.processInfo.systemUptime < deadline {
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
    }
    let results = responses.read()
    guard results.count == 1 else {
        throw ProbeFailure(description: "\(name): timed out or received multiple completions")
    }
    guard matches(results[0], expected) else {
        // Deliberately omit payloads and error descriptions from test output.
        throw ProbeFailure(description: "\(name): unexpected result category")
    }
    if let requests, requests.read() != expectedTypes {
        throw ProbeFailure(description: "\(name): unexpected representation request")
    }
    print("PASS \(name)")
}

@main
private struct ShareInputProbe {
    static func main() {
        setbuf(stdout, nil)
        do {
            try run()
        } catch {
            fputs("FAIL \(error)\n", stderr)
            exit(1)
        }
    }

    private static func run() throws {
        try check("zero-items", items: [], expected: .singleLinkRequired)
        try check("two-text-items", items: [item(text: goodURL), item(text: goodURL)], expected: .singleLinkRequired)
        try check("two-attachment-items", items: [item([urlProvider(goodURL)]), item([urlProvider(goodURL)])], expected: .singleLinkRequired)
        try check("non-extension-item", items: [goodURL as NSString], expected: .singleLinkRequired)
        try check("nil-attachments-no-text", items: [item()], expected: .singleLinkRequired)
        try check("zero-attachments-no-text", items: [item([])], expected: .singleLinkRequired)
        try check("two-attachments-valid-text", items: [item([urlProvider(goodURL), textProvider(goodURL)], text: goodURL)], expected: .singleLinkRequired)

        try check("sharekit-text-delivery-context", items: [item(text: goodURL)], expected: .url(goodURL), useContext: true)
        try check("empty-attachments-complete-text", items: [item([], text: goodURL)], expected: .url(goodURL))
        try check("trimmed-attributed-text", items: [item(text: " \n" + goodURL + "\n ")], expected: .url(goodURL))
        let attributedFailures: [(String, String)] = [
            ("empty", ""),
            ("whitespace", " \n"),
            ("prose-prefix", "Read " + goodURL),
            ("prose-suffix", goodURL + " read this"),
            ("multiple-urls", goodURL + " " + otherURL),
            ("credentials", "https://user:password@example.com/"),
            ("nonweb", "ftp://example.com/"),
            ("file-url", "file:///synthetic-not-read"),
            ("missing-scheme", "example.com/path"),
            ("missing-host", "https:///"),
            ("bad-escape", "https://example.com/%ZZ")
        ]
        for (name, text) in attributedFailures {
            try check("attributed-" + name, items: [item(text: text)], expected: .invalidURL)
        }
        let titleOnly = item()
        titleOnly.attributedTitle = NSAttributedString(string: goodURL)
        try check("title-is-not-content", items: [titleOnly], expected: .singleLinkRequired)
        let linkedProse = item()
        linkedProse.attributedContentText = NSAttributedString(string: "Read this", attributes: [.link: URL(string: goodURL)!])
        try check("never-extract-attributed-link", items: [linkedProse], expected: .invalidURL)

        try check("nsurl-attachment-context", items: [item([urlProvider(goodURL)])], expected: .url(goodURL), useContext: true)
        try check("nsstring-text-attachment", items: [item([textProvider(goodURL)])], expected: .url(goodURL))
        try check("trimmed-text-attachment", items: [item([textProvider(" \n" + goodURL + "\n ")])], expected: .url(goodURL))
        try check("attachment-wins-over-valid-attributed-text", items: [item([urlProvider(otherURL)], text: goodURL)], expected: .url(otherURL))
        try check("valid-attachment-ignores-prose", items: [item([urlProvider(goodURL)], text: "prose")], expected: .url(goodURL))
        try check("unsupported-attachment-no-text-fallback", items: [item([NSItemProvider()], text: goodURL)], expected: .unsupportedRepresentation)
        try check("bad-text-attachment-no-attributed-fallback", items: [item([textProvider("prose")], text: goodURL)], expected: .invalidURL)
        try check("nonweb-url-attachment-no-text-fallback", items: [item([urlProvider("ftp://example.com/")], text: goodURL)], expected: .invalidURL)
        try check("credential-url-attachment", items: [item([urlProvider("https://user:password@example.com/")])], expected: .invalidURL)

        for (name, value, advertiseURL) in [
            ("nsstring-url-representation", goodURL as NSString as NSSecureCoding, true),
            ("nsdata-url-representation", Data(goodURL.utf8) as NSData as NSSecureCoding, true),
            ("nsdata-text-representation", Data(goodURL.utf8) as NSData as NSSecureCoding, false)
        ] {
            let requests = Locked<[String]>([])
            let provider = registeredProvider(url: value, text: value, advertiseURL: advertiseURL, requests: requests)
            try check(name, items: [item([provider])], expected: .url(goodURL), requests: requests,
                      expectedTypes: [advertiseURL ? UTType.url.identifier : UTType.plainText.identifier])
        }
        let failures: [(String, NSSecureCoding?, Error?, Expected)] = [
            ("malformed-url", "https://example.com/%ZZ" as NSString, nil, .invalidURL),
            ("nonweb-url", "ftp://example.com/" as NSString, nil, .invalidURL),
            ("invalid-utf8-url-data", Data([0xff]) as NSData, nil, .unsupportedRepresentation),
            ("unsupported-url-value", NSNumber(value: 7), nil, .unsupportedRepresentation),
            ("nil-url-value", nil, nil, .unsupportedRepresentation),
            ("url-provider-error", goodURL as NSString, providerError, .providerError)
        ]
        for (name, value, error, expected) in failures {
            let requests = Locked<[String]>([])
            let provider = registeredProvider(url: value, text: goodURL as NSString, error: error, requests: requests)
            try check(name + "-never-falls-back", items: [item([provider], text: goodURL)], expected: expected,
                      requests: requests, expectedTypes: [UTType.url.identifier])
        }
        let priorityRequests = Locked<[String]>([])
        let priorityProvider = registeredProvider(url: URL(string: otherURL)! as NSURL, text: goodURL as NSString, requests: priorityRequests)
        try check("url-priority-over-provider-and-attributed-text", items: [item([priorityProvider], text: goodURL)],
                  expected: .url(otherURL), requests: priorityRequests, expectedTypes: [UTType.url.identifier])
        let errorRequests = Locked<[String]>([])
        let errorProvider = registeredProvider(text: goodURL as NSString, error: providerError, advertiseURL: false, requests: errorRequests)
        try check("text-provider-error-no-attributed-fallback", items: [item([errorProvider], text: goodURL)], expected: .providerError,
                  requests: errorRequests, expectedTypes: [UTType.plainText.identifier])
        let responses = Locked<[Result<URL, Error>]>([])
        ShareInputLoader.load(from: nil) { result in responses.update { $0.append(result) } }
        guard responses.read().count == 1, matches(responses.read()[0], .singleLinkRequired) else {
            throw ProbeFailure(description: "nil-context: unexpected result")
        }
        print("PASS nil-context")
    }
}
