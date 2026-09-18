import Combine
import Foundation

public protocol UsageLoading: Sendable {
    func loadReport(request: UsageRequest) async throws -> UsageReport
}

public enum UsageRefreshScope: Sendable {
    case menuBar
    case dashboard
}

@MainActor
public final class UsageStore: ObservableObject {
    private enum ReportLoadOutcome: Sendable {
        case success(UsageReport)
        case failure(String)
    }

    @Published public private(set) var report: UsageReport?
    @Published public private(set) var comparisonReport: UsageReport?
    @Published public private(set) var activityReport: UsageReport?
    @Published public private(set) var budgetReport: UsageReport?
    @Published public private(set) var modelCatalog: [String] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var isManualRefreshing = false
    @Published public private(set) var isActivityLoading = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var activityErrorMessage: String?
    @Published private var loadingRequest: UsageRequest?

    var loader: any UsageLoading
    public var request: UsageRequest
    public var comparisonRequest: UsageRequest? {
        didSet {
            guard comparisonRequest != oldValue else {
                return
            }
            comparisonGeneration &+= 1
            if comparisonRequest != lastSuccessfulComparisonRequest {
                comparisonReport = nil
            }
        }
    }
    public var activityRequest: UsageRequest? {
        didSet {
            guard activityRequest != oldValue else {
                return
            }
            activityGeneration &+= 1
            activityErrorMessage = nil
            if activityRequest != lastSuccessfulActivityRequest {
                activityReport = nil
            }
            // The first scan may be queued behind another report. Until it
            // succeeds or fails, nil means pending, not an empty period.
            isActivityLoading = activityRequest != nil && activityReport == nil
        }
    }
    public var budgetRequest: UsageRequest? {
        didSet {
            guard budgetRequest != oldValue else {
                return
            }
            budgetGeneration &+= 1
            if budgetRequest != lastSuccessfulBudgetRequest {
                budgetReport = nil
            }
        }
    }
    private var refreshGeneration: UInt64 = 0
    private var comparisonGeneration: UInt64 = 0
    private var activityGeneration: UInt64 = 0
    private var budgetGeneration: UInt64 = 0
    private var modelCatalogGeneration: UInt64 = 0
    private var lastSuccessfulRequest: UsageRequest?
    private var lastSuccessfulRefreshAt: Date?
    private var lastSuccessfulComparisonRequest: UsageRequest?
    private var lastSuccessfulComparisonRefreshAt: Date?
    private var lastSuccessfulActivityRequest: UsageRequest?
    private var lastSuccessfulActivityRefreshAt: Date?
    private var lastSuccessfulBudgetRequest: UsageRequest?
    private var lastSuccessfulBudgetRefreshAt: Date?
    private var lastSuccessfulModelCatalogRequest: UsageRequest?
    private var lastSuccessfulModelCatalogRefreshAt: Date?
    private let reportCache: (any UsageReportCaching)?
    private var lastCacheRestoreRequest: UsageRequest?
    private var inFlightReportLoads: [
        UsageRequest: Task<ReportLoadOutcome, Never>
    ] = [:]

    public var isLoadingNewRequest: Bool {
        // Scheduled refreshes keep the current report visible. A changed
        // period or data root gets an explicit loading transition instead.
        isLoading
            && report != nil
            && loadingRequest != lastSuccessfulRequest
    }

    public init(
        loader: any UsageLoading,
        request: UsageRequest = UsageRequest(),
        reportCache: (any UsageReportCaching)? = nil
    ) {
        self.loader = loader
        self.request = request
        self.reportCache = reportCache
        comparisonRequest = nil
        activityRequest = nil
        budgetRequest = nil
    }

    public func refreshIfNeeded(
        maxAge: TimeInterval?,
        now: Date = Date()
    ) async {
        await restoreCachedReportIfNeeded()
        guard shouldRefresh(maxAge: maxAge, now: now) else {
            return
        }
        await refresh()
    }

    public func refreshManually(settings: SettingsValues) async {
        guard !isManualRefreshing else { return }
        // The button stays busy through every dashboard report, including
        // activity and model scans that outlive the primary loading flag.
        isManualRefreshing = true
        defer { isManualRefreshing = false }
        await refreshUsage(settings: settings, scope: .dashboard, maxAge: 0)
    }

    public func refreshUsage(
        settings: SettingsValues,
        scope: UsageRefreshScope,
        maxAge: TimeInterval?,
        now: Date = Date()
    ) async {
        guard !Task.isCancelled else { return }
        request = settings.usageRequest(now: now)
        comparisonRequest = request.previousPeriod()
        activityRequest = settings.activityRequest(now: now)
        budgetRequest = settings.budget.analyticsRequest(
            now: now,
            useEnvironmentRoots: settings.useEnvironmentRoots
        )

        await refreshIfNeeded(maxAge: maxAge, now: now)
        guard !Task.isCancelled else { return }
        if scope == .dashboard {
            // Fill the visible heatmap before supplementary comparisons and
            // budgets; each worker may have to wait for pricing on cold start.
            await refreshActivityIfNeeded(maxAge: maxAge, now: now)
        }
        guard !Task.isCancelled else { return }
        await refreshComparisonIfNeeded(now: now)
        guard !Task.isCancelled else { return }
        await refreshBudgetIfNeeded(maxAge: maxAge, now: now)
        guard !Task.isCancelled, scope == .dashboard else { return }

        // The all-time model catalog is only consumed by the dashboard.
        await refreshModelCatalogIfNeeded(
            maxAge: maxAge == 0 ? 0 : 300,
            now: now
        )
    }

