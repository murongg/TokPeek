import Foundation

public struct TokenComposition: Sendable, Equatable {
    public let input: Int64
    public let output: Int64
    public let cache: Int64
    public let reasoning: Int64

    public var total: Int64 {
        input
            .saturatingAdd(output)
            .saturatingAdd(cache)
            .saturatingAdd(reasoning)
    }
}

public struct ClientUsageSummary: Identifiable, Sendable, Equatable {
    public var id: String { client }

    public let client: String
    public let tokens: Int64
    public let cost: Double
    public let messages: Int
}

public struct ModelUsageSummary: Identifiable, Sendable, Equatable {
    public var id: String {
        "\(providerId)|\(modelId)"
    }

    public let modelId: String
    public let providerId: String
    public let tokens: Int64
    public let cost: Double
    public let messages: Int
}

public enum ModelRankingLayout {
    public static let columnCount = 2
    public static let maximumVisibleItems = 8
}

extension TokenBreakdown {
    public var totalTokens: Int64 {
        input
            .saturatingAdd(output)
            .saturatingAdd(cacheRead)
            .saturatingAdd(cacheWrite)
            .saturatingAdd(reasoning)
    }
}

extension UsageReport {
    public var modelFilterOptions: [String] {
        Array(
            Set(
                summary.models.filter { modelId in
                    let value = modelId.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    // Tokscale reserves angle-bracketed IDs for internal
                    // records such as <synthetic>, not selectable models.
                    return !value.isEmpty
                        && !(value.hasPrefix("<") && value.hasSuffix(">"))
                }
            )
        ).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    public func filtered(
        modelId: String
    ) -> UsageReport {
        var filteredContributions = contributions.map { day in
            let clients = day.clients.forModel(modelId)
            let tokenBreakdown = clients.combinedTokenBreakdown

            return DailyContribution(
                date: day.date,
                totals: clients.combinedTotals,
                intensity: 0,
                tokenBreakdown: tokenBreakdown,
                clients: clients,
                // Tokscale reports active time per day, not per model.
                // Keeping it would incorrectly attribute the whole day.
                activeTimeMs: nil
            )
        }

        let maxCost =
            filteredContributions
            .map(\.totals.cost)
            .max()
            ?? 0
        if maxCost > 0 {
            filteredContributions = filteredContributions.map { day in
                let ratio = day.totals.cost / maxCost
                let intensity: UInt8
                if ratio >= 0.75 {
                    intensity = 4
                } else if ratio >= 0.5 {
                    intensity = 3
                } else if ratio >= 0.25 {
                    intensity = 2
                } else if ratio > 0 {
                    intensity = 1
                } else {
                    intensity = 0
                }

                return DailyContribution(
                    date: day.date,
                    totals: day.totals,
                    intensity: intensity,
                    tokenBreakdown: day.tokenBreakdown,
                    clients: day.clients,
                    activeTimeMs: day.activeTimeMs
                )
            }
        }

        let filteredHourlyContributions = hourlyContributions.map { hour in
            let clients = hour.clients.forModel(modelId)
            return HourlyContribution(
                hour: hour.hour,
                totals: clients.combinedTotals,
                tokenBreakdown: clients.combinedTokenBreakdown,
                clients: clients
            )
        }

        let totalTokens = filteredContributions.reduce(Int64(0)) {
            $0.saturatingAdd($1.totals.tokens)
        }
        let totalCost = filteredContributions.reduce(0) {
            $0 + $1.totals.cost
        }
        let activeDays = filteredContributions.filter {
            $0.totals.tokens > 0
                || $0.totals.cost > 0
                || $0.totals.messages > 0
        }.count
        let clients = Set(
            filteredContributions
                .flatMap(\.clients)
                .map(\.client)
        ).sorted()
        let models = Set(
            filteredContributions
                .flatMap(\.clients)
                .map(\.modelId)
        ).sorted()

        struct YearAggregate {
            var tokens: Int64 = 0
            var cost = 0.0
            var start = ""
            var end = ""
        }

        var yearAggregates: [String: YearAggregate] = [:]
        for contribution in filteredContributions
        where contribution.date.count >= 4 {
            let year = String(contribution.date.prefix(4))
            var aggregate = yearAggregates[year] ?? YearAggregate()
            aggregate.tokens = aggregate.tokens.saturatingAdd(
                contribution.totals.tokens
            )
            aggregate.cost += contribution.totals.cost
            if aggregate.start.isEmpty
                || contribution.date < aggregate.start
            {
                aggregate.start = contribution.date
            }
            if aggregate.end.isEmpty
                || contribution.date > aggregate.end
            {
                aggregate.end = contribution.date
            }
            yearAggregates[year] = aggregate
        }

        let years = yearAggregates.map { year, aggregate in
            YearSummary(
                year: year,
                totalTokens: aggregate.tokens,
                totalCost: aggregate.cost,
                rangeStart: aggregate.start,
                rangeEnd: aggregate.end
            )
        }.sorted { $0.year < $1.year }

        return UsageReport(
            meta: meta,
            summary: UsageSummary(
                totalTokens: totalTokens,
                totalCost: totalCost,
                totalDays: filteredContributions.count,
                activeDays: activeDays,
                averagePerDay: activeDays > 0
                    ? totalCost / Double(activeDays)
                    : 0,
                maxCostInSingleDay: maxCost,
                clients: clients,
                models: models
            ),
            years: years,
            contributions: filteredContributions,
            hourlyContributions: filteredHourlyContributions
        )
    }

    public var tokenComposition: TokenComposition {
        contributions.reduce(
            into: TokenComposition(
                input: 0,
                output: 0,
                cache: 0,
                reasoning: 0
            )
        ) { result, day in
            result = TokenComposition(
                input: result.input.saturatingAdd(day.tokenBreakdown.input),
                output: result.output.saturatingAdd(day.tokenBreakdown.output),
                cache: result.cache
                    .saturatingAdd(day.tokenBreakdown.cacheRead)
                    .saturatingAdd(day.tokenBreakdown.cacheWrite),
                reasoning: result.reasoning.saturatingAdd(
                    day.tokenBreakdown.reasoning
                )
            )
        }
    }

    public var clientSummaries: [ClientUsageSummary] {
        struct Aggregate {
            var tokens: Int64 = 0
            var cost = 0.0
            var messages = 0
        }

        var aggregates: [String: Aggregate] = [:]
        for contribution in contributions.flatMap(\.clients) {
            var aggregate = aggregates[contribution.client] ?? Aggregate()
            aggregate.tokens = aggregate.tokens.saturatingAdd(
                contribution.tokens.totalTokens
            )
            aggregate.cost += contribution.cost
            aggregate.messages += contribution.messages
            aggregates[contribution.client] = aggregate
        }

        return
            aggregates
            .map { client, aggregate in
                ClientUsageSummary(
                    client: client,
                    tokens: aggregate.tokens,
                    cost: aggregate.cost,
                    messages: aggregate.messages
                )
            }
            .sorted {
                if $0.tokens == $1.tokens {
                    return $0.client < $1.client
                }
                return $0.tokens > $1.tokens
            }
    }

    public var modelSummaries: [ModelUsageSummary] {
        struct Key: Hashable {
            let modelId: String
            let providerId: String
        }

        struct Aggregate {
            var tokens: Int64 = 0
            var cost = 0.0
            var messages = 0
        }

        var aggregates: [Key: Aggregate] = [:]
        for contribution in contributions.flatMap(\.clients) {
            let key = Key(
                modelId: contribution.modelId,
                providerId: contribution.providerId
            )
            var aggregate = aggregates[key] ?? Aggregate()
            aggregate.tokens = aggregate.tokens.saturatingAdd(
                contribution.tokens.totalTokens
            )
            aggregate.cost += contribution.cost
            aggregate.messages += contribution.messages
            aggregates[key] = aggregate
        }

        return
            aggregates
            .map { key, aggregate in
                ModelUsageSummary(
                    modelId: key.modelId,
                    providerId: key.providerId,
                    tokens: aggregate.tokens,
                    cost: aggregate.cost,
                    messages: aggregate.messages
                )
            }
            .sorted {
                if $0.tokens != $1.tokens {
                    return $0.tokens > $1.tokens
                }
                if $0.modelId != $1.modelId {
                    return $0.modelId < $1.modelId
                }
                return $0.providerId < $1.providerId
            }
    }
}

private extension Array where Element == ClientContribution {
    func forModel(
        _ modelId: String
    ) -> [ClientContribution] {
        filter { $0.modelId == modelId }
    }

