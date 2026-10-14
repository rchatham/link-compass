import Foundation

public enum ShareRequestOrigin: Sendable {
    case wire
    case localPicker
}

public enum ShareRememberConsent: Sendable {
    case openOnce
    case openAndRemember
    case cancel
}

/// A decoded URL is untrusted. Only the containing app's own UI can approve
/// remembering; keep that approved intent distinct from the wire request.
public struct ApprovedShareOpenRequest: Equatable, Sendable {
    public let request: ShareOpenRequest

    fileprivate init(request: ShareOpenRequest) {
        self.request = request
    }
}

public enum ShareConsentPolicy {
    public static func requiresConfirmation(_ request: ShareOpenRequest, origin: ShareRequestOrigin) -> Bool {
        guard case .wire = origin,
              case .browser(_, let remember) = request.selection else { return false }
        return remember
    }

    public static func approve(
        _ request: ShareOpenRequest,
        origin: ShareRequestOrigin,
        consent: ShareRememberConsent = .openOnce
    ) throws -> ApprovedShareOpenRequest? {
        guard consent != .cancel else { return nil }
        switch request.selection {
        case .savedChoice:
            return ApprovedShareOpenRequest(request: request)
        case .browser(let identifier, let requestedRemember):
            let remember = requestedRemember && (origin == .localPicker || consent == .openAndRemember)
            let approved = try ShareOpenRequest(url: request.url, selection: .browser(bundleIdentifier: identifier, remember: remember))
            return ApprovedShareOpenRequest(request: approved)
        }
    }
}
