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
    public var learningEnabled: Bool
    public var rules: [BrowserChoiceRule]

    public init(
        globalDefaultBrowserBundleIdentifier: String? = nil,
        autoOpenKnownHosts: Bool = false,
        learningEnabled: Bool = false,
        rules: [BrowserChoiceRule] = []
    ) {
        self.globalDefaultBrowserBundleIdentifier = globalDefaultBrowserBundleIdentifier
        self.autoOpenKnownHosts = autoOpenKnownHosts
        self.learningEnabled = learningEnabled
        self.rules = rules
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        globalDefaultBrowserBundleIdentifier = try container.decodeIfPresent(String.self, forKey: .globalDefaultBrowserBundleIdentifier)
        autoOpenKnownHosts = try container.decodeIfPresent(Bool.self, forKey: .autoOpenKnownHosts) ?? false
        learningEnabled = try container.decodeIfPresent(Bool.self, forKey: .learningEnabled) ?? false
        rules = try container.decodeIfPresent([BrowserChoiceRule].self, forKey: .rules) ?? []
    }
}
