import Foundation

public struct CoreResponse<Value: Decodable & Sendable>: Decodable, Sendable {
    public let ok: Bool
    public let data: Value?
    public let error: String?

    public func value() throws -> Value {
        guard ok else {
            throw CoreResponseError.core(
                error
                    ?? Localization.string(
                        "Tokscale Core returned an unknown error"
                    )
            )
        }

        guard let data else {
            throw CoreResponseError.missingData
        }

        return data
    }
}

public enum CoreResponseError: Error, LocalizedError {
    case core(String)
    case missingData

    public var errorDescription: String? {
        switch self {
        case .core(let message):
            message
        case .missingData:
            Localization.string(
                "Tokscale Core returned no report data"
            )
        }
    }
}
