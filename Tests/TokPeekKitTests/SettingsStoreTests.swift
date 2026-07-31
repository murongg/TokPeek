import Foundation
import Testing

#if SWIFT_PACKAGE
    @testable import TokPeekKit
#endif

@MainActor
@Test("Settings persist and reload from an isolated defaults suite")
func settingsPersistAndReload() throws {
    let suiteName = "TokPeekTests.Settings.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let settings = SettingsStore(defaults: defaults)
    settings.usagePeriod = .month
    settings.refreshFrequency = .fiveMinutes
    settings.menuBarMetric = .budgetProgress
    settings.useEnvironmentRoots = true
    settings.customDateRange = UsageDateRange(
        start: Date(timeIntervalSince1970: 1_780_000_000),
        end: Date(timeIntervalSince1970: 1_780_604_800)
    )
    settings.isBudgetEnabled = true
    settings.budgetPeriod = .week
    settings.budgetMetric = .tokens
    settings.budgetLimit = 2_500_000
    settings.budgetNotificationsEnabled = false

    let reloaded = SettingsStore(defaults: defaults)

    #expect(reloaded.usagePeriod == .month)
    #expect(reloaded.refreshFrequency == .fiveMinutes)
    #expect(reloaded.menuBarMetric == .budgetProgress)
    #expect(reloaded.useEnvironmentRoots)
    #expect(reloaded.customDateRange == settings.customDateRange)
    #expect(reloaded.isBudgetEnabled)
    #expect(reloaded.budgetPeriod == .week)
    #expect(reloaded.budgetMetric == .tokens)
    #expect(reloaded.budgetLimit == 2_500_000)
    #expect(reloaded.budgetNotificationsEnabled == false)
    #expect(
        reloaded.budget
            == UsageBudget(
                isEnabled: true,
                period: .week,
                metric: .tokens,
                limit: 2_500_000,
                notificationsEnabled: false
            )
    )
}

@MainActor
@Test("Fresh settings use useful menu-bar defaults")
func freshSettingsUseDefaults() throws {
    let suiteName = "TokPeekTests.Defaults.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let settings = SettingsStore(defaults: defaults)

    #expect(settings.usagePeriod == .today)
    #expect(settings.refreshFrequency == .minute)
    #expect(settings.menuBarMetric == .summary)
    #expect(settings.useEnvironmentRoots == false)
    #expect(settings.isBudgetEnabled == false)
    #expect(settings.budgetPeriod == .month)
    #expect(settings.budgetMetric == .cost)
    #expect(settings.budgetLimit == 50)
    #expect(settings.budgetNotificationsEnabled)
}

@Test("Usage periods build an inclusive Tokscale request")
func usagePeriodBuildsRequest() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
    let now = try #require(
        ISO8601DateFormatter().date(from: "2026-07-27T12:00:00Z")
    )
    let values = SettingsValues(
        usagePeriod: .month,
        refreshFrequency: .minute,
        menuBarMetric: .tokens,
        useEnvironmentRoots: true
    )

    let request = values.usageRequest(now: now, calendar: calendar)

    #expect(request.since == "2026-06-28")
    #expect(request.until == "2026-07-27")
    #expect(request.useEnvironmentRoots)
}

@Test("Today is the first period and requests hourly data for the natural day")
func todayUsageBuildsHourlyNaturalDayRequest() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(
        TimeZone(secondsFromGMT: 8 * 60 * 60)
    )
    let now = try #require(
        ISO8601DateFormatter().date(from: "2026-07-27T18:00:00Z")
    )
    let values = SettingsValues(
        usagePeriod: .today,
        refreshFrequency: .minute,
        menuBarMetric: .summary,
        useEnvironmentRoots: false
    )

    let request = values.usageRequest(now: now, calendar: calendar)

    #expect(UsagePeriod.allCases.first == .today)
    #expect(request.since == "2026-07-28")
    #expect(request.until == "2026-07-28")
    #expect(request.hourly)
    #expect(
        request.startTimeMs
            == Int64(
                calendar.startOfDay(for: now).timeIntervalSince1970
                    * 1_000
            )
    )
    #expect(
        request.endTimeMs
            == Int64(
                try #require(
                    calendar.date(
                        byAdding: .day,
                        value: 1,
                        to: calendar.startOfDay(for: now)
                    )
                ).timeIntervalSince1970 * 1_000
            )
    )
}