    public func refresh() async {
        refreshGeneration &+= 1
        let generation = refreshGeneration
        let requestedReport = request
        let activeLoader = loader
        loadingRequest = requestedReport
        isLoading = true
        errorMessage = nil
        defer {
            if generation == refreshGeneration {
                isLoading = false
                loadingRequest = nil
            }
        }

        switch await loadReport(
            for: requestedReport,
            using: activeLoader
        ) {
        case let .success(loadedReport):
            // A period change can start another scan before the detached FFI
            // call returns. Only the newest request is allowed to publish.
            guard generation == refreshGeneration else {
                return
            }
            report = loadedReport
            lastSuccessfulRequest = requestedReport
            let refreshedAt = Date()
            lastSuccessfulRefreshAt = refreshedAt
            if let reportCache {
                await reportCache.save(
                    UsageReportSnapshot(
                        request: requestedReport,
                        report: loadedReport,
                        refreshedAt: refreshedAt
                    )
                )
            }
        case let .failure(message):
            guard generation == refreshGeneration else {
                return
            }
            errorMessage = message
        }
    }

    private func restoreCachedReportIfNeeded() async {
        let requestedReport = request
        guard
            report == nil,
            lastCacheRestoreRequest != requestedReport,
            let reportCache
        else {
            return
        }

        lastCacheRestoreRequest = requestedReport
        // Usage periods are encoded in the request, so restoring a mismatched
        // snapshot would show stale totals under the wrong period label.
        guard
            let snapshot = await reportCache.load(),
            snapshot.request == requestedReport,
            request == requestedReport,
            report == nil
        else {
            return
        }

        report = snapshot.report
        lastSuccessfulRequest = snapshot.request
        lastSuccessfulRefreshAt = snapshot.refreshedAt
    }

    public func refreshComparisonIfNeeded(
        maxAge: TimeInterval? = nil,
        now: Date = Date()
    ) async {
        guard let comparisonRequest else {
            comparisonReport = nil
            lastSuccessfulComparisonRequest = nil
            lastSuccessfulComparisonRefreshAt = nil
            return
        }
        guard shouldRefreshComparison(
            request: comparisonRequest,
            maxAge: maxAge,
            now: now
        ) else {
            return
        }

        comparisonGeneration &+= 1
        let generation = comparisonGeneration
        let activeLoader = loader

        switch await loadReport(
            for: comparisonRequest,
            using: activeLoader
        ) {
        case let .success(loadedReport):
            guard generation == comparisonGeneration else {
                return
            }
            comparisonReport = loadedReport
            lastSuccessfulComparisonRequest = comparisonRequest
            lastSuccessfulComparisonRefreshAt = now
        case .failure:
            // Comparison is supplementary; the current report remains useful
            // when an older range cannot be loaded.
            break
        }
    }

    public func refreshActivityIfNeeded(
        maxAge: TimeInterval? = nil,
        now: Date = Date()
    ) async {
        guard let activityRequest else {
            activityReport = nil
            isActivityLoading = false
            activityErrorMessage = nil
            lastSuccessfulActivityRequest = nil
            lastSuccessfulActivityRefreshAt = nil
            return
        }
        guard shouldRefreshActivity(
            request: activityRequest,
            maxAge: maxAge,
            now: now
        ) else {
            return
        }

        activityGeneration &+= 1
        let generation = activityGeneration
        let activeLoader = loader
        isActivityLoading = true
        activityErrorMessage = nil
        defer {
            if generation == activityGeneration {
                isActivityLoading = false
            }
        }

        switch await loadReport(
            for: activityRequest,
            using: activeLoader
        ) {
        case let .success(loadedReport):
            guard generation == activityGeneration else {
                return
            }
            activityReport = loadedReport
            lastSuccessfulActivityRequest = activityRequest
            lastSuccessfulActivityRefreshAt = now
        case let .failure(message):
            guard generation == activityGeneration else {
                return
            }
            // Activity is supplementary; the main report remains useful
            // when the fixed weekly hourly scan cannot be loaded.
            activityErrorMessage = message
        }
    }

