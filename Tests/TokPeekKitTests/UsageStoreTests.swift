import Foundation
import Testing

#if SWIFT_PACKAGE
    @testable import TokPeekKit
#endif

@MainActor
@Test("Refreshing publishes the latest report and clears loading state")
func refreshPublishesReport() async throws {
    let report = try fixtureReport()
    let store = UsageStore(loader: StubLoader(report: report))

    await store.refresh()

    #expect(store.report == report)
    #expect(store.errorMessage == nil)
    #expect(store.isLoading == false)
}

@MainActor
@Test("Refreshing exposes a readable error and preserves the previous report")
func refreshPreservesReportOnFailure() async throws {
    let report = try fixtureReport()
    let store = UsageStore(loader: StubLoader(report: report))
    await store.refresh()
    store.loader = FailingLoader()

    await store.refresh()

    #expect(store.report == report)
    #expect(store.errorMessage == "Synthetic loading failure")
    #expect(store.isLoading == false)
}

@MainActor
@Test("A newer request wins when an earlier refresh finishes later")
func newestRequestWins() async throws {
    let slowReport = try fixtureReport(totalTokens: 100)
    let latestReport = try fixtureReport(totalTokens: 200)
    let store = UsageStore(
        loader: DelayedRequestLoader(
            slowReport: slowReport,
            latestReport: latestReport
        ),
        request: UsageRequest(since: "slow")
    )

    let slowRefresh = Task {
        await store.refresh()
    }
    try await Task.sleep(for: .milliseconds(5))

    store.request = UsageRequest(since: "latest")
    await store.refresh()
    await slowRefresh.value

    #expect(store.report == latestReport)
    #expect(store.isLoading == false)
}

@MainActor
@Test("Changing requests exposes a replacement loading state")
func changedRequestShowsReplacementLoadingState() async throws {
    let previousReport = try fixtureReport(totalTokens: 200)
    let replacementReport = try fixtureReport(totalTokens: 100)
    let store = UsageStore(
        loader: DelayedRequestLoader(
            slowReport: replacementReport,
            latestReport: previousReport
        ),
        request: UsageRequest(since: "latest")
    )
    await store.refresh()

    store.request = UsageRequest(since: "slow")
    let replacementRefresh = Task {
        await store.refresh()
    }
    try await Task.sleep(for: .milliseconds(5))

    #expect(store.report == previousReport)
    #expect(store.isLoading)
    #expect(store.isLoadingNewRequest)

    await replacementRefresh.value

    #expect(store.report == replacementReport)
    #expect(store.isLoading == false)
    #expect(store.isLoadingNewRequest == false)
}

@MainActor
@Test("Refreshing the same request keeps replacement loading quiet")
func sameRequestKeepsReplacementLoadingQuiet() async throws {
    let report = try fixtureReport(totalTokens: 100)
    let store = UsageStore(
        loader: DelayedRequestLoader(
            slowReport: report,
            latestReport: report
        ),
        request: UsageRequest(since: "slow")
    )
    await store.refresh()

    let scheduledRefresh = Task {
        await store.refresh()
    }
    try await Task.sleep(for: .milliseconds(5))

    #expect(store.isLoading)
    #expect(store.isLoadingNewRequest == false)

    await scheduledRefresh.value
}

@MainActor
@Test("A fresh cached report skips another core scan")
func freshCacheSkipsRefresh() async throws {
    let loader = CountingLoader(report: try fixtureReport())
    let store = UsageStore(loader: loader)

    await store.refreshIfNeeded(maxAge: 60)
    await store.refreshIfNeeded(maxAge: 60)

    #expect(await loader.loadCount == 1)
}

@MainActor
@Test("An expired cached report is refreshed")
func expiredCacheRefreshes() async throws {
    let loader = CountingLoader(report: try fixtureReport())
    let store = UsageStore(loader: loader)

    await store.refreshIfNeeded(maxAge: 60)
    await store.refreshIfNeeded(maxAge: 0)

    #expect(await loader.loadCount == 2)
}

