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
    settings.menuBarMetric = .cost
    settings.useEnvironmentRoots = true

    let reloaded = SettingsStore(defaults: defaults)

    #expect(reloaded.usagePeriod == .month)
    #expect(reloaded.refreshFrequency == .fiveMinutes)
    #expect(reloaded.menuBarMetric == .cost)
    #expect(reloaded.useEnvironmentRoots)
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

@Test("Today is the first period and requests only the current local day")
func todayUsageBuildsSingleDayRequest() throws {
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
