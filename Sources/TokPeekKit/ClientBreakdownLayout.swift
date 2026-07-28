import Foundation

public struct ClientUsageSlice: Identifiable, Sendable, Equatable {
    public var id: String {
        isOther ? "other" : "client:\(client)"
    }

    public let client: String
    public let tokens: Int64
    public let cost: Double
    public let messages: Int
    public let fraction: Double
    public let isOther: Bool
}

public struct ClientBreakdownLayout: Sendable, Equatable {
    public let slices: [ClientUsageSlice]
    public let totalTokens: Int64

    public init(
        summaries: [ClientUsageSummary]
    ) {
        let ranked =
            summaries
            .filter { $0.tokens > 0 }
            .sorted {
                if $0.tokens == $1.tokens {
                    return $0.client < $1.client
                }
                return $0.tokens > $1.tokens
            }
        totalTokens = ranked.reduce(0) {
            Self.saturatingAdd($0, $1.tokens)
        }

        let visible: [(summary: ClientUsageSummary, isOther: Bool)]
        if ranked.count > 5 {
            let major = ranked.prefix(4).map { ($0, false) }
            let remaining = ranked.dropFirst(4)
            let other = ClientUsageSummary(
                client: "other",
                tokens: remaining.reduce(0) {
                    Self.saturatingAdd($0, $1.tokens)
                },
                cost: remaining.reduce(0) { $0 + $1.cost },
                messages: remaining.reduce(0) {
                    Self.saturatingAdd($0, $1.messages)
                }
            )
            visible = major + [(other, true)]
        } else {
            visible = ranked.map { ($0, false) }
        }

        let fractionTotal = visible.reduce(0.0) {
            $0 + Double($1.summary.tokens)
        }
        slices = visible.map { item in
            ClientUsageSlice(
                client: item.summary.client,
                tokens: item.summary.tokens,
                cost: item.summary.cost,
                messages: item.summary.messages,
                fraction: fractionTotal > 0
                    ? Double(item.summary.tokens) / fractionTotal
                    : 0,
                isOther: item.isOther
            )
        }
    }

    public func slice(
        atFraction fraction: Double
    ) -> ClientUsageSlice? {
        guard fraction >= 0, fraction < 1 else {
            return nil
        }

        var upperBound = 0.0
        for slice in slices {
            upperBound += slice.fraction
            if fraction < upperBound {
                return slice
            }
        }

        return slices.last
    }

    private static func saturatingAdd(
        _ left: Int64,
        _ right: Int64
    ) -> Int64 {
        let (value, overflow) = left.addingReportingOverflow(right)
        return overflow ? .max : value
    }

    private static func saturatingAdd(
        _ left: Int,
        _ right: Int
    ) -> Int {
        let (value, overflow) = left.addingReportingOverflow(right)
        return overflow ? .max : value
    }
}
