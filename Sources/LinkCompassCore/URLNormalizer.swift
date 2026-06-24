import Foundation

public enum URLNormalizer {
    public static func normalizedHost(from url: URL) -> String? {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return nil
        }

        guard var host = url.host(percentEncoded: false)?.trimmingCharacters(in: .whitespacesAndNewlines), !host.isEmpty else {
            return nil
        }

        host = host.lowercased()
        if host.hasSuffix(".") {
            host.removeLast()
        }
        if host.hasPrefix("www.") {
            host.removeFirst(4)
        }

        return host.isEmpty ? nil : host
    }
}
