import Foundation

#if canImport(CTokPeekCore)
    import CTokPeekCore
#endif
#if canImport(TokPeekKit)
    import TokPeekKit
#endif

public struct TokscaleClient: UsageLoading {
    public init() {}

    public func loadReport(request: UsageRequest) async throws -> UsageReport {
        // The C ABI call performs a synchronous filesystem scan, so it must
        // never occupy SwiftUI's main actor.
        try await Task.detached(priority: .userInitiated) {
            try Self.loadSynchronously(request: request)
        }.value
    }

    private static func loadSynchronously(
        request: UsageRequest
    ) throws -> UsageReport {
        let requestData = try CoreJSON.encoder.encode(request)
        let requestJSON = String(decoding: requestData, as: UTF8.self)

        guard
            let output = requestJSON.withCString({
                tokpeek_graph_report($0)
            })
        else {
            throw TokscaleClientError.noResponse
        }
        defer { tokpeek_string_free(output) }

        guard let responseJSON = String(validatingCString: output) else {
            throw TokscaleClientError.invalidUTF8
        }

        let response = try CoreJSON.decoder.decode(
            CoreResponse<UsageReport>.self,
            from: Data(responseJSON.utf8)
        )
        return try response.value()
    }
}

private enum TokscaleClientError: Error, LocalizedError {
    case noResponse
    case invalidUTF8

    var errorDescription: String? {
        switch self {
        case .noResponse:
            Localization.string(
                "Tokscale Core returned no response"
            )
        case .invalidUTF8:
            Localization.string(
                "Tokscale Core returned invalid text"
            )
        }
    }
}
