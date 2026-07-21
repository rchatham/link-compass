import Foundation

public protocol EventPersisting: Sendable {
    func load() throws -> [ChoiceEvent]
    func save(_ events: [ChoiceEvent]) throws
    func deleteAll() throws
}

public struct JSONEventStore: EventPersisting {
    public let fileURL: URL
    public let retentionLimit: Int

    public init(fileURL: URL? = nil, retentionLimit: Int = 500) throws {
        self.retentionLimit = retentionLimit
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
        self.fileURL = supportURL.appendingPathComponent("choice-events.json")
    }

    public func load() throws -> [ChoiceEvent] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder.linkCompass.decode([ChoiceEvent].self, from: data)
    }

    public func save(_ events: [ChoiceEvent]) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let retainedEvents = Array(events.suffix(retentionLimit))
        let data = try JSONEncoder.linkCompass.encode(retainedEvents)
        try data.write(to: fileURL, options: [.atomic])
    }

    public func deleteAll() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}

public final class EventStore: @unchecked Sendable {
    private let persistence: EventPersisting

    public init(persistence: EventPersisting) {
        self.persistence = persistence
    }

    public func events() throws -> [ChoiceEvent] {
        try persistence.load()
    }

    public func append(_ event: ChoiceEvent) throws {
        var events = try persistence.load()
        events.append(event)
        try persistence.save(events)
    }

    public func deleteAll() throws {
        try persistence.deleteAll()
    }
}