@Test("Last 24 hours requests 24 aligned hourly buckets")
func last24HoursBuildsAlignedHourlyRequest() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
    let now = try #require(
        ISO8601DateFormatter().date(from: "2026-07-27T12:34:56Z")
    )
    let values = SettingsValues(
        usagePeriod: .last24Hours,
        refreshFrequency: .minute,
        menuBarMetric: .summary,
        useEnvironmentRoots: false
    )

    let request = values.usageRequest(now: now, calendar: calendar)
    let currentHour = try #require(
        calendar.dateInterval(of: .hour, for: now)?.start
    )
    let expectedStart = try #require(
        calendar.date(byAdding: .hour, value: -23, to: currentHour)
    )
    let expectedEnd = try #require(
        calendar.date(byAdding: .hour, value: 1, to: currentHour)
    )

    #expect(Array(UsagePeriod.allCases.prefix(2)) == [.today, .last24Hours])
    #expect(request.since == "2026-07-26")
    #expect(request.until == "2026-07-27")
    #expect(request.hourly)
    #expect(
        request.startTimeMs
            == Int64(expectedStart.timeIntervalSince1970 * 1_000)
    )
    #expect(
        request.endTimeMs
            == Int64(expectedEnd.timeIntervalSince1970 * 1_000)
    )
}

@Test("All-time usage leaves Tokscale date filters empty")
func allTimeUsageLeavesDatesEmpty() {
    let values = SettingsValues(
        usagePeriod: .all,
        refreshFrequency: .manual,
        menuBarMetric: .iconOnly,
        useEnvironmentRoots: false
    )

    let request = values.usageRequest()

    #expect(request.since == nil)
    #expect(request.until == nil)
}

@Test("Custom usage ranges normalize dates and preserve inclusive bounds")
func customUsageRangeBuildsRequest() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
    let later = try #require(
        ISO8601DateFormatter().date(from: "2026-07-27T18:00:00Z")
    )
    let earlier = try #require(
        ISO8601DateFormatter().date(from: "2026-07-05T08:00:00Z")
    )
    let values = SettingsValues(
        usagePeriod: .custom,
        refreshFrequency: .minute,
        menuBarMetric: .summary,
        useEnvironmentRoots: false,
        customDateRange: UsageDateRange(
            start: later,
            end: earlier
        )
    )

    let request = values.usageRequest(
        now: later,
        calendar: calendar
    )

    #expect(request.since == "2026-07-05")
    #expect(request.until == "2026-07-27")
    #expect(request.hourly == false)
}

@Test("Date range drafts edit one boundary and normalize only when applied")
func dateRangeDraftUpdatesSelectedBoundary() {
    let originalStart = Date(timeIntervalSince1970: 1_780_000_000)
    let originalEnd = Date(timeIntervalSince1970: 1_780_604_800)
    let editedStart = Date(timeIntervalSince1970: 1_781_209_600)
    var draft = UsageDateRangeDraft(
        range: UsageDateRange(
            start: originalStart,
            end: originalEnd
        )
    )

    draft[.start] = editedStart

    #expect(draft[.start] == editedStart)
    #expect(draft[.end] == originalEnd)
    #expect(draft.normalizedRange.start == originalEnd)
    #expect(draft.normalizedRange.end == editedStart)
}

@Test("Date range picker expands one boundary and collapses repeated selection")
func dateRangePickerStateTogglesOneBoundary() {
    var state = UsageDatePickerState()

    state.toggle(.start)
    #expect(state.expandedBoundary == .start)

    state.toggle(.end)
    #expect(state.expandedBoundary == .end)

    state.toggle(.end)
    #expect(state.expandedBoundary == nil)
}

@Test("A daily request compares against the immediately preceding equal range")
func dailyRequestBuildsPreviousPeriod() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
    let request = UsageRequest(
        clients: ["mock-client"],
        since: "2026-07-21",
        until: "2026-07-27",
        useEnvironmentRoots: true
    )

    let previous = try #require(
        request.previousPeriod(calendar: calendar)
    )

    #expect(previous.clients == ["mock-client"])
    #expect(previous.since == "2026-07-14")
    #expect(previous.until == "2026-07-20")
    #expect(previous.useEnvironmentRoots)
}

@Test("An hourly request shifts its exact half-open interval")
func hourlyRequestBuildsPreviousPeriod() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
    let start: Int64 = 1_785_283_200_000
    let end = start + 24 * 60 * 60 * 1_000
    let request = UsageRequest(
        since: "2026-07-29",
        until: "2026-07-29",
        hourly: true,
        startTimeMs: start,
        endTimeMs: end
    )

    let previous = try #require(
        request.previousPeriod(calendar: calendar)
    )

    #expect(previous.hourly)
    #expect(previous.startTimeMs == start - 24 * 60 * 60 * 1_000)
    #expect(previous.endTimeMs == start)
    #expect(previous.since == "2026-07-28")
    #expect(previous.until == "2026-07-28")
}
