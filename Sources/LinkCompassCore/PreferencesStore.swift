import Darwin
import Foundation

public protocol FileLocking: Sendable {
    func withExclusiveAccess<T>(_ body: () throws -> T) throws -> T
}

public protocol PreferencesPersisting: Sendable {
    func load() throws -> LinkCompassPreferences
    func save(_ preferences: LinkCompassPreferences) throws
}

public struct JSONPreferencesStore: PreferencesPersisting, FileLocking {
    public let fileURL: URL
    private let lockURL: URL

    public init(fileURL: URL? = nil) throws {
        if let fileURL {
            self.fileURL = fileURL
            self.lockURL = fileURL.appendingPathExtension("lock")
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
        self.lockURL = supportURL.appendingPathComponent("preferences.json.lock")
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

    public func withExclusiveAccess<T>(_ body: () throws -> T) throws -> T {
        try FileLock.withExclusiveAccess(lockURL: lockURL, body)
    }
}

public enum FileLock {
    public static func withExclusiveAccess<T>(lockURL: URL, _ body: () throws -> T) throws -> T {
        let directoryURL = lockURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let fd = open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard fd >= 0 else {
            throw CocoaError(.fileWriteUnknown)
        }
        defer { close(fd) }
        guard flock(fd, LOCK_EX) == 0 else {
            throw CocoaError(.fileWriteUnknown)
        }
        defer { flock(fd, LOCK_UN) }
        return try body()
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
