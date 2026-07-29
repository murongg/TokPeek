import Foundation

public struct UsageReport: Decodable, Sendable, Equatable {
    public let meta: ReportMetadata
    public let summary: UsageSummary
    public let years: [YearSummary]
    public let contributions: [DailyContribution]
    public let hourlyContributions: [HourlyContribution]

    public init(
        meta: ReportMetadata,
        summary: UsageSummary,
        years: [YearSummary],
        contributions: [DailyContribution],
        hourlyContributions: [HourlyContribution] = []
    ) {
        self.meta = meta
        self.summary = summary
        self.years = years
        self.contributions = contributions
        self.hourlyContributions = hourlyContributions
    }

    private enum CodingKeys: String, CodingKey {
        case meta
        case summary
        case years
        case contributions
        case hourlyContributions
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        meta = try container.decode(
            ReportMetadata.self,
            forKey: .meta
        )
        summary = try container.decode(
            UsageSummary.self,
            forKey: .summary
        )
        years = try container.decode(
            [YearSummary].self,
            forKey: .years
        )
        contributions = try container.decode(
            [DailyContribution].self,
            forKey: .contributions
        )
        hourlyContributions =
            try container.decodeIfPresent(
                [HourlyContribution].self,
                forKey: .hourlyContributions
            ) ?? []
    }

    public var latestContribution: DailyContribution? {
        contributions.max { $0.date < $1.date }
    }
}

public struct ReportMetadata: Decodable, Sendable, Equatable {
    public let generatedAt: String
    public let version: String
    public let dateRangeStart: String
    public let dateRangeEnd: String
    public let processingTimeMs: UInt32
}

public struct UsageSummary: Decodable, Sendable, Equatable {
    public let totalTokens: Int64
    public let totalCost: Double
    public let totalDays: Int
    public let activeDays: Int
    public let averagePerDay: Double
    public let maxCostInSingleDay: Double
    public let clients: [String]
    public let models: [String]
}

public struct YearSummary: Decodable, Sendable, Equatable {
    public let year: String
    public let totalTokens: Int64
    public let totalCost: Double
    public let rangeStart: String
    public let rangeEnd: String
}

public struct DailyContribution: Decodable, Sendable, Equatable, Identifiable {
    public var id: String { date }

    public let date: String
    public let totals: DailyTotals
    public let intensity: UInt8
    public let tokenBreakdown: TokenBreakdown
    public let clients: [ClientContribution]
    public let activeTimeMs: Int64?
}

public struct HourlyContribution: Decodable, Sendable, Equatable, Identifiable {
    public var id: String { hour }

    public let hour: String
    public let totals: DailyTotals
    public let tokenBreakdown: TokenBreakdown
    public let clients: [ClientContribution]

    public init(
        hour: String,
        totals: DailyTotals,
        tokenBreakdown: TokenBreakdown,
        clients: [ClientContribution]
    ) {
        self.hour = hour
        self.totals = totals
        self.tokenBreakdown = tokenBreakdown
        self.clients = clients
    }
}

public struct DailyTotals: Decodable, Sendable, Equatable {
    public let tokens: Int64
    public let cost: Double
    public let messages: Int
}

public struct TokenBreakdown: Decodable, Sendable, Equatable {
    public let input: Int64
    public let output: Int64
    public let cacheRead: Int64
    public let cacheWrite: Int64
    public let reasoning: Int64
}

public struct ClientContribution: Decodable, Sendable, Equatable, Identifiable {
    public var id: String {
        "\(client)|\(providerId)|\(modelId)"
    }

    public let client: String
    public let modelId: String
    public let providerId: String
    public let tokens: TokenBreakdown
    public let cost: Double
    public let messages: Int
}
