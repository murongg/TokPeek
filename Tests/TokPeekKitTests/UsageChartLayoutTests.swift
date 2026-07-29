import Foundation
import Testing

#if SWIFT_PACKAGE
    @testable import TokPeekKit
#endif

@Test("Dashboard tabs compensate the native segmented control alignment inset")
func dashboardTabsAlignWithContent() {
    #expect(
        DashboardLayoutMetrics.segmentedControlHorizontalAllowance
            == 14
    )
    #expect(DashboardLayoutMetrics.periodPickerWidth == 300)
    #expect(DashboardLayoutMetrics.filtersMenuWidth == 74)
    #expect(
        DashboardLayoutMetrics.filtersMenuLabelWidth
            == DashboardLayoutMetrics.filtersMenuWidth
    )
    #expect(
        DashboardLayoutMetrics.filtersMenuHitTargetWidth
            == DashboardLayoutMetrics.filtersMenuWidth
    )
    #expect(
        DashboardLayoutMetrics.filtersMenuHitTargetHeight
            == 24
    )
    #expect(
        DashboardLayoutMetrics.filtersMenuNativeTrailingAllowance
            == 15
    )
    #expect(
        DashboardLayoutMetrics.filtersMenuContentLeadingPadding
            == 8
    )
    #expect(
        DashboardLayoutMetrics.filtersMenuContentTrailingPadding
            == 0
    )
    #expect(
        DashboardLayoutMetrics.periodPickerWidth
            + DashboardLayoutMetrics.segmentedControlHorizontalAllowance * 2
            + DashboardLayoutMetrics.calendarButtonWidth
            + DashboardLayoutMetrics.filtersMenuWidth
            + DashboardLayoutMetrics.filterSpacing * 2
            == DashboardLayoutMetrics.contentWidth
    )
}

@Test("Thirty and ninety day charts use thin bars and sparse date labels")
func chartLayoutAdaptsToLongerRanges() throws {
    let calendar = chartCalendar()
    let thirtyDates = try chartDates(
        starting: "2026-07-01",
        count: 30,
        calendar: calendar
    )
    let ninetyDates = try chartDates(
        starting: "2026-05-02",
        count: 90,
        calendar: calendar
    )

    let thirtyDayLayout = UsageChartLayout(
        report: chartReport(contributionDates: thirtyDates),
        calendar: calendar
    )
    let ninetyDayLayout = UsageChartLayout(
        report: chartReport(contributionDates: ninetyDates),
        calendar: calendar
    )

    #expect(thirtyDayLayout.points.count == 30)
    #expect(thirtyDayLayout.dayCount == 30)
    #expect(thirtyDayLayout.fixedBarWidth == 5)
    #expect(thirtyDayLayout.axisDates.count == 5)
    #expect(
        chartDateString(
            thirtyDayLayout.axisDates.first,
            calendar: calendar
        ) == "2026-07-01"
    )
    #expect(
        chartDateString(
            thirtyDayLayout.axisDates.last,
            calendar: calendar
        ) == "2026-07-30"
    )

    #expect(ninetyDayLayout.points.count == 90)
    #expect(ninetyDayLayout.dayCount == 90)
    #expect(ninetyDayLayout.fixedBarWidth == 2.5)
    #expect(ninetyDayLayout.axisDates.count == 5)
    #expect(
        chartDateString(
            ninetyDayLayout.axisDates.first,
            calendar: calendar
        ) == "2026-05-02"
    )
    #expect(
        chartDateString(
            ninetyDayLayout.axisDates.last,
            calendar: calendar
        ) == "2026-07-30"
    )
}

