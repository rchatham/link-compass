import AppKit
import LinkCompassCore

/// Never use the default scheme handler: multiple development copies may be registered.
enum ContainingAppHandoff {
    static func open(_ request: ShareOpenRequest, completion: @escaping (Result<Void, Error>) -> Void) throws {
        let appURL = try containingApplicationURL()
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open(
            [try request.encodedURL()],
            withApplicationAt: appURL,
            configuration: configuration
        ) { application, error in
            if let error {
                completion(.failure(error))
            } else if application != nil {
                completion(.success(()))
            } else {
                completion(.failure(HandoffError.launchFailed))
            }
        }
    }

    private static func containingApplicationURL() throws -> URL {
        let extensionURL = Bundle.main.bundleURL.resolvingSymlinksInPath().standardizedFileURL
        let pluginsURL = extensionURL.deletingLastPathComponent()
        let contentsURL = pluginsURL.deletingLastPathComponent()
        let appURL = contentsURL.deletingLastPathComponent()
        guard extensionURL.lastPathComponent == "LinkCompassShare.appex",
              Bundle.main.bundleIdentifier == "com.reidchatham.LinkCompass.Share",
              pluginsURL.lastPathComponent == "PlugIns",
              contentsURL.lastPathComponent == "Contents",
              appURL.pathExtension == "app",
              let appBundle = Bundle(url: appURL),
              appBundle.bundleIdentifier == "com.reidchatham.LinkCompass",
              appBundle.object(forInfoDictionaryKey: "CFBundlePackageType") as? String == "APPL",
              appBundle.object(forInfoDictionaryKey: "CFBundleExecutable") as? String == "LinkCompass",
              let executableURL = appBundle.executableURL,
              executableURL.resolvingSymlinksInPath().deletingLastPathComponent()
                == contentsURL.appendingPathComponent("MacOS", isDirectory: true),
              FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw HandoffError.invalidContainer
        }
        return appURL
    }
}

private enum HandoffError: LocalizedError {
    case invalidContainer
    case launchFailed

    var errorDescription: String? {
        switch self {
        case .invalidContainer:
            return "The containing LinkCompass app could not be verified. Reinstall the complete app bundle."
        case .launchFailed:
            return "LinkCompass could not receive this link. Try again."
        }
    }
}
