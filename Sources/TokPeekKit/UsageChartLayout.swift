import Foundation

public enum UsageChartGranularity: Sendable, Equatable {
    case hourly
    case daily

    public var calendarComponent: Calendar.Component {
        switch self {
        case .hourly: .hour
        case .daily: .day
        }
    }
}

public enum DashboardLayoutMetrics {
    public static let contentWidth = 448.0
    public static let filterSpacing = 8.0
    public static let periodPickerWidth = 300.0
    public static let calendarButtonWidth = 30.0
    public static let filtersMenuWidth = 74.0
    public static let filtersMenuLabelWidth = filtersMenuWidth
    public static let filtersMenuHitTargetWidth = filtersMenuWidth
    public static let filtersMenuHitTargetHeight = 24.0
    public static let filtersMenuContentLeadingPadding = 8.0
    public static let filtersMenuContentTrailingPadding = 0.0
    public static let filtersMenuNativeTrailingAllowance = 15.0
    public static let calendarFocusEffectDisabled = true
    public static let calendarUsesSystemAccent = true

    // NSSegmentedControl draws beyond its SwiftUI alignment rect on macOS.
    // Budget both overflow edges so adjacent controls start after the native
    // drawing boundary instead of merely shifting the overlap to the right.
    public static let segmentedControlHorizontalAllowance = 14.0
}

public struct UsageChartPoint: Identifiable, Sendable, Equatable {
    public let id: String
    public let date: Date
    public let totals: DailyTotals
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
    public let granularity: UsageChartGranularity

    private let calendar: Calendar

    public init(
        report: UsageReport,
        period: UsagePeriod = .week,
        calendar: Calendar = .current
    ) {
        if period.usesHourlyChart {
            self = Self.hourlyLayout(
                report: report,
                period: period,
                calendar: calendar
            )
        } else {
            self = Self.dailyLayout(
                report: report,
                calendar: calendar
            )
        }
    }

    public func indicatorDate(
        for point: UsageChartPoint
    ) -> Date {
        switch granularity {
        case .hourly:
            return point.date.addingTimeInterval(30 * 60)
        case .daily:
            return Self.midpoint(
                ofDayContaining: point.date,
                calendar: calendar
            )
        }
    }

    public func point(nearestTo date: Date) -> UsageChartPoint? {
        let maximumDistance: TimeInterval =
            granularity == .hourly
            ? 30 * 60
            : 12 * 60 * 60

        guard
            let point = points.min(by: {
                abs(
                    indicatorDate(for: $0)
                        .timeIntervalSince(date)
                )
                    < abs(
                        indicatorDate(for: $1)
                            .timeIntervalSince(date)
                    )
            }),
            abs(
                indicatorDate(for: point)
                    .timeIntervalSince(date)
            ) <= maximumDistance
        else {
            return nil
        }

        return point
    }

    public func axisValueLabelAnchorX(
        for date: Date
    ) -> Double {
        guard granularity == .hourly else {
            return 0.5
        }
        if date == axisDates.first {
            return 0
        }
        if date == axisDates.last {
            return 1
        }
        return 0.5
    }

    private static func hourlyLayout(
        report: UsageReport,
        period: UsagePeriod,
        calendar: Calendar
    ) -> UsageChartLayout {
        let parsed = report.hourlyContributions.compactMap {
            contribution -> (Date, HourlyContribution)? in
            guard
                let date = hour(
                    from: contribution.hour,
                    calendar: calendar
                )
            else {
                return nil
            }
            return (date, contribution)
        }
        .sorted { $0.0 < $1.0 }

        let firstHour: Date
        switch period {
        case .today:
            let reportDay =
                date(
                    from: report.meta.dateRangeEnd,
                    calendar: calendar
                )
                ?? parsed.first?.0
                ?? Date()
            firstHour = calendar.startOfDay(for: reportDay)

        case .last24Hours:
            let lastHour =
                parsed.last?.0
                ?? generatedAt(
                    from: report.meta.generatedAt,
                    calendar: calendar
                )
                ?? Date()
            let alignedLastHour =
                calendar.dateInterval(
                    of: .hour,
                    for: lastHour
                )?.start ?? lastHour
            firstHour =
                calendar.date(
                    byAdding: .hour,
                    value: -23,
                    to: alignedLastHour
                ) ?? alignedLastHour

        case .week, .month, .quarter, .all, .custom:
            preconditionFailure(
                "Daily periods cannot create an hourly chart"
            )
        }

        let contributionByHour = Dictionary(
            uniqueKeysWithValues: parsed.map {
                ($0.0, $0.1)
            }
        )
        let points = (0..<24).compactMap { offset -> UsageChartPoint? in
            guard
                let pointDate = calendar.date(
                    byAdding: .hour,
                    value: offset,
                    to: firstHour
                )
            else {
                return nil
            }

            let contribution = contributionByHour[pointDate]
            return UsageChartPoint(
                id: hourString(
                    from: pointDate,
                    calendar: calendar
                ),
                date: pointDate,
                totals: contribution?.totals ?? zeroTotals
            )
        }
        let lastHour = points.last?.date ?? firstHour
        let domainEnd =
            calendar.date(
                byAdding: .hour,
                value: 1,
                to: lastHour
            ) ?? lastHour
        let totalTokens = points.reduce(Int64(0)) {
            saturatingAdd($0, $1.totals.tokens)
        }

        return UsageChartLayout(
            points: points,
            startDate: firstHour,
            endDate: lastHour,
            dayCount: 1,
            fixedBarWidth: 6,
            axisDates: hourlyAxisDates(
                from: firstHour,
                calendar: calendar
            ),
            totalTokens: totalTokens,
            averageTokens: Double(totalTokens) / 24,
            chartDomain: firstHour...domainEnd,
            granularity: .hourly,
            calendar: calendar
        )
    }