@Test("Seven-day charts use the native automatic bar width")
func sevenDayChartUsesAutomaticBarWidth() throws {
    let calendar = chartCalendar()
    let dates = try chartDates(
        starting: "2026-07-24",
        count: 7,
        calendar: calendar
    )

    let layout = UsageChartLayout(
        report: chartReport(contributionDates: dates),
        calendar: calendar
    )

    #expect(layout.fixedBarWidth == nil)
    #expect(layout.axisDates.count == 7)
    #expect(
        chartDateString(
            layout.axisDates.first,
            calendar: calendar
        ) == "2026-07-24"
    )
    #expect(
        chartDateString(
            layout.axisDates.last,
            calendar: calendar
        ) == "2026-07-30"
    )
    #expect(
        chartDateString(
            layout.chartDomain.lowerBound,
            calendar: calendar
        ) == "2026-07-23"
    )
    #expect(
        chartDateString(
            layout.chartDomain.upperBound,
            calendar: calendar
        ) == "2026-07-31"
    )

    let firstPoint = try #require(layout.points.first)
    let lastPoint = try #require(layout.points.last)
    let leadingInset = layout.indicatorDate(for: firstPoint)
        .timeIntervalSince(layout.chartDomain.lowerBound)
    let trailingInset = layout.chartDomain.upperBound
        .timeIntervalSince(layout.indicatorDate(for: lastPoint))

    #expect(leadingInset == trailingInset)
    #expect(leadingInset == 24 * 60 * 60)
}

@Test("Daily hover indicators anchor to the center of their bars")
func dailyIndicatorAnchorsToBarCenter() throws {
    let calendar = chartCalendar()
    let dates = try chartDates(
        starting: "2026-07-24",
        count: 1,
        calendar: calendar
    )
    let layout = UsageChartLayout(
        report: chartReport(contributionDates: dates),
        calendar: calendar
    )
    let point = try #require(layout.points.first)
    let anchor = layout.indicatorDate(for: point)
    let domainMidpoint =
        layout.chartDomain.lowerBound.addingTimeInterval(
            layout.chartDomain.upperBound.timeIntervalSince(
                layout.chartDomain.lowerBound
            ) / 2
        )

    #expect(calendar.component(.hour, from: anchor) == 12)
    #expect(calendar.component(.minute, from: anchor) == 0)
    #expect(anchor == domainMidpoint)
    #expect(layout.axisDates == [anchor])
    #expect(
        layout.axisValueLabelAnchorX(
            for: layout.axisDates[0]
        ) == 0.5
    )
}

@Test("All-time charts stay focused on the most recent ninety days")
func chartLayoutCapsLongRanges() throws {
    let calendar = chartCalendar()
    let dates = try chartDates(
        starting: "2026-01-01",
        count: 211,
        calendar: calendar
    )

    let layout = UsageChartLayout(
        report: chartReport(contributionDates: dates),
        calendar: calendar
    )

    #expect(layout.dayCount == 90)
    #expect(layout.points.count == 90)
    #expect(layout.points.first?.id == "2026-05-02")
    #expect(layout.points.last?.id == "2026-07-30")
}

@Test("Today chart renders all 24 hourly slots with sparse hour labels")
func todayChartUsesHourlySlots() throws {
    let calendar = chartCalendar()
    let report = chartReport(
        contributionDates: ["2026-07-30"],
        hourlyContributions: [
            chartHourlyContribution(
                hour: "2026-07-30 09:00",
                tokens: 120
            ),
            chartHourlyContribution(
                hour: "2026-07-30 14:00",
                tokens: 240
            ),
        ]
    )

    let layout = UsageChartLayout(
        report: report,
        period: .today,
        calendar: calendar
    )

    #expect(layout.granularity == .hourly)
    #expect(layout.points.count == 24)
    #expect(layout.points[9].totals.tokens == 120)
    #expect(layout.points[14].totals.tokens == 240)
    #expect(layout.axisDates.count == 5)
    #expect(calendar.component(.hour, from: layout.axisDates[0]) == 0)
    #expect(calendar.component(.hour, from: layout.axisDates[1]) == 6)
    #expect(calendar.component(.hour, from: layout.axisDates[2]) == 12)
    #expect(calendar.component(.hour, from: layout.axisDates[3]) == 18)
    #expect(calendar.component(.hour, from: layout.axisDates[4]) == 23)
    #expect(
        layout.axisValueLabelAnchorX(
            for: layout.axisDates[0]
        ) == 0
    )
    #expect(
        layout.axisValueLabelAnchorX(
            for: layout.axisDates[2]
        ) == 0.5
    )
    #expect(
        layout.axisValueLabelAnchorX(
            for: layout.axisDates[4]
        ) == 1
    )
}

