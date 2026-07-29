import Foundation

public struct UsageChartPoint: Identifiable, Sendable, Equatable {
    public var id: String { contribution.id }

    public let date: Date
    public let contribution: DailyContribution
}

public struct UsageChartLayout: Sendable, Equatable {
    public let points: [UsageChartPoint]
    public let startDate: Date
    public let endDate: Date
    public let dayCount: Int
    public let fixedBarWidth: Double?
    public let axisDates: [Date]
    public let totalTokens: Int64
    public let averageTokens: Double
    public let chartDomain: ClosedRange<Date>
    public var axisValueLabelAnchorX: Double { 0.5 }

    private let calendar: Calendar

    public init(
        report: UsageReport,
        calendar: Calendar = .current
    ) {
        self.calendar = calendar

        let parsedPoints = report.contributions
            .compactMap { contribution -> UsageChartPoint? in
                guard
                    let date = Self.date(
                        from: contribution.date,
                        calendar: calendar
                    )
                else {
                    return nil
                }
                return UsageChartPoint(
                    date: date,
                    contribution: contribution
                )
            }
            .sorted { $0.date < $1.date }

        let fallbackDate = parsedPoints.last?.date ?? Date()
        var reportedStart =
            Self.date(
                from: report.meta.dateRangeStart,
                calendar: calendar
            ) ?? parsedPoints.first?.date ?? fallbackDate
        var reportedEnd =
            Self.date(
                from: report.meta.dateRangeEnd,
                calendar: calendar
            ) ?? parsedPoints.last?.date ?? reportedStart

        if reportedStart > reportedEnd {
            swap(&reportedStart, &reportedEnd)
        }

        let reportedDayCount = Self.inclusiveDayCount(
            from: reportedStart,
            through: reportedEnd,
            calendar: calendar
        )
        // Daily bars stop being legible beyond 90 days; all-time totals remain
        // in the overview while the trend stays focused on recent activity.
        let visibleDayCount = min(
            max(reportedDayCount, 1),
            90
        )
        let visibleStart =
            calendar.date(
                byAdding: .day,
                value: -(visibleDayCount - 1),
                to: reportedEnd
            ) ?? reportedStart

        let resolvedStart = max(reportedStart, visibleStart)
        let resolvedEnd = reportedEnd
        let resolvedDayCount = Self.inclusiveDayCount(
            from: resolvedStart,
            through: resolvedEnd,
            calendar: calendar
        )
        let visiblePoints = parsedPoints.filter {
            $0.date >= resolvedStart && $0.date <= resolvedEnd
        }
        let visibleTotalTokens = visiblePoints.reduce(0) {
            $0 + $1.contribution.totals.tokens
        }

        startDate = resolvedStart
        endDate = resolvedEnd
        dayCount = resolvedDayCount
        points = visiblePoints
        fixedBarWidth = Self.fixedBarWidth(
            for: resolvedDayCount
        )
        axisDates = Self.axisDates(
            from: resolvedStart,
            dayCount: resolvedDayCount,
            calendar: calendar
        )
        totalTokens = visibleTotalTokens
        averageTokens =
            Double(visibleTotalTokens)
            / Double(resolvedDayCount)

        let domainStart =
            calendar.date(
                byAdding: .day,
                value: -1,
                to: resolvedStart
            ) ?? resolvedStart
        // A day-binned BarMark spans midnight to midnight and is centered at
        // noon. Give the one-day view an extra trailing day so that center
        // lands in the middle of the plot instead of half a day to the right.
        let trailingGutterDays = resolvedDayCount == 1 ? 2 : 1
        let domainEnd =
            calendar.date(
                byAdding: .day,
                value: trailingGutterDays,
                to: resolvedEnd
            ) ?? resolvedEnd
        // A full-day gutter keeps the endpoint bars and centered date labels
        // inside the plot instead of letting Charts truncate the final label.
        chartDomain = domainStart...domainEnd
    }

    public func indicatorDate(
        for point: UsageChartPoint
    ) -> Date {
        Self.midpoint(
            ofDayContaining: point.date,
            calendar: calendar
        )
    }

    public func point(nearestTo date: Date) -> UsageChartPoint? {
        guard
            let point = points.min(by: {
                abs($0.date.timeIntervalSince(date))
                    < abs($1.date.timeIntervalSince(date))
            }),
            // Do not snap a tooltip across empty calendar days.
            abs(point.date.timeIntervalSince(date))
                <= 12 * 60 * 60
        else {
            return nil
        }

        return point
    }

    private static func fixedBarWidth(
        for dayCount: Int
    ) -> Double? {
        switch dayCount {
        case ...14:
            nil
        case ...31:
            5
        default:
            2.5
        }
    }

    private static func axisDates(
        from startDate: Date,
        dayCount: Int,
        calendar: Calendar
    ) -> [Date] {
        let labelCount = min(
            dayCount,
            dayCount <= 7 ? 7 : 5
        )
        guard labelCount > 1 else {
            return [
                midpoint(
                    ofDayContaining: startDate,
                    calendar: calendar
                ),
            ]
        }

        return (0..<labelCount).compactMap { index in
            let offset = Int(
                (Double(dayCount - 1)
                    * Double(index)
                    / Double(labelCount - 1)).rounded()
            )
            guard let date = calendar.date(
                byAdding: .day,
                value: offset,
                to: startDate
            ) else {
                return nil
            }
            return midpoint(
                ofDayContaining: date,
                calendar: calendar
            )
        }
    }

    private static func midpoint(
        ofDayContaining date: Date,
        calendar: Calendar
    ) -> Date {
        guard let interval = calendar.dateInterval(
            of: .day,
            for: date
        ) else {
            return date
        }

        return interval.start.addingTimeInterval(
            interval.duration / 2
        )
    }

    private static func inclusiveDayCount(
        from startDate: Date,
        through endDate: Date,
        calendar: Calendar
    ) -> Int {
        let difference =
            calendar.dateComponents(
                [.day],
                from: startDate,
                to: endDate
            ).day ?? 0
        return max(difference + 1, 1)
    }

    private static func date(
        from rawValue: String,
        calendar: Calendar
    ) -> Date? {
        let parts = rawValue.split(separator: "-")
        guard
            parts.count == 3,
            let year = Int(parts[0]),
            let month = Int(parts[1]),
            let day = Int(parts[2])
        else {
            return nil
        }

        return calendar.date(
            from: DateComponents(
                timeZone: calendar.timeZone,
                year: year,
                month: month,
                day: day
            )
        )
    }
}
