import Foundation

public enum ShareOpenRequestError: LocalizedError, Equatable, Sendable {
    case malformedRequest
    case unknownBrowser(String)

    public var errorDescription: String? {
        switch self {
        case .malformedRequest: "The LinkCompass share request is invalid."
        case .unknownBrowser(let identifier): "Unsupported browser: \(identifier)."
        }
    }
}

public struct ShareOpenRequest: Equatable, Sendable {
    public enum Selection: Equatable, Sendable {
        case browser(bundleIdentifier: String, remember: Bool)
        case savedChoice

        public func updatingRemember(_ remember: Bool) -> Selection {
            switch self {
            case .browser(let identifier, _):
                return .browser(bundleIdentifier: identifier, remember: remember)
            case .savedChoice:
                return .savedChoice
            }
        }
    }

    public let url: URL
    public let selection: Selection

    public init(url: URL, selection: Selection) throws {
        self.url = try WebURLValidator.validatedURL(url)
        if case .browser(let identifier, _) = selection, KnownBrowser(rawValue: identifier) == nil {
            throw ShareOpenRequestError.unknownBrowser(identifier)
        }
        self.selection = selection
    }

    public func encodedURL() throws -> URL {
        var components = URLComponents()
        components.scheme = "linkcompass"
        components.host = "share"
        var items = [URLQueryItem(name: "v", value: "1"), URLQueryItem(name: "url", value: url.absoluteString)]
        switch selection {
        case .browser(let identifier, let remember):
            items += [URLQueryItem(name: "mode", value: "browser"), URLQueryItem(name: "browser", value: identifier), URLQueryItem(name: "remember", value: remember ? "1" : "0")]
        case .savedChoice:
            items.append(URLQueryItem(name: "mode", value: "saved"))
        }
        components.queryItems = items
        guard let requestURL = components.url else { throw ShareOpenRequestError.malformedRequest }
        return requestURL
    }

    public static func decode(_ requestURL: URL) throws -> ShareOpenRequest {
        guard requestURL.absoluteString.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first?.lowercased() == "linkcompass://share",
              hasValidPercentEncoding(requestURL.absoluteString),
              let components = URLComponents(url: requestURL, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "linkcompass",
              components.host == "share",
              components.user == nil, components.password == nil, components.port == nil,
              components.percentEncodedPath.isEmpty, components.fragment == nil,
              let items = components.queryItems else {
            throw ShareOpenRequestError.malformedRequest
        }
        var fields: [String: String] = [:]
        for item in items {
            guard let value = item.value, fields[item.name] == nil else {
                throw ShareOpenRequestError.malformedRequest
            }
            fields[item.name] = value
        }
        guard fields["v"] == "1", let text = fields["url"] else {
            throw ShareOpenRequestError.malformedRequest
        }
        let selection: Selection
        switch fields["mode"] {
        case "browser":
            guard Set(fields.keys) == Set(["v", "url", "mode", "browser", "remember"]),
                  let identifier = fields["browser"],
                  let remember = fields["remember"], remember == "0" || remember == "1" else {
                throw ShareOpenRequestError.malformedRequest
            }
            selection = .browser(bundleIdentifier: identifier, remember: remember == "1")
        case "saved":
            guard Set(fields.keys) == Set(["v", "url", "mode"]) else { throw ShareOpenRequestError.malformedRequest }
            selection = .savedChoice
        default:
            throw ShareOpenRequestError.malformedRequest
        }
        return try ShareOpenRequest(url: WebURLValidator.validatedURL(from: text), selection: selection)
    }
}
