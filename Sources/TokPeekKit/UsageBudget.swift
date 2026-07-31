import Foundation

public enum UsageBudgetPeriod: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case day
    case week
    case month

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .day: Localization.string("Daily")
        case .week: Localization.string("Weekly")
        case .month: Localization.string("Monthly")
        }
    }

    fileprivate func dateInterval(
        containing date: Date,
        calendar: Calendar
    ) -> DateInterval? {
        switch self {
        case .day:
            calendar.dateInterval(of: .day, for: date)
        case .week:
            calendar.dateInterval(of: .weekOfYear, for: date)
        case .month:
            calendar.dateInterval(of: .month, for: date)
        }
    }
}

public enum UsageBudgetMetric: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case cost
    case tokens

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .cost: Localization.string("Estimated cost")
        case .tokens: Localization.string("Total tokens")
        }
    }
}

public struct UsageBudget: Codable, Sendable, Equatable, Hashable {
    public static let `default` = UsageBudget(
        isEnabled: false,
        period: .month,
        metric: .cost,
        limit: 50,
        notificationsEnabled: true
    )

    public var isEnabled: Bool
    public var period: UsageBudgetPeriod
    public var metric: UsageBudgetMetric
    public var limit: Double
    public var notificationsEnabled: Bool

    public init(
        isEnabled: Bool,
        period: UsageBudgetPeriod,
        metric: UsageBudgetMetric,
        limit: Double,
        notificationsEnabled: Bool
    ) {
        self.isEnabled = isEnabled
        self.period = period
        self.metric = metric
        self.limit = limit
        self.notificationsEnabled = notificationsEnabled
    }

    public var isActive: Bool {
        isEnabled && limit > 0
    }

    public func analyticsRequest(
        now: Date = Date(),
        calendar: Calendar = .current,
        useEnvironmentRoots: Bool
    ) -> UsageRequest? {
        guard
            isActive,
            let budgetInterval = period.dateInterval(
                containing: now,
                calendar: calendar
            ),
            let monthInterval = calendar.dateInterval(
                of: .month,
                for: now
            )
        else {
            return nil
        }

        // The budget cycle may be daily or weekly, but the same report also
        // powers the month-end forecast. Request the earliest required start
        // so one cached scan can serve both calculations.
        let start = min(budgetInterval.start, monthInterval.start)
        let end = calendar.startOfDay(for: now)

        return UsageRequest(
            since: Self.dateString(start, calendar: calendar),
            until: Self.dateString(end, calendar: calendar),
            useEnvironmentRoots: useEnvironmentRoots
        )
    }

    public func snapshot(
        report: UsageReport,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> UsageBudgetSnapshot? {
        guard
            isActive,
            let budgetInterval = period.dateInterval(
                containing: now,
                calendar: calendar
            ),
            let monthInterval = calendar.dateInterval(
                of: .month,
                for: now
            )
        else {
            return nil
        }

        let datedContributions = report.contributions.compactMap {
            contribution -> (Date, DailyContribution)? in
            guard
                let date = Self.date(
                    contribution.date,
                    calendar: calendar
                )
            else {
                return nil
            }
            return (date, contribution)
        }
        let budgetContributions = datedContributions.filter {
            budgetInterval.contains($0.0)
        }
        let used: Double
        switch metric {
        case .cost:
            used = budgetContributions.reduce(0) {
                $0 + $1.1.totals.cost
            }
        case .tokens:
            used = budgetContributions.reduce(0) {
                $0 + Double($1.1.totals.tokens)
            }
        }

        let monthToDateCost = datedContributions
            .filter { monthInterval.contains($0.0) }
            .reduce(0) { $0 + $1.1.totals.cost }
        let elapsedDays =
            max(
                calendar.dateComponents(
                    [.day],
                    from: monthInterval.start,
                    to: calendar.startOfDay(for: now)
                ).day ?? 0,
                0
            ) + 1
        let totalDays = max(
            calendar.dateComponents(
                [.day],
                from: monthInterval.start,
                to: monthInterval.end
            ).day ?? elapsedDays,
            elapsedDays
        )
        let forecast = MonthlyCostForecast(
            monthToDateCost: monthToDateCost,
            projectedCost:
                monthToDateCost
                * Double(totalDays)
                / Double(max(elapsedDays, 1)),
            elapsedDays: elapsedDays,
            totalDays: totalDays
        )

        return UsageBudgetSnapshot(
            budget: self,
            used: used,
            remaining: max(limit - used, 0),
            progress: used / limit,
            cycleID:
                "\(period.rawValue)|"
                + Self.dateString(
                    budgetInterval.start,
                    calendar: calendar
                )
                + "|\(metric.rawValue)|\(limit.bitPattern)",
            forecast: forecast
        )
    }

    private static func date(
        _ value: String,
        calendar: Calendar
    ) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private static func dateString(
        _ date: Date,
        calendar: Calendar
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

public struct MonthlyCostForecast: Sendable, Equatable {
    public let monthToDateCost: Double
    public let projectedCost: Double
    public let elapsedDays: Int
    public let totalDays: Int
}

public enum UsageBudgetAlertThreshold: Int, Codable, Sendable, Equatable {
    case eightyPercent = 80
    case limitReached = 100
}

public struct UsageBudgetAlertCheckpoint: Codable, Sendable, Equatable {
    public let cycleID: String
    public let threshold: UsageBudgetAlertThreshold

    public init(
        cycleID: String,
        threshold: UsageBudgetAlertThreshold
    ) {
        self.cycleID = cycleID
        self.threshold = threshold
    }
}

public struct UsageBudgetSnapshot: Sendable, Equatable {
    public let budget: UsageBudget
    public let used: Double
    public let remaining: Double
    public let progress: Double
    public let cycleID: String
    public let forecast: MonthlyCostForecast

    public func nextAlert(
        after checkpoint: UsageBudgetAlertCheckpoint?
    ) -> UsageBudgetAlertThreshold? {
        let reachedThreshold: UsageBudgetAlertThreshold?
        if progress >= 1 {
            reachedThreshold = .limitReached
        } else if progress >= 0.8 {
            reachedThreshold = .eightyPercent
        } else {
            reachedThreshold = nil
        }

        guard let reachedThreshold else {
            return nil
        }
        guard
            let checkpoint,
            checkpoint.cycleID == cycleID
        else {
            return reachedThreshold
        }

        return checkpoint.threshold.rawValue < reachedThreshold.rawValue
            ? reachedThreshold
            : nil
    }
}
