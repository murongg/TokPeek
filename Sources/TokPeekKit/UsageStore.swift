import Combine
import Foundation

public protocol UsageLoading: Sendable {
    func loadReport(request: UsageRequest) async throws -> UsageReport
}

@MainActor
public final class UsageStore: ObservableObject {
    @Published public private(set) var report: UsageReport?
    @Published public private(set) var modelCatalog: [String] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?

    var loader: any UsageLoading
    public var request: UsageRequest
    private var refreshGeneration: UInt64 = 0
    private var modelCatalogGeneration: UInt64 = 0
    private var lastSuccessfulRequest: UsageRequest?
    private var lastSuccessfulRefreshAt: Date?
    private var lastSuccessfulModelCatalogRequest: UsageRequest?
    private var lastSuccessfulModelCatalogRefreshAt: Date?

    public init(
        loader: any UsageLoading,
        request: UsageRequest = UsageRequest()
    ) {
        self.loader = loader
        self.request = request
    }

    public func refreshIfNeeded(
        maxAge: TimeInterval?,
        now: Date = Date()
    ) async {
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
        isLoading = true
        errorMessage = nil
        defer {
            if generation == refreshGeneration {
                isLoading = false
            }
        }

        do {
            let loadedReport = try await activeLoader.loadReport(
                request: requestedReport
            )
            // A period change can start another scan before the detached FFI
            // call returns. Only the newest request is allowed to publish.
            guard generation == refreshGeneration else {
                return
            }
            report = loadedReport
            lastSuccessfulRequest = requestedReport
            lastSuccessfulRefreshAt = Date()
        } catch {
            guard generation == refreshGeneration else {
                return
            }
            errorMessage = error.localizedDescription
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

        do {
            let catalogReport = try await activeLoader.loadReport(
                request: requestedCatalog
            )
            guard generation == modelCatalogGeneration else {
                return
            }

            modelCatalog = catalogReport.modelFilterOptions
            lastSuccessfulModelCatalogRequest = requestedCatalog
            lastSuccessfulModelCatalogRefreshAt = now
        } catch {
            // The current-period report remains usable when the optional
            // all-time catalog scan fails.
        }
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
}
