import Foundation
import Testing

#if SWIFT_PACKAGE
    @testable import TokPeekKit
#endif

@Test("Activity heatmap columns fill the available card width")
func activityHeatmapFillsCardWidth() {
    let geometry = ActivityHeatmapGeometry(contentWidth: 424)

    #expect(geometry.cellSize > 12)
    #expect(abs(geometry.gridWidth - 386) < 0.000_001)
    #expect(abs(geometry.totalWidth - 424) < 0.000_001)
}

@Test("Activity heatmap resolves one hovered cell from the whole grid")
func activityHeatmapResolvesHoveredCell() {
    let geometry = ActivityHeatmapGeometry(contentWidth: 424)
    let gridLeading =
        ActivityHeatmapGeometry.weekdayLabelWidth
        + ActivityHeatmapGeometry.labelSpacing
    let columnStep =
        geometry.cellSize
        + ActivityHeatmapGeometry.cellSpacing
    let rowStep =
        geometry.cellSize
        + ActivityHeatmapGeometry.rowSpacing

    let index = geometry.cellIndex(
        atX: gridLeading + columnStep * 12 + geometry.cellSize / 2,
        y: rowStep * 3 + geometry.cellSize / 2
    )
    let horizontalGap = geometry.cellIndex(
        atX: gridLeading + geometry.cellSize
            + ActivityHeatmapGeometry.cellSpacing / 2,
        y: geometry.cellSize / 2
    )

    #expect(index == 3 * 24 + 12)
    #expect(geometry.cellIndex(atX: 20, y: 10) == nil)
    #expect(horizontalGap == nil)
}

@Test("Activity heatmap aggregates matching weekday and hour slots")
func activityHeatmapAggregatesWeekdayHours() throws {
    let calendar = heatmapCalendar()
    let report = heatmapReport(
        hourlyContributions: [
            heatmapContribution(
                hour: "2026-08-30 09:00",
                tokens: 100,
                cost: 0.10,
                activeTimeMs: 60_000
            ),
            heatmapContribution(
                hour: "2026-09-06 09:00",
                tokens: 300,
                cost: 0.30,
                activeTimeMs: 180_000
            ),
            heatmapContribution(
                hour: "2026-08-31 21:00",
                tokens: 25,
                cost: 0.05,
                activeTimeMs: 30_000
            ),
        ]
    )

    let tokenLayout = ActivityHeatmapLayout(
        report: report,
        metric: .tokens,
        calendar: calendar
    )
    let costLayout = ActivityHeatmapLayout(
        report: report,
        metric: .cost,
        calendar: calendar
    )
    let durationLayout = ActivityHeatmapLayout(
        report: report,
        metric: .duration,
        calendar: calendar
    )

    #expect(tokenLayout.cells.count == 7 * 24)
    #expect(tokenLayout.cells.first?.weekday == 1)
    #expect(tokenLayout.cells.first?.hour == 0)
    #expect(tokenLayout.cells.last?.weekday == 7)
    #expect(tokenLayout.cells.last?.hour == 23)
    #expect(tokenLayout.cell(weekday: 1, hour: 9)?.value == 400)
    #expect(
        abs(
            try #require(
                costLayout.cell(weekday: 1, hour: 9)
            ).value - 0.40
        ) < 0.000_001
    )
    #expect(durationLayout.cell(weekday: 1, hour: 9)?.value == 240_000)
    #expect(tokenLayout.cell(weekday: 2, hour: 21)?.value == 25)
}

@Test("Activity heatmap maps zero and peak values to stable intensity levels")
func activityHeatmapNormalizesIntensity() {
    let layout = ActivityHeatmapLayout(
        report: heatmapReport(
            hourlyContributions: [
                heatmapContribution(
                    hour: "2026-08-30 09:00",
                    tokens: 25,
                    cost: 0.05,
                    activeTimeMs: 30_000
                ),
                heatmapContribution(
                    hour: "2026-08-31 09:00",
                    tokens: 400,
                    cost: 0.40,
                    activeTimeMs: 240_000
                ),
            ]
        ),
        metric: .tokens,
        calendar: heatmapCalendar()
    )

    #expect(layout.cell(weekday: 1, hour: 0)?.intensity == 0)
    #expect(layout.cell(weekday: 1, hour: 9)?.intensity == 2)
    #expect(layout.cell(weekday: 2, hour: 9)?.intensity == 6)
}

@Test("Activity heatmap reports unavailable filtered duration data")
func activityHeatmapDetectsUnavailableDuration() {
    let calendar = heatmapCalendar()
    let available = ActivityHeatmapLayout(
        report: heatmapReport(
            hourlyContributions: [
                heatmapContribution(
                    hour: "2026-08-30 09:00",
                    tokens: 100,
                    cost: 0.10,
                    activeTimeMs: 0
                )
            ]
        ),
        metric: .duration,
        calendar: calendar
    )
    let unavailable = ActivityHeatmapLayout(
        report: heatmapReport(
            hourlyContributions: [
                heatmapContribution(
                    hour: "2026-08-30 09:00",
                    tokens: 100,
                    cost: 0.10,
                    activeTimeMs: nil
                )
            ]
        ),
        metric: .duration,
        calendar: calendar
    )

    #expect(available.isMetricAvailable)
    #expect(unavailable.isMetricAvailable == false)
}

private func heatmapCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

private func heatmapReport(
    hourlyContributions: [HourlyContribution]
) -> UsageReport {
    UsageReport(
        meta: ReportMetadata(
            generatedAt: "2026-09-07T00:00:00Z",
            version: "test",
            dateRangeStart: "2026-08-30",
            dateRangeEnd: "2026-09-07",
            processingTimeMs: 1
        ),
        summary: UsageSummary(
            totalTokens: 0,
            totalCost: 0,
            totalDays: 0,
            activeDays: 0,
            averagePerDay: 0,
            maxCostInSingleDay: 0,
            clients: [],
            models: []
        ),
        years: [],
        contributions: [],
        hourlyContributions: hourlyContributions
    )
}

private func heatmapContribution(
    hour: String,
    tokens: Int64,
    cost: Double,
    activeTimeMs: Int64?
) -> HourlyContribution {
    HourlyContribution(
        hour: hour,
        totals: DailyTotals(
            tokens: tokens,
            cost: cost,
            messages: 1
        ),
        tokenBreakdown: TokenBreakdown(
            input: tokens,
            output: 0,
            cacheRead: 0,
            cacheWrite: 0,
            reasoning: 0
        ),
        clients: [],
        activeTimeMs: activeTimeMs
    )
}
