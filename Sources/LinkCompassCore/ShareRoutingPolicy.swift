import Foundation

public enum ShareRoutingError: LocalizedError, Equatable, Sendable {
    case browserUnavailable(String)
    case couldNotSavePreference(String)

    public var errorDescription: String? {
        switch self {
        case .browserUnavailable(let identifier):
            "The selected browser (\(identifier)) is not installed. Choose another browser explicitly."
        case .couldNotSavePreference(let description):
            "The link opened, but its site preference could not be saved: \(description)"
        }
    }
}

public enum ShareRoute: Equatable, Sendable {
    case browser(Browser, remember: Bool)
    case picker
}

/// Share requests deliberately ignore auto-open and learning settings. A missing
/// saved browser is an error, not permission to silently choose another browser.
public enum ShareRoutingPolicy {
    public static func route(
        _ request: ShareOpenRequest,
        browsers: [Browser],
        preferences: LinkCompassPreferences
    ) throws -> ShareRoute {
        let identifier: String
        let remember: Bool
        switch request.selection {
        case .browser(let selectedIdentifier, let shouldRemember):
            identifier = selectedIdentifier
            remember = shouldRemember
        case .savedChoice:
            let host = URLNormalizer.normalizedHost(from: request.url)
            let rule = preferences.rules.first { normalizedHost($0.hostPattern) == host }
            guard let savedIdentifier = rule?.browserBundleIdentifier ?? preferences.globalDefaultBrowserBundleIdentifier else {
                return .picker
            }
            identifier = savedIdentifier
            remember = false
        }
        guard KnownBrowser(rawValue: identifier) != nil else {
            throw ShareOpenRequestError.unknownBrowser(identifier)
        }
        guard let browser = browsers.first(where: { $0.bundleIdentifier == identifier }) else {
            throw ShareRoutingError.browserUnavailable(identifier)
        }
        return .browser(browser, remember: remember)
    }

    private static func normalizedHost(_ host: String) -> String {
        var host = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if host.hasSuffix(".") { host.removeLast() }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        return host
    }
}

/// The only persistence seam for Share: after a confirmed launch, opt-in site
/// rules may be saved. No global default, choice event, or pending route is written.
@MainActor
public final class ShareRouter {
    private let ruleStore: RuleStore

    public init(ruleStore: RuleStore) {
        self.ruleStore = ruleStore
    }

    @discardableResult
    public func open(
        _ approvedRequest: ApprovedShareOpenRequest,
        browsers: [Browser],
        launch: (URL, Browser) async throws -> Void
    ) async throws -> ShareRoute {
        let request = approvedRequest.request
        ruleStore.reload()
        let route = try ShareRoutingPolicy.route(request, browsers: browsers, preferences: ruleStore.currentPreferences)
        guard case .browser(let browser, let remember) = route else { return route }
        try await launch(request.url, browser)
        if remember, let host = URLNormalizer.normalizedHost(from: request.url) {
            do {
                try ruleStore.recordChoice(host: host, browserBundleIdentifier: browser.bundleIdentifier)
            } catch {
                throw ShareRoutingError.couldNotSavePreference(error.localizedDescription)
            }
        }
        return route
    }
}
