import Foundation

public struct UsageRequest: Codable, Sendable, Equatable {
    public var homeDirectory: String?
    public var clients: [String]?
    public var since: String?
    public var until: String?
    public var year: String?
    public var hourly: Bool
    public var startTimeMs: Int64?
    public var endTimeMs: Int64?
    public var useEnvironmentRoots: Bool

    public init(
        homeDirectory: String? = nil,
        clients: [String]? = nil,
        since: String? = nil,
        until: String? = nil,
        year: String? = nil,
        hourly: Bool = false,
        startTimeMs: Int64? = nil,
        endTimeMs: Int64? = nil,
        useEnvironmentRoots: Bool = false
    ) {
        self.homeDirectory = homeDirectory
        self.clients = clients
        self.since = since
        self.until = until
        self.year = year
        self.hourly = hourly
        self.startTimeMs = startTimeMs
        self.endTimeMs = endTimeMs
        self.useEnvironmentRoots = useEnvironmentRoots
    }
}
