import Foundation

public struct ChoiceEvent: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let normalizedHost: String?
    public let chosenBrowserBundleIdentifier: String
    public let preselectedBrowserBundleIdentifier: String?
    public let wasOverride: Bool
    public let hourOfDay: Int
    public let weekday: Int
    public let isFileURL: Bool

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        normalizedHost: String?,
        chosenBrowserBundleIdentifier: String,
        preselectedBrowserBundleIdentifier: String?,
        wasOverride: Bool,
        hourOfDay: Int,
        weekday: Int,
        isFileURL: Bool
    ) {
        self.id = id
        self.createdAt = createdAt
        self.normalizedHost = normalizedHost
        self.chosenBrowserBundleIdentifier = chosenBrowserBundleIdentifier
        self.preselectedBrowserBundleIdentifier = preselectedBrowserBundleIdentifier
        self.wasOverride = wasOverride
        self.hourOfDay = hourOfDay
        self.weekday = weekday
        self.isFileURL = isFileURL
    }

    public init(
        url: URL,
        chosenBrowserBundleIdentifier: String,
        preselectedBrowserBundleIdentifier: String?,
        calendar: Calendar = .current,
        date: Date = Date()
    ) {
        let normalizedHost = URLNormalizer.normalizedHost(from: url)
        let hourOfDay = calendar.component(.hour, from: date)
        let weekday = calendar.component(.weekday, from: date)
        self.init(
            createdAt: date,
            normalizedHost: normalizedHost,
            chosenBrowserBundleIdentifier: chosenBrowserBundleIdentifier,
            preselectedBrowserBundleIdentifier: preselectedBrowserBundleIdentifier,
            wasOverride: preselectedBrowserBundleIdentifier != nil && preselectedBrowserBundleIdentifier != chosenBrowserBundleIdentifier,
            hourOfDay: hourOfDay,
            weekday: weekday,
            isFileURL: url.isFileURL
        )
    }
}
