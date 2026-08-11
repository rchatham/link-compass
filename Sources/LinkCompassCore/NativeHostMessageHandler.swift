import Foundation

public struct NativeHostResponse: Codable, Equatable, Sendable {
    public let ok: Bool
    public let type: String
    public let matched: Bool?
    public let host: String?
    public let browserBundleIdentifier: String?
    public let browserDisplayName: String?
    public let expiresAt: Date?
    public let error: String?

    public static func recentRoute(_ route: PendingRoute?) -> NativeHostResponse {
        NativeHostResponse(
            ok: true,
            type: "recentRouteForURLResult",
            matched: route != nil,
            host: route?.normalizedHost,
            browserBundleIdentifier: route?.browserBundleIdentifier,
            browserDisplayName: route?.browserDisplayName,
            expiresAt: route?.expiresAt,
            error: nil
        )
    }

    public static func remembered(host: String, browserBundleIdentifier: String) -> NativeHostResponse {
        NativeHostResponse(
            ok: true,
            type: "rememberRouteResult",
            matched: nil,
            host: host,
            browserBundleIdentifier: browserBundleIdentifier,
            browserDisplayName: nil,
            expiresAt: nil,
            error: nil
        )
    }

    public static func failure(_ message: String) -> NativeHostResponse {
        NativeHostResponse(
            ok: false,
            type: "error",
            matched: nil,
            host: nil,
            browserBundleIdentifier: nil,
            browserDisplayName: nil,
            expiresAt: nil,
            error: message
        )
    }
}

public final class NativeHostMessageHandler: @unchecked Sendable {
    private struct Envelope: Decodable {
        let type: String
        let url: String?
        let host: String?
        let browserBundleIdentifier: String?
    }

    private let routeStore: PendingRouteStore
    private let ruleStore: RuleStore

    public init(routeStore: PendingRouteStore, ruleStore: RuleStore) {
        self.routeStore = routeStore
        self.ruleStore = ruleStore
    }

    public func handle(_ data: Data) -> NativeHostResponse {
        do {
            let envelope = try JSONDecoder.linkCompass.decode(Envelope.self, from: data)
            switch envelope.type {
            case "recentRouteForURL":
                return try handleRecentRouteForURL(envelope)
            case "rememberRoute":
                return try handleRememberRoute(envelope)
            default:
                return .failure("Unsupported message type: \(envelope.type)")
            }
        } catch {
            return .failure("Invalid native message: \(error.localizedDescription)")
        }
    }

    private func handleRecentRouteForURL(_ envelope: Envelope) throws -> NativeHostResponse {
        guard let rawURL = envelope.url,
              let url = URL(string: rawURL),
              URLNormalizer.normalizedHost(from: url) != nil else {
            return .failure("recentRouteForURL requires a valid http or https url")
        }
        let route = try routeStore.recentRoute(for: url)
        return .recentRoute(route)
    }

    private func handleRememberRoute(_ envelope: Envelope) throws -> NativeHostResponse {
        guard let rawHost = envelope.host,
              let normalizedHost = Self.normalizedHost(rawHost) else {
            return .failure("rememberRoute requires a valid host")
        }
        guard let browserBundleIdentifier = envelope.browserBundleIdentifier,
              !browserBundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure("rememberRoute requires browserBundleIdentifier")
        }
        try ruleStore.recordChoice(host: normalizedHost, browserBundleIdentifier: browserBundleIdentifier)
        return .remembered(host: normalizedHost, browserBundleIdentifier: browserBundleIdentifier)
    }

    private static func normalizedHost(_ host: String) -> String? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = components.url else { return nil }
        return URLNormalizer.normalizedHost(from: url)
    }
}