@MainActor
@Test("Changing the usage request bypasses the cache")
func changedRequestRefreshes() async throws {
    let loader = CountingLoader(report: try fixtureReport())
    let store = UsageStore(
        loader: loader,
        request: UsageRequest(since: "2026-07-01")
    )

    await store.refreshIfNeeded(maxAge: 300)
    store.request = UsageRequest(since: "2026-07-02")
    await store.refreshIfNeeded(maxAge: 300)

    #expect(await loader.loadCount == 2)
}

@MainActor
@Test("Model catalog loads all-time models and caches the scan")
func modelCatalogLoadsAllTimeModels() async throws {
    let loader = CatalogLoader(
        currentReport: try fixtureReport(models: ["mock-current"]),
        catalogReport: try fixtureReport(
            models: [
                "<synthetic>",
                "mock-archive-alpha",
                "mock-archive-beta",
                "mock-current",
            ]
        )
    )
    let store = UsageStore(
        loader: loader,
        request: UsageRequest(
            since: "2026-07-22",
            until: "2026-07-28",
            useEnvironmentRoots: true
        )
    )

    await store.refresh()
    await store.refreshModelCatalogIfNeeded(maxAge: nil)
    await store.refreshModelCatalogIfNeeded(maxAge: nil)

    #expect(
        store.modelCatalog
            == [
                "mock-archive-alpha",
                "mock-archive-beta",
                "mock-current",
            ]
    )

    let requests = await loader.requests
    #expect(requests.count == 2)
    #expect(requests[1].since == nil)
    #expect(requests[1].until == nil)
    #expect(requests[1].year == nil)
    #expect(requests[1].useEnvironmentRoots)
}

private struct StubLoader: UsageLoading {
    let report: UsageReport

    func loadReport(request: UsageRequest) async throws -> UsageReport {
        report
    }
}

private actor CountingLoader: UsageLoading {
    let report: UsageReport
    private(set) var loadCount = 0

    init(report: UsageReport) {
        self.report = report
    }

    func loadReport(request: UsageRequest) async throws -> UsageReport {
        loadCount += 1
        return report
    }
}

private actor CatalogLoader: UsageLoading {
    let currentReport: UsageReport
    let catalogReport: UsageReport
    private(set) var requests: [UsageRequest] = []

    init(
        currentReport: UsageReport,
        catalogReport: UsageReport
    ) {
        self.currentReport = currentReport
        self.catalogReport = catalogReport
    }

    func loadReport(request: UsageRequest) async throws -> UsageReport {
        requests.append(request)
        return request.since == nil && request.until == nil
            ? catalogReport
            : currentReport
    }
}

private struct FailingLoader: UsageLoading {
    struct Failure: Error, LocalizedError {
        var errorDescription: String? { "Synthetic loading failure" }
    }

    func loadReport(request: UsageRequest) async throws -> UsageReport {
        throw Failure()
    }
}

private struct DelayedRequestLoader: UsageLoading {
    let slowReport: UsageReport
    let latestReport: UsageReport

    func loadReport(request: UsageRequest) async throws -> UsageReport {
        if request.since == "slow" {
            try await Task.sleep(for: .milliseconds(50))
            return slowReport
        }
        return latestReport
    }
}

private func fixtureReport(
    totalTokens: Int64 = 900,
    models: [String] = ["gpt-5"]
) throws -> UsageReport {
    let modelList = try String(
        decoding: JSONEncoder().encode(models),
        as: UTF8.self
    )
    let json = """
        {
          "meta": {
            "generated_at": "2026-07-27T10:00:00Z",
            "version": "4.7.0",
            "date_range_start": "2026-07-27",
            "date_range_end": "2026-07-27",
            "processing_time_ms": 12
          },
          "summary": {
            "total_tokens": \(totalTokens),
            "total_cost": 0.75,
            "total_days": 1,
            "active_days": 1,
            "average_per_day": 900,
            "max_cost_in_single_day": 0.75,
            "clients": ["codex"],
            "models": \(modelList)
          },
          "years": [],
          "contributions": []
        }
        """

    return try CoreJSON.decoder.decode(
        UsageReport.self,
        from: Data(json.utf8)
    )
}
