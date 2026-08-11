import Foundation

public struct PendingRoute: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let nonce: String
    public let normalizedHost: String
    public let browserBundleIdentifier: String
    public let browserDisplayName: String
    public let createdAt: Date
    public let expiresAt: Date

    public init(
        id: UUID = UUID(),
        nonce: String = UUID().uuidString,
        normalizedHost: String,
        browserBundleIdentifier: String,
        browserDisplayName: String,
        createdAt: Date = Date(),
        expiresAt: Date
    ) {
        self.id = id
        self.nonce = nonce
        self.normalizedHost = normalizedHost
        self.browserBundleIdentifier = browserBundleIdentifier
        self.browserDisplayName = browserDisplayName
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }
}

public protocol PendingRoutePersisting: Sendable {
    func load() throws -> [PendingRoute]
    func save(_ routes: [PendingRoute]) throws
}

public struct JSONPendingRoutePersistence: PendingRoutePersisting, FileLocking {
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
        self.fileURL = supportURL.appendingPathComponent("pending-routes.json")
        self.lockURL = supportURL.appendingPathComponent("pending-routes.json.lock")
    }

    public func load() throws -> [PendingRoute] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder.linkCompass.decode([PendingRoute].self, from: data)
    }

    public func save(_ routes: [PendingRoute]) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try JSONEncoder.linkCompass.encode(routes)
        try data.write(to: fileURL, options: [.atomic])
    }

    public func withExclusiveAccess<T>(_ body: () throws -> T) throws -> T {
        try FileLock.withExclusiveAccess(lockURL: lockURL, body)
    }
}

public final class PendingRouteStore: @unchecked Sendable {
    private let persistence: PendingRoutePersisting
    private let routeLifetime: TimeInterval
    private let maximumRoutes: Int

    public init(
        persistence: PendingRoutePersisting,
        routeLifetime: TimeInterval = 5 * 60,
        maximumRoutes: Int = 100
    ) {
        self.persistence = persistence
        self.routeLifetime = routeLifetime
        self.maximumRoutes = maximumRoutes
    }

    @discardableResult
    public func recordRoute(
        url: URL,
        browserBundleIdentifier: String,
        browserDisplayName: String,
        date: Date = Date()
    ) throws -> PendingRoute? {
        guard let normalizedHost = URLNormalizer.normalizedHost(from: url) else { return nil }
        return try withPersistenceLock {
            let route = PendingRoute(
                normalizedHost: normalizedHost,
                browserBundleIdentifier: browserBundleIdentifier,
                browserDisplayName: browserDisplayName,
                createdAt: date,
                expiresAt: date.addingTimeInterval(routeLifetime)
            )
            var routes = try unexpiredRoutes(at: date)
            routes.append(route)
            routes = Array(routes.suffix(maximumRoutes))
            try persistence.save(routes)
            return route
        }
    }

    public func recentRoute(for url: URL, date: Date = Date()) throws -> PendingRoute? {
        guard let normalizedHost = URLNormalizer.normalizedHost(from: url) else { return nil }
        return try recentRoute(forNormalizedHost: normalizedHost, date: date)
    }

    public func recentRoute(forNormalizedHost normalizedHost: String, date: Date = Date()) throws -> PendingRoute? {
        try withPersistenceLock {
            let originalRoutes = try persistence.load()
            let routes = originalRoutes.filter { $0.expiresAt > date }
            if routes.count != originalRoutes.count {
                try persistence.save(routes)
            }
            return routes.last { $0.normalizedHost == normalizedHost }
        }
    }

    public func pruneExpired(date: Date = Date()) throws {
        try withPersistenceLock {
            try persistence.save(unexpiredRoutes(at: date))
        }
    }

    private func unexpiredRoutes(at date: Date) throws -> [PendingRoute] {
        try persistence.load().filter { $0.expiresAt > date }
    }

    private func withPersistenceLock<T>(_ body: () throws -> T) throws -> T {
        if let fileLockingPersistence = persistence as? FileLocking {
            return try fileLockingPersistence.withExclusiveAccess(body)
        }
        return try body()
    }
}