@Test("Last 24 hour chart keeps rolling hour order across midnight")
func last24HourChartKeepsRollingOrder() throws {
    let calendar = chartCalendar()
    let report = chartReport(
        contributionDates: ["2026-07-29", "2026-07-30"],
        hourlyContributions: [
            chartHourlyContribution(
                hour: "2026-07-29 13:00",
                tokens: 10
            ),
            chartHourlyContribution(
                hour: "2026-07-30 12:00",
                tokens: 20
            ),
        ]
    )

    let layout = UsageChartLayout(
        report: report,
        period: .last24Hours,
        calendar: calendar
    )

    #expect(layout.granularity == .hourly)
    #expect(layout.points.count == 24)
    #expect(layout.points.first?.id == "2026-07-29 13:00")
    #expect(layout.points.last?.id == "2026-07-30 12:00")
    #expect(layout.points.first?.totals.tokens == 10)
    #expect(layout.points.last?.totals.tokens == 20)
}

private func chartReport(
    contributionDates: [String],
    hourlyContributions: [HourlyContribution] = []
) -> UsageReport {
    let contributions = contributionDates.map { date in
        DailyContribution(
            date: date,
            totals: DailyTotals(
                tokens: 100,
                cost: 0.01,
                messages: 2
            ),
            intensity: 1,
            tokenBreakdown: TokenBreakdown(
                input: 60,
                output: 40,
                cacheRead: 0,
                cacheWrite: 0,
                reasoning: 0
            ),
            clients: [],
            activeTimeMs: nil
        )
    }

    return UsageReport(
        meta: ReportMetadata(
            generatedAt: "2026-07-30T12:00:00Z",
            version: "4.7.0",
            dateRangeStart: contributionDates.first ?? "2026-07-30",
            dateRangeEnd: contributionDates.last ?? "2026-07-30",
            processingTimeMs: 1
        ),
        summary: UsageSummary(
            totalTokens: Int64(contributions.count * 100),
            totalCost: Double(contributions.count) * 0.01,
            totalDays: contributions.count,
            activeDays: contributions.count,
            averagePerDay: 100,
            maxCostInSingleDay: 0.01,
            clients: ["synthetic-client"],
            models: ["synthetic-model"]
        ),
        years: [],
        contributions: contributions,
        hourlyContributions: hourlyContributions
    )
}

private func chartHourlyContribution(
    hour: String,
    tokens: Int64
) -> HourlyContribution {
    HourlyContribution(
        hour: hour,
        totals: DailyTotals(
            tokens: tokens,
            cost: 0.01,
            messages: 2
        ),
        tokenBreakdown: TokenBreakdown(
            input: tokens,
            output: 0,
            cacheRead: 0,
            cacheWrite: 0,
            reasoning: 0
        ),
        clients: []
    )
}

private func chartDates(
    starting start: String,
    count: Int,
    calendar: Calendar
) throws -> [String] {
    let startDate = try #require(
        chartDateFormatter(calendar: calendar).date(from: start)
    )

    return try (0..<count).map { offset in
        let date = try #require(
            calendar.date(
                byAdding: .day,
                value: offset,
                to: startDate
            )
        )
        return chartDateFormatter(calendar: calendar).string(from: date)
    }
}

private func chartDateString(
    _ date: Date?,
    calendar: Calendar
) -> String? {
    date.map(chartDateFormatter(calendar: calendar).string(from:))
}

private func chartDateFormatter(
    calendar: Calendar
) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}

private func chartCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}
