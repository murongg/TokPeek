import Foundation

public struct UsageRequest: Codable, Sendable, Equatable {
    public var homeDirectory: String?
    public var clients: [String]?
    public var since: String?
    public var until: String?
    public var year: String?
    public var useEnvironmentRoots: Bool

    public init(
        homeDirectory: String? = nil,
        clients: [String]? = nil,
        since: String? = nil,
        until: String? = nil,
        year: String? = nil,
        useEnvironmentRoots: Bool = false
    ) {
        self.homeDirectory = homeDirectory
        self.clients = clients
        self.since = since
        self.until = until
        self.year = year
        self.useEnvironmentRoots = useEnvironmentRoots
    }
}
