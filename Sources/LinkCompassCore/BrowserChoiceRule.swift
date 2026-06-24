import Foundation

public struct BrowserChoiceRule: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let hostPattern: String
    public var browserBundleIdentifier: String
    public let createdAt: Date
    public var updatedAt: Date
    public var usageCount: Int

    public init(
        id: UUID = UUID(),
        hostPattern: String,
        browserBundleIdentifier: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        usageCount: Int = 0
    ) {
        self.id = id
        self.hostPattern = hostPattern
        self.browserBundleIdentifier = browserBundleIdentifier
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.usageCount = usageCount
    }
}

public struct LinkCompassPreferences: Codable, Equatable, Sendable {
    public var globalDefaultBrowserBundleIdentifier: String?
    public var autoOpenKnownHosts: Bool
    public var rules: [BrowserChoiceRule]

    public init(
        globalDefaultBrowserBundleIdentifier: String? = nil,
        autoOpenKnownHosts: Bool = false,
        rules: [BrowserChoiceRule] = []
    ) {
        self.globalDefaultBrowserBundleIdentifier = globalDefaultBrowserBundleIdentifier
        self.autoOpenKnownHosts = autoOpenKnownHosts
        self.rules = rules
    }
}
