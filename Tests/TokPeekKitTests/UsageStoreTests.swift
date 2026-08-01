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
@Test("Concurrent refresh checks wait for the shared core scan")
func concurrentRefreshChecksWaitForSharedScan() async throws {
    let loader = SuspendedCountingLoader(report: try fixtureReport())
    let store = UsageStore(loader: loader)

    let firstRefresh = Task {
        await store.refreshIfNeeded(maxAge: 60)
    }
    await loader.waitUntilStarted()

    var secondRefreshStarted = false
    var secondRefreshCompleted = false
    let secondRefresh = Task { @MainActor in
        secondRefreshStarted = true
        await store.refreshIfNeeded(maxAge: 60)
        secondRefreshCompleted = true
    }
    while !secondRefreshStarted {
        await Task.yield()
    }

    #expect(secondRefreshCompleted == false)

    await loader.release()

    await firstRefresh.value
    await secondRefresh.value

    #expect(secondRefreshCompleted)
    #expect(await loader.loadCount == 1)
}

@MainActor
@Test("Matching report kinds share one core scan")
func matchingReportKindsShareCoreScan() async throws {
    let report = try fixtureReport(models: ["mock-model"])
    let loader = SuspendedCountingLoader(report: report)
    let request = UsageRequest()
    let store = UsageStore(loader: loader, request: request)
    store.comparisonRequest = request
    store.budgetRequest = request

    let currentRefresh = Task {
        await store.refresh()
    }
    await loader.waitUntilStarted()

    var comparisonStarted = false
    var budgetStarted = false
    var catalogStarted = false
    let comparisonRefresh = Task { @MainActor in
        comparisonStarted = true
        await store.refreshComparisonIfNeeded()
    }
    let budgetRefresh = Task { @MainActor in
        budgetStarted = true
        await store.refreshBudgetIfNeeded()
    }
    let catalogRefresh = Task { @MainActor in
        catalogStarted = true
        await store.refreshModelCatalogIfNeeded(maxAge: nil)
    }
    while !comparisonStarted || !budgetStarted || !catalogStarted {
        await Task.yield()
    }

    await loader.release()

    await currentRefresh.value
    await comparisonRefresh.value
    await budgetRefresh.value
    await catalogRefresh.value

    #expect(store.report == report)
    #expect(store.comparisonReport == report)
    #expect(store.budgetReport == report)
    #expect(store.modelCatalog == ["mock-model"])
    #expect(await loader.loadCount == 1)
}

@MainActor
@Test("A persisted report is restored before another core scan")
func persistedReportRestoresBeforeRefresh() async throws {
    let cachedAt = Date(timeIntervalSince1970: 1_785_283_200)
    let request = UsageRequest(since: "2026-07-28")
    let cachedReport = try fixtureReport(totalTokens: 450)
    let loader = CountingLoader(
        report: try fixtureReport(totalTokens: 900)
    )
    let cache = MemoryUsageReportCache(
        snapshot: UsageReportSnapshot(
            request: request,
            report: cachedReport,
            refreshedAt: cachedAt
        )
    )
    let store = UsageStore(
        loader: loader,
        request: request,
        reportCache: cache
    )

    await store.refreshIfNeeded(
        maxAge: 60,
        now: cachedAt.addingTimeInterval(30)
    )

    #expect(store.report == cachedReport)
    #expect(await loader.loadCount == 0)
}

@MainActor
@Test("A persisted report for another request is not displayed")
func mismatchedPersistedReportIsIgnored() async throws {
    let requestedReport = try fixtureReport(totalTokens: 900)
    let loader = CountingLoader(report: requestedReport)
    let cache = MemoryUsageReportCache(
        snapshot: UsageReportSnapshot(
            request: UsageRequest(since: "2026-07-27"),
            report: try fixtureReport(totalTokens: 450),
            refreshedAt: Date(timeIntervalSince1970: 1_785_196_800)
        )
    )
    let store = UsageStore(
        loader: loader,
        request: UsageRequest(since: "2026-07-28"),
        reportCache: cache
    )

    await store.refreshIfNeeded(maxAge: 60)

    #expect(store.report == requestedReport)
    #expect(await loader.loadCount == 1)
    #expect(await cache.savedSnapshot?.report == requestedReport)
}

@Test("The file report cache round-trips a synthetic snapshot")
func fileReportCacheRoundTripsSnapshot() async throws {
    let cacheDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let cacheURL = cacheDirectory
        .appendingPathComponent("usage-report.json", isDirectory: false)
    defer { try? FileManager.default.removeItem(at: cacheDirectory) }

    let cache = FileUsageReportCache(fileURL: cacheURL)
    let snapshot = UsageReportSnapshot(
        request: UsageRequest(since: "2026-07-28"),
        report: try fixtureReport(totalTokens: 450),
        refreshedAt: Date(timeIntervalSince1970: 1_785_283_200)
    )

    await cache.save(snapshot)

    #expect(await cache.load() == snapshot)
}

