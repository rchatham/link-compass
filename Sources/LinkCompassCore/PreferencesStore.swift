import Foundation

public protocol PreferencesPersisting: Sendable {
    func load() throws -> LinkCompassPreferences
    func save(_ preferences: LinkCompassPreferences) throws
}

public struct JSONPreferencesStore: PreferencesPersisting {
    public let fileURL: URL

    public init(fileURL: URL? = nil) throws {
        if let fileURL {
            self.fileURL = fileURL
            return
        }

        let supportURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("LinkCompass", isDirectory: true)

        try FileManager.default.createDirectory(at: supportURL, withIntermediateDirectories: true)
        self.fileURL = supportURL.appendingPathComponent("preferences.json")
    }

    public func load() throws -> LinkCompassPreferences {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return LinkCompassPreferences()
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder.linkCompass.decode(LinkCompassPreferences.self, from: data)
    }

    public func save(_ preferences: LinkCompassPreferences) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try JSONEncoder.linkCompass.encode(preferences)
        try data.write(to: fileURL, options: [.atomic])
    }
}

extension JSONEncoder {
    static var linkCompass: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var linkCompass: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
