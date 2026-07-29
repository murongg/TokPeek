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

    public func previousPeriod(
        calendar: Calendar = .current
    ) -> UsageRequest? {
        if hourly {
            return previousHourlyPeriod(calendar: calendar)
        }

        guard
            let since,
            let until,
            let start = Self.date(
                from: since,
                calendar: calendar
            ),
            let end = Self.date(
                from: until,
                calendar: calendar
            ),
            start <= end,
            let dayCount = calendar.dateComponents(
                [.day],
                from: start,
                to: end
            ).day.map({ $0 + 1 }),
            let previousEnd = calendar.date(
                byAdding: .day,
                value: -1,
                to: start
            ),
            let previousStart = calendar.date(
                byAdding: .day,
                value: -(dayCount - 1),
                to: previousEnd
            )
        else {
            return nil
        }

        return UsageRequest(
            homeDirectory: homeDirectory,
            clients: clients,
            since: Self.string(
                from: previousStart,
                calendar: calendar
            ),
            until: Self.string(
                from: previousEnd,
                calendar: calendar
            ),
            useEnvironmentRoots: useEnvironmentRoots
        )
    }

    private func previousHourlyPeriod(
        calendar: Calendar
    ) -> UsageRequest? {
        guard
            let startTimeMs,
            let endTimeMs,
            endTimeMs > startTimeMs
        else {
            return nil
        }

        let duration = endTimeMs - startTimeMs
        let previousStartTimeMs = startTimeMs - duration
        let previousEndTimeMs = startTimeMs
        let previousStart = Date(
            timeIntervalSince1970:
                TimeInterval(previousStartTimeMs) / 1_000
        )
        // The bridge treats timestamp bounds as half-open while its coarse
        // date filter is inclusive, so format the last included millisecond.
        let previousInclusiveEnd = Date(
            timeIntervalSince1970:
                TimeInterval(previousEndTimeMs - 1) / 1_000
        )

        return UsageRequest(
            homeDirectory: homeDirectory,
            clients: clients,
            since: Self.string(
                from: previousStart,
                calendar: calendar
            ),
            until: Self.string(
                from: previousInclusiveEnd,
                calendar: calendar
            ),
            hourly: true,
            startTimeMs: previousStartTimeMs,
            endTimeMs: previousEndTimeMs,
            useEnvironmentRoots: useEnvironmentRoots
        )
    }

    private static func date(
        from value: String,
        calendar: Calendar
    ) -> Date? {
        dateFormatter(calendar: calendar).date(from: value)
    }

    private static func string(
        from date: Date,
        calendar: Calendar
    ) -> String {
        dateFormatter(calendar: calendar).string(from: date)
    }

    private static func dateFormatter(
        calendar: Calendar
    ) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}