@Test("The file report cache ignores malformed data")
func fileReportCacheIgnoresMalformedData() async throws {
    let cacheDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let cacheURL = cacheDirectory
        .appendingPathComponent("usage-report.json", isDirectory: false)
    defer { try? FileManager.default.removeItem(at: cacheDirectory) }
    try FileManager.default.createDirectory(
        at: cacheDirectory,
        withIntermediateDirectories: true
    )
    try Data("not-json".utf8).write(to: cacheURL)

    let cache = FileUsageReportCache(fileURL: cacheURL)

    #expect(await cache.load() == nil)
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

@MainActor
@Test("Comparison reports load once per distinct previous-period request")
func comparisonReportCachesByRequest() async throws {
    let loader = CountingLoader(report: try fixtureReport(totalTokens: 450))
    let store = UsageStore(loader: loader)
    store.comparisonRequest = UsageRequest(
        since: "2026-07-20",
        until: "2026-07-26"
    )

    await store.refreshComparisonIfNeeded()
    await store.refreshComparisonIfNeeded()

    #expect(store.comparisonReport?.summary.totalTokens == 450)
    #expect(await loader.loadCount == 1)

    store.comparisonRequest = UsageRequest(
        since: "2026-07-13",
        until: "2026-07-19"
    )
    await store.refreshComparisonIfNeeded()

    #expect(await loader.loadCount == 2)
}

@MainActor
@Test("Removing the comparison request clears stale comparison data")
func nilComparisonRequestClearsReport() async throws {
    let store = UsageStore(
        loader: StubLoader(
            report: try fixtureReport(totalTokens: 450)
        )
    )
    store.comparisonRequest = UsageRequest(
        since: "2026-07-20",
        until: "2026-07-26"
    )
    await store.refreshComparisonIfNeeded()

    store.comparisonRequest = nil
    await store.refreshComparisonIfNeeded()

    #expect(store.comparisonReport == nil)
}

@MainActor
@Test("Budget reports load once per distinct analytics request")
func budgetReportCachesByRequest() async throws {
    let loader = CountingLoader(
        report: try fixtureReport(totalTokens: 7_500)
    )
    let store = UsageStore(loader: loader)
    store.budgetRequest = UsageRequest(
        since: "2026-07-01",
        until: "2026-07-30"
    )

    await store.refreshBudgetIfNeeded()
    await store.refreshBudgetIfNeeded()

    #expect(store.budgetReport?.summary.totalTokens == 7_500)
    #expect(await loader.loadCount == 1)

    store.budgetRequest = UsageRequest(
        since: "2026-08-01",
        until: "2026-08-01"
    )
    await store.refreshBudgetIfNeeded()

    #expect(await loader.loadCount == 2)
}

@MainActor
@Test("Removing the budget request clears stale budget data")
func nilBudgetRequestClearsReport() async throws {
    let store = UsageStore(
        loader: StubLoader(
            report: try fixtureReport(totalTokens: 7_500)
        )
    )
    store.budgetRequest = UsageRequest(
        since: "2026-07-01",
        until: "2026-07-30"
    )
    await store.refreshBudgetIfNeeded()

    store.budgetRequest = nil
    await store.refreshBudgetIfNeeded()

    #expect(store.budgetReport == nil)
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

private actor DelayedCountingLoader: UsageLoading {
    let report: UsageReport
    private(set) var loadCount = 0

    init(report: UsageReport) {
        self.report = report
    }

    func loadReport(request: UsageRequest) async throws -> UsageReport {
        loadCount += 1
        try await Task.sleep(for: .milliseconds(50))
        return report
    }
}

private actor SuspendedCountingLoader: UsageLoading {
    let report: UsageReport
    private(set) var loadCount = 0
    private var isStarted = false
    private var isReleased = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    init(report: UsageReport) {
        self.report = report
    }

    func loadReport(request: UsageRequest) async throws -> UsageReport {
        loadCount += 1
        isStarted = true
        let waiters = startWaiters
        startWaiters.removeAll()
        waiters.forEach { $0.resume() }

        if !isReleased {
            await withCheckedContinuation { continuation in
                releaseWaiters.append(continuation)
            }
        }
        return report
    }

    func waitUntilStarted() async {
        guard !isStarted else {
            return
        }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func release() {
        isReleased = true
        let waiters = releaseWaiters
        releaseWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }
}

private actor MemoryUsageReportCache: UsageReportCaching {
    private let snapshot: UsageReportSnapshot?
    private(set) var savedSnapshot: UsageReportSnapshot?

    init(snapshot: UsageReportSnapshot?) {
        self.snapshot = snapshot
    }

    func load() async -> UsageReportSnapshot? {
        snapshot
    }

    func save(_ snapshot: UsageReportSnapshot) async {
        savedSnapshot = snapshot
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
