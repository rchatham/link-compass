import Foundation

public enum WebURLValidationError: LocalizedError, Equatable, Sendable {
    case invalidURL

    public var errorDescription: String? {
        "Share a complete HTTP or HTTPS URL with a host, without credentials or whitespace."
    }
}

public enum WebURLValidator {
    public static func validatedURL(_ url: URL) throws -> URL {
        try validate(url.absoluteString)
        return url
    }

    public static func validatedURL(from text: String) throws -> URL {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        try validate(text)
        guard let url = URL(string: text) else {
            throw WebURLValidationError.invalidURL
        }
        return url
    }

    private static func validate(_ text: String) throws {
        guard !text.isEmpty,
              !text.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.union(.controlCharacters).contains($0) }),
              !text.contains("\\"),
              hasValidPercentEncoding(text),
              let decoded = text.removingPercentEncoding,
              !decoded.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
              let components = URLComponents(string: text),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host, !host.isEmpty,
              !host.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.union(.controlCharacters).contains($0) }),
              !host.contains(where: { "/\\?#@".contains($0) }),
              components.user == nil, components.password == nil,
              let url = components.url,
              URLNormalizer.normalizedHost(from: url) != nil else {
            throw WebURLValidationError.invalidURL
        }
    }
}

// Foundation repairs malformed escapes when constructing URLs; inspect input first.
func hasValidPercentEncoding(_ text: String) -> Bool {
    let bytes = Array(text.utf8)
    var index = 0
    func isHex(_ byte: UInt8) -> Bool {
        (48...57).contains(byte) || (65...70).contains(byte) || (97...102).contains(byte)
    }
    while index < bytes.count {
        if bytes[index] == 37 {
            guard index + 2 < bytes.count, isHex(bytes[index + 1]), isHex(bytes[index + 2]) else { return false }
            index += 3
        } else {
            index += 1
        }
    }
    return true
}
