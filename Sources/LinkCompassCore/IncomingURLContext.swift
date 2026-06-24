import Foundation

public struct IncomingURLContext: Equatable, Sendable {
    public let displayTitle: String
    public let rememberHost: String?
    public let supportsDomainRules: Bool

    public init?(url: URL) {
        if let host = URLNormalizer.normalizedHost(from: url) {
            self.displayTitle = host
            self.rememberHost = host
            self.supportsDomainRules = true
            return
        }

        guard url.isFileURL else { return nil }
        let fileName = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
        self.displayTitle = fileName
        self.rememberHost = nil
        self.supportsDomainRules = false
    }
}
