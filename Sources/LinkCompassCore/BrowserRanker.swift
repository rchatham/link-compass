import Foundation

public struct RankingContext: Equatable, Sendable {
    public let rememberHost: String?
    public let supportsDomainRules: Bool

    public init(rememberHost: String?, supportsDomainRules: Bool) {
        self.rememberHost = rememberHost
        self.supportsDomainRules = supportsDomainRules
    }

    public init(incomingURLContext: IncomingURLContext) {
        self.init(
            rememberHost: incomingURLContext.rememberHost,
            supportsDomainRules: incomingURLContext.supportsDomainRules
        )
    }
}

public struct RankedBrowser: Equatable, Sendable {
    public let browser: Browser
    public let isPreferred: Bool
    public let isPreferenceBacked: Bool

    public init(browser: Browser, isPreferred: Bool, isPreferenceBacked: Bool) {
        self.browser = browser
        self.isPreferred = isPreferred
        self.isPreferenceBacked = isPreferenceBacked
    }
}

public protocol BrowserRanking: Sendable {
    func rankedBrowsers(
        browsers: [Browser],
        context: RankingContext,
        preferences: LinkCompassPreferences
    ) -> [RankedBrowser]

    func autoOpenBrowser(
        browsers: [Browser],
        context: RankingContext,
        preferences: LinkCompassPreferences
    ) -> Browser?
}

public struct RuleBasedRanker: BrowserRanking {
    public init() {}

    public func rankedBrowsers(
        browsers: [Browser],
        context: RankingContext,
        preferences: LinkCompassPreferences
    ) -> [RankedBrowser] {
        guard !browsers.isEmpty else { return [] }
        let preferenceBackedBundleIdentifier = preferredBundleIdentifier(context: context, preferences: preferences)
        let selectedBundleIdentifier = preferenceBackedBundleIdentifier ?? browsers.first?.bundleIdentifier

        return browsers.map { browser in
            RankedBrowser(
                browser: browser,
                isPreferred: browser.bundleIdentifier == selectedBundleIdentifier,
                isPreferenceBacked: browser.bundleIdentifier == preferenceBackedBundleIdentifier
            )
        }
    }

    public func autoOpenBrowser(
        browsers: [Browser],
        context: RankingContext,
        preferences: LinkCompassPreferences
    ) -> Browser? {
        guard context.supportsDomainRules,
              preferences.autoOpenKnownHosts,
              let host = context.rememberHost,
              let bundleIdentifier = domainRuleBrowserBundleIdentifier(forHost: host, preferences: preferences) else {
            return nil
        }
        return browsers.first { $0.bundleIdentifier == bundleIdentifier }
    }

    private func preferredBundleIdentifier(
        context: RankingContext,
        preferences: LinkCompassPreferences
    ) -> String? {
        guard let host = context.rememberHost else { return nil }
        return domainRuleBrowserBundleIdentifier(forHost: host, preferences: preferences)
            ?? preferences.globalDefaultBrowserBundleIdentifier
    }

    private func domainRuleBrowserBundleIdentifier(
        forHost host: String,
        preferences: LinkCompassPreferences
    ) -> String? {
        let normalized = normalizeStoredHost(host)
        return preferences.rules.first { rule in
            normalizeStoredHost(rule.hostPattern) == normalized
        }?.browserBundleIdentifier
    }

    private func normalizeStoredHost(_ host: String) -> String {
        var normalized = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.hasSuffix(".") {
            normalized.removeLast()
        }
        if normalized.hasPrefix("www.") {
            normalized.removeFirst(4)
        }
        return normalized
    }
}
