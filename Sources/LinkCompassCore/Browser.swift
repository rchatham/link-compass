import Foundation

public struct Browser: Codable, Equatable, Identifiable, Sendable {
    public var id: String { bundleIdentifier }

    public let displayName: String
    public let bundleIdentifier: String
    public let appURL: URL

    public init(displayName: String, bundleIdentifier: String, appURL: URL) {
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
        self.appURL = appURL
    }
}

public enum KnownBrowser: String, CaseIterable, Sendable {
    case safari = "com.apple.Safari"
    case googleChrome = "com.google.Chrome"
    case chromium = "org.chromium.Chromium"
    case brave = "com.brave.Browser"
    case firefox = "org.mozilla.firefox"
    case duckDuckGo = "com.duckduckgo.macos.browser"
    case microsoftEdge = "com.microsoft.edgemac"

    public var displayName: String {
        switch self {
        case .safari: "Safari"
        case .googleChrome: "Google Chrome"
        case .chromium: "Chromium"
        case .brave: "Brave Browser"
        case .firefox: "Firefox"
        case .duckDuckGo: "DuckDuckGo Browser"
        case .microsoftEdge: "Microsoft Edge"
        }
    }
}
