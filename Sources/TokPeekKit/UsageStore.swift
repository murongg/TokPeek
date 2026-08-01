import Combine
import Foundation

public protocol UsageLoading: Sendable {
    func loadReport(request: UsageRequest) async throws -> UsageReport
}

@MainActor
public final class UsageStore: ObservableObject {
    private enum ReportLoadOutcome: Sendable {
        case success(UsageReport)
        case failure(String)
    }

    @Published public private(set) var report: UsageReport?
    @Published public private(set) var comparisonReport: UsageReport?
    @Published public private(set) var budgetReport: UsageReport?
    @Published public private(set) var modelCatalog: [String] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?
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
    private var budgetGeneration: UInt64 = 0
    private var modelCatalogGeneration: UInt64 = 0
    private var lastSuccessfulRequest: UsageRequest?
    private var lastSuccessfulRefreshAt: Date?
    private var lastSuccessfulComparisonRequest: UsageRequest?
    private var lastSuccessfulComparisonRefreshAt: Date?
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

        return now.timeIntervalSince(lastSuccessfulRefreshAt) >= maxAge
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

        return now.timeIntervalSince(
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

        return now.timeIntervalSince(
            lastSuccessfulComparisonRefreshAt
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

        return now.timeIntervalSince(
            lastSuccessfulBudgetRefreshAt
        ) >= maxAge
    }
}