    private static func dailyLayout(
        report: UsageReport,
        calendar: Calendar
    ) -> UsageChartLayout {
        let parsedPoints = report.contributions
            .compactMap { contribution -> UsageChartPoint? in
                guard
                    let date = date(
                        from: contribution.date,
                        calendar: calendar
                    )
                else {
                    return nil
                }
                return UsageChartPoint(
                    id: contribution.id,
                    date: date,
                    totals: contribution.totals
                )
            }
            .sorted { $0.date < $1.date }

        let fallbackDate = parsedPoints.last?.date ?? Date()
        var reportedStart =
            date(
                from: report.meta.dateRangeStart,
                calendar: calendar
            ) ?? parsedPoints.first?.date ?? fallbackDate
        var reportedEnd =
            date(
                from: report.meta.dateRangeEnd,
                calendar: calendar
            ) ?? parsedPoints.last?.date ?? reportedStart

        if reportedStart > reportedEnd {
            swap(&reportedStart, &reportedEnd)
        }

        let reportedDayCount = inclusiveDayCount(
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
        let resolvedDayCount = inclusiveDayCount(
            from: resolvedStart,
            through: resolvedEnd,
            calendar: calendar
        )
        let visiblePoints = parsedPoints.filter {
            $0.date >= resolvedStart && $0.date <= resolvedEnd
        }
        let visibleTotalTokens = visiblePoints.reduce(Int64(0)) {
            saturatingAdd($0, $1.totals.tokens)
        }

        let domainStart: Date
        let domainEnd: Date
        if resolvedDayCount == 1 {
            domainStart =
                calendar.date(
                    byAdding: .day,
                    value: -1,
                    to: resolvedStart
                ) ?? resolvedStart
            domainEnd =
                calendar.date(
                    byAdding: .day,
                    value: 2,
                    to: resolvedEnd
                ) ?? resolvedEnd
        } else {
            let firstBarCenter = midpoint(
                ofDayContaining: resolvedStart,
                calendar: calendar
            )
            let lastBarCenter = midpoint(
                ofDayContaining: resolvedEnd,
                calendar: calendar
            )
            domainStart =
                calendar.date(
                    byAdding: .day,
                    value: -1,
                    to: firstBarCenter
                ) ?? resolvedStart
            domainEnd =
                calendar.date(
                    byAdding: .day,
                    value: 1,
                    to: lastBarCenter
                ) ?? resolvedEnd
        }

        return UsageChartLayout(
            points: visiblePoints,
            startDate: resolvedStart,
            endDate: resolvedEnd,
            dayCount: resolvedDayCount,
            fixedBarWidth: fixedBarWidth(
                for: resolvedDayCount
            ),
            axisDates: dailyAxisDates(
                from: resolvedStart,
                dayCount: resolvedDayCount,
                calendar: calendar
            ),
            totalTokens: visibleTotalTokens,
            averageTokens:
                Double(visibleTotalTokens)
                / Double(resolvedDayCount),
            chartDomain: domainStart...domainEnd,
            granularity: .daily,
            calendar: calendar
        )
    }

    private init(
        points: [UsageChartPoint],
        startDate: Date,
        endDate: Date,
        dayCount: Int,
        fixedBarWidth: Double?,
        axisDates: [Date],
        totalTokens: Int64,
        averageTokens: Double,
        chartDomain: ClosedRange<Date>,
        granularity: UsageChartGranularity,
        calendar: Calendar
    ) {
        self.points = points
        self.startDate = startDate
        self.endDate = endDate
        self.dayCount = dayCount
        self.fixedBarWidth = fixedBarWidth
        self.axisDates = axisDates
        self.totalTokens = totalTokens
        self.averageTokens = averageTokens
        self.chartDomain = chartDomain
        self.granularity = granularity
        self.calendar = calendar
    }

    private static var zeroTotals: DailyTotals {
        DailyTotals(
            tokens: 0,
            cost: 0,
            messages: 0
        )
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

    private static func hourlyAxisDates(
        from startDate: Date,
        calendar: Calendar
    ) -> [Date] {
        [0, 6, 12, 18, 23].compactMap { offset in
            calendar.date(
                byAdding: .minute,
                value: offset * 60 + 30,
                to: startDate
            )
        }
    }

    private static func dailyAxisDates(
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

    private static func saturatingAdd(
        _ lhs: Int64,
        _ rhs: Int64
    ) -> Int64 {
        let (value, overflow) = lhs.addingReportingOverflow(rhs)
        guard overflow else {
            return value
        }
        return rhs >= 0 ? .max : .min
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

    private static func hour(
        from rawValue: String,
        calendar: Calendar
    ) -> Date? {
        let components = rawValue.split(separator: " ")
        guard
            components.count == 2,
            let day = date(
                from: String(components[0]),
                calendar: calendar
            ),
            let hour = Int(
                components[1].split(separator: ":").first ?? ""
            )
        else {
            return nil
        }

        return calendar.date(
            bySettingHour: hour,
            minute: 0,
            second: 0,
            of: day
        )
    }

    private static func hourString(
        from date: Date,
        calendar: Calendar
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:00"
        return formatter.string(from: date)
    }

    private static func generatedAt(
        from rawValue: String,
        calendar: Calendar
    ) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = calendar.timeZone
        return formatter.date(from: rawValue)
    }
}