    var combinedTokenBreakdown: TokenBreakdown {
        reduce(
            TokenBreakdown(
                input: 0,
                output: 0,
                cacheRead: 0,
                cacheWrite: 0,
                reasoning: 0
            )
        ) { result, contribution in
            TokenBreakdown(
                input: result.input.saturatingAdd(
                    contribution.tokens.input
                ),
                output: result.output.saturatingAdd(
                    contribution.tokens.output
                ),
                cacheRead: result.cacheRead.saturatingAdd(
                    contribution.tokens.cacheRead
                ),
                cacheWrite: result.cacheWrite.saturatingAdd(
                    contribution.tokens.cacheWrite
                ),
                reasoning: result.reasoning.saturatingAdd(
                    contribution.tokens.reasoning
                )
            )
        }
    }

    var combinedTotals: DailyTotals {
        DailyTotals(
            tokens: combinedTokenBreakdown.totalTokens,
            cost: reduce(0) { $0 + $1.cost },
            messages: reduce(0) { $0 + $1.messages }
        )
    }
}

extension Int64 {
    fileprivate func saturatingAdd(_ other: Int64) -> Int64 {
        let (value, overflow) = addingReportingOverflow(other)
        guard overflow else {
            return value
        }
        return other >= 0 ? .max : .min
    }
}