    public func refreshBudgetIfNeeded(
        maxAge: TimeInterval? = nil,
        now: Date = Date()
    ) async {
        guard let budgetRequest else {
            budgetReport = nil
            lastSuccessfulBudgetRequest = nil
            lastSuccessfulBudgetRefreshAt = nil
            return
        }
        guard shouldRefreshBudget(
            request: budgetRequest,
            maxAge: maxAge,
            now: now
        ) else {
            return
        }

        budgetGeneration &+= 1
        let generation = budgetGeneration
        let activeLoader = loader

        switch await loadReport(
            for: budgetRequest,
            using: activeLoader
        ) {
        case let .success(loadedReport):
            guard generation == budgetGeneration else {
                return
            }
            budgetReport = loadedReport
            lastSuccessfulBudgetRequest = budgetRequest
            lastSuccessfulBudgetRefreshAt = now
        case .failure:
            // Budget analytics are supplementary; the main report remains
            // available if their broader date scan cannot be loaded.
            break
        }
    }

    public func refreshModelCatalogIfNeeded(
        maxAge: TimeInterval?,
        now: Date = Date()
    ) async {
        let requestedCatalog = UsageRequest(
            homeDirectory: request.homeDirectory,
            clients: request.clients,
            useEnvironmentRoots: request.useEnvironmentRoots
        )
        guard shouldRefreshModelCatalog(
            request: requestedCatalog,
            maxAge: maxAge,
            now: now
        ) else {
            return
        }

        modelCatalogGeneration &+= 1
        let generation = modelCatalogGeneration
        let activeLoader = loader

        switch await loadReport(
            for: requestedCatalog,
            using: activeLoader
        ) {
        case let .success(catalogReport):
            guard generation == modelCatalogGeneration else {
                return
            }

            modelCatalog = catalogReport.modelFilterOptions
            lastSuccessfulModelCatalogRequest = requestedCatalog
            lastSuccessfulModelCatalogRefreshAt = now
        case .failure:
            // The current-period report remains usable when the optional
            // all-time catalog scan fails.
            break
        }
    }

    private func loadReport(
        for request: UsageRequest,
        using loader: any UsageLoading
    ) async -> ReportLoadOutcome {
        if let inFlightLoad = inFlightReportLoads[request] {
            return await inFlightLoad.value
        }

        // Every report lane goes through this request-keyed task so matching
        // dashboard and menu-bar work cannot start duplicate core scans.
        let load = Task {
            do {
                return ReportLoadOutcome.success(
                    try await loader.loadReport(request: request)
                )
            } catch {
                return ReportLoadOutcome.failure(
                    error.localizedDescription
                )
            }
        }
        inFlightReportLoads[request] = load

        let outcome = await load.value
        inFlightReportLoads[request] = nil
        return outcome
    }

    private func shouldRefresh(
        maxAge: TimeInterval?,
        now: Date
    ) -> Bool {
        guard
            report != nil,
            lastSuccessfulRequest == request,
            let lastSuccessfulRefreshAt
        else {
            return true
        }

        guard let maxAge else {
            return false
        }

        // Zero means an explicit refresh, even if `now` was captured before
        // the previous scan completed and is earlier than its completion time.
        return maxAge <= 0 || now.timeIntervalSince(lastSuccessfulRefreshAt) >= maxAge
    }

    private func shouldRefreshModelCatalog(
        request: UsageRequest,
        maxAge: TimeInterval?,
        now: Date
    ) -> Bool {
        guard
            lastSuccessfulModelCatalogRequest == request,
            let lastSuccessfulModelCatalogRefreshAt
        else {
            return true
        }

        guard let maxAge else {
            return false
        }

        return maxAge <= 0 || now.timeIntervalSince(
            lastSuccessfulModelCatalogRefreshAt
        ) >= maxAge
    }

    private func shouldRefreshComparison(
        request: UsageRequest,
        maxAge: TimeInterval?,
        now: Date
    ) -> Bool {
        guard
            comparisonReport != nil,
            lastSuccessfulComparisonRequest == request,
            let lastSuccessfulComparisonRefreshAt
        else {
            return true
        }

        guard let maxAge else {
            return false
        }

        return maxAge <= 0 || now.timeIntervalSince(
            lastSuccessfulComparisonRefreshAt
        ) >= maxAge
    }

    private func shouldRefreshActivity(
        request: UsageRequest,
        maxAge: TimeInterval?,
        now: Date
    ) -> Bool {
        guard
            activityReport != nil,
            lastSuccessfulActivityRequest == request,
            let lastSuccessfulActivityRefreshAt
        else {
            return true
        }

        guard let maxAge else {
            return false
        }

        return maxAge <= 0 || now.timeIntervalSince(
            lastSuccessfulActivityRefreshAt
        ) >= maxAge
    }

    private func shouldRefreshBudget(
        request: UsageRequest,
        maxAge: TimeInterval?,
        now: Date
    ) -> Bool {
        guard
            budgetReport != nil,
            lastSuccessfulBudgetRequest == request,
            let lastSuccessfulBudgetRefreshAt
        else {
            return true
        }

        guard let maxAge else {
            return false
        }

        return maxAge <= 0 || now.timeIntervalSince(
            lastSuccessfulBudgetRefreshAt
        ) >= maxAge
    }
}
