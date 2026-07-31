import Foundation
import Testing

#if SWIFT_PACKAGE
    @testable import TokPeekKit
#endif

@Test("Budget analytics requests include the month needed for forecasting")
func budgetAnalyticsRequestIncludesCurrentMonth() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
    calendar.firstWeekday = 2
    let now = try #require(
        ISO8601DateFormatter().date(from: "2026-07-30T12:00:00Z")
    )
    let budget = UsageBudget(
        isEnabled: true,
        period: .day,
        metric: .cost,
        limit: 20,
        notificationsEnabled: true
    )

    let request = try #require(
        budget.analyticsRequest(
            now: now,
            calendar: calendar,
            useEnvironmentRoots: true
        )
    )

    #expect(request.since == "2026-07-01")
    #expect(request.until == "2026-07-30")
    #expect(request.useEnvironmentRoots)
}

@Test("Budget snapshots isolate the active cycle and forecast month-end cost")
func budgetSnapshotAggregatesCurrentCycle() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
    calendar.firstWeekday = 2
    let now = try #require(
        ISO8601DateFormatter().date(from: "2026-07-30T12:00:00Z")
    )
    let report = budgetReport(
        days: [
            ("2026-06-30", 9_000, 90),
            ("2026-07-01", 1_000, 10),
            ("2026-07-15", 2_000, 20),
            ("2026-07-29", 3_000, 30),
        ]
    )
    let budget = UsageBudget(
        isEnabled: true,
        period: .month,
        metric: .cost,
        limit: 100,
        notificationsEnabled: true
    )

    let snapshot = try #require(
        budget.snapshot(
            report: report,
            now: now,
            calendar: calendar
        )
    )

    #expect(snapshot.used == 60)
    #expect(snapshot.remaining == 40)
    #expect(snapshot.progress == 0.6)
    #expect(snapshot.forecast.monthToDateCost == 60)
    #expect(snapshot.forecast.elapsedDays == 30)
    #expect(snapshot.forecast.totalDays == 31)
    #expect(snapshot.forecast.projectedCost == 62)
    #expect(snapshot.cycleID.hasPrefix("month|2026-07-01|cost|"))
}

@Test("Token budgets use token totals from only the selected week")
func tokenBudgetUsesCurrentWeek() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
    calendar.firstWeekday = 2
    let now = try #require(
        ISO8601DateFormatter().date(from: "2026-07-30T12:00:00Z")
    )
    let report = budgetReport(
        days: [
            ("2026-07-26", 9_000, 9),
            ("2026-07-27", 2_000, 2),
            ("2026-07-29", 3_000, 3),
        ]
    )
    let budget = UsageBudget(
        isEnabled: true,
        period: .week,
        metric: .tokens,
        limit: 10_000,
        notificationsEnabled: false
    )

    let snapshot = try #require(
        budget.snapshot(
            report: report,
            now: now,
            calendar: calendar
        )
    )

    #expect(snapshot.used == 5_000)
    #expect(snapshot.progress == 0.5)
    #expect(snapshot.remaining == 5_000)
    #expect(snapshot.cycleID.hasPrefix("week|2026-07-27|tokens|"))
}

@Test("Budget alerts fire once per threshold and reset for a new cycle")
func budgetAlertsDeduplicateWithinCycle() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
    let july = try #require(
        ISO8601DateFormatter().date(from: "2026-07-30T12:00:00Z")
    )
    let august = try #require(
        ISO8601DateFormatter().date(from: "2026-08-01T12:00:00Z")
    )
    let budget = UsageBudget(
        isEnabled: true,
        period: .month,
        metric: .cost,
        limit: 100,
        notificationsEnabled: true
    )
    let warningSnapshot = try #require(
        budget.snapshot(
            report: budgetReport(
                days: [("2026-07-30", 8_500, 85)]
            ),
            now: july,
            calendar: calendar
        )
    )

    let warning = try #require(
        warningSnapshot.nextAlert(after: nil)
    )
    #expect(warning == .eightyPercent)

    let warningCheckpoint = UsageBudgetAlertCheckpoint(
        cycleID: warningSnapshot.cycleID,
        threshold: warning
    )
    #expect(
        warningSnapshot.nextAlert(after: warningCheckpoint) == nil
    )

    let limitSnapshot = try #require(
        budget.snapshot(
            report: budgetReport(
                days: [("2026-07-30", 10_500, 105)]
            ),
            now: july,
            calendar: calendar
        )
    )
    #expect(
        limitSnapshot.nextAlert(after: warningCheckpoint)
            == .limitReached
    )

    let nextCycleSnapshot = try #require(
        budget.snapshot(
            report: budgetReport(
                days: [("2026-08-01", 8_500, 85)]
            ),
            now: august,
            calendar: calendar
        )
    )
    #expect(
        nextCycleSnapshot.nextAlert(after: warningCheckpoint)
            == .eightyPercent
    )
}

@Test("Changing the budget definition starts a fresh alert cycle")
func budgetDefinitionChangeResetsAlertCycle() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
    let now = try #require(
        ISO8601DateFormatter().date(from: "2026-07-30T12:00:00Z")
    )
    let report = budgetReport(
        days: [("2026-07-30", 9_000, 90)]
    )
    let costBudget = UsageBudget(
        isEnabled: true,
        period: .month,
        metric: .cost,
        limit: 100,
        notificationsEnabled: true
    )
    let tokenBudget = UsageBudget(
        isEnabled: true,
        period: .month,
        metric: .tokens,
        limit: 10_000,
        notificationsEnabled: true
    )
    let costSnapshot = try #require(
        costBudget.snapshot(
            report: report,
            now: now,
            calendar: calendar
        )
    )
    let tokenSnapshot = try #require(
        tokenBudget.snapshot(
            report: report,
            now: now,
            calendar: calendar
        )
    )
    let checkpoint = UsageBudgetAlertCheckpoint(
        cycleID: costSnapshot.cycleID,
        threshold: .eightyPercent
    )

    #expect(
        tokenSnapshot.nextAlert(after: checkpoint)
            == .eightyPercent
    )
}

private func budgetReport(
    days: [(date: String, tokens: Int64, cost: Double)]
) -> UsageReport {
    let contributions = days.map { day in
        DailyContribution(
            date: day.date,
            totals: DailyTotals(
                tokens: day.tokens,
                cost: day.cost,
                messages: 1
            ),
            intensity: 1,
            tokenBreakdown: TokenBreakdown(
                input: day.tokens,
                output: 0,
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
            dateRangeStart: days.map(\.date).min() ?? "",
            dateRangeEnd: days.map(\.date).max() ?? "",
            processingTimeMs: 1
        ),
        summary: UsageSummary(
            totalTokens: days.reduce(0) { $0 + $1.tokens },
            totalCost: days.reduce(0) { $0 + $1.cost },
            totalDays: days.count,
            activeDays: days.count,
            averagePerDay: 0,
            maxCostInSingleDay: days.map(\.cost).max() ?? 0,
            clients: [],
            models: []
        ),
        years: [],
        contributions: contributions
    )
}
