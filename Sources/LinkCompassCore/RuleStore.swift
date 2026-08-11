import Foundation

public final class RuleStore: @unchecked Sendable {
    private let persistence: PreferencesPersisting
    private var preferences: LinkCompassPreferences

    public init(persistence: PreferencesPersisting) {
        self.persistence = persistence
        self.preferences = (try? persistence.load()) ?? LinkCompassPreferences()
    }

    public var currentPreferences: LinkCompassPreferences { preferences }

    public var globalDefaultBrowserBundleIdentifier: String? {
        get { preferences.globalDefaultBrowserBundleIdentifier }
        set {
            mutateIgnoringErrors {
                preferences.globalDefaultBrowserBundleIdentifier = newValue
            }
        }
    }

    public var autoOpenKnownHosts: Bool {
        get { preferences.autoOpenKnownHosts }
        set {
            mutateIgnoringErrors {
                preferences.autoOpenKnownHosts = newValue
            }
        }
    }

    public var learningEnabled: Bool {
        get { preferences.learningEnabled }
        set {
            mutateIgnoringErrors {
                preferences.learningEnabled = newValue
            }
        }
    }

    public func domainRuleBrowserBundleIdentifier(forHost host: String) -> String? {
        let normalized = normalizeStoredHost(host)
        return preferences.rules.first { rule in
            normalizeStoredHost(rule.hostPattern) == normalized
        }?.browserBundleIdentifier
    }

    public func preferredBrowserBundleIdentifier(forHost host: String) -> String? {
        domainRuleBrowserBundleIdentifier(forHost: host) ?? preferences.globalDefaultBrowserBundleIdentifier
    }

    public func recordChoice(host: String, browserBundleIdentifier: String) throws {
        try mutatePreferences {
            let normalized = normalizeStoredHost(host)
            if let index = preferences.rules.firstIndex(where: { normalizeStoredHost($0.hostPattern) == normalized }) {
                preferences.rules[index].browserBundleIdentifier = browserBundleIdentifier
                preferences.rules[index].usageCount += 1
                preferences.rules[index].updatedAt = Date()
            } else {
                preferences.rules.append(
                    BrowserChoiceRule(
                        hostPattern: normalized,
                        browserBundleIdentifier: browserBundleIdentifier,
                        usageCount: 1
                    )
                )
            }
        }
    }

    public func deleteRule(id: UUID) throws {
        try mutatePreferences {
            preferences.rules.removeAll { $0.id == id }
        }
    }

    public func reload() {
        preferences = (try? persistence.load()) ?? LinkCompassPreferences()
    }

    private func mutateIgnoringErrors(_ mutation: () -> Void) {
        try? mutatePreferences(mutation)
    }

    private func mutatePreferences(_ mutation: () -> Void) throws {
        try withPersistenceLock {
            preferences = try persistence.load()
            mutation()
            try persistence.save(preferences)
        }
    }

    private func withPersistenceLock<T>(_ body: () throws -> T) throws -> T {
        if let fileLockingPersistence = persistence as? FileLocking {
            return try fileLockingPersistence.withExclusiveAccess(body)
        }
        return try body()
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
