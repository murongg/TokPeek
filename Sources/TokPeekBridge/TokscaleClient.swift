import Darwin
import Foundation

#if canImport(CTokPeekCore)
    import CTokPeekCore
#endif
#if canImport(TokPeekKit)
    import TokPeekKit
#endif

public struct TokscaleClient: UsageLoading {
    private static let scans = ScanExecutor()

    public init() {}

    public func loadReport(request: UsageRequest) async throws -> UsageReport {
        try await Self.scans.run {
            try Self.loadSynchronously(request: request)
        }
    }

    private static func loadSynchronously(
        request: UsageRequest
    ) throws -> UsageReport {
        let requestData = try CoreJSON.encoder.encode(request)
        guard let executableURL = Bundle.main.executableURL else {
            throw TokscaleClientError.scannerUnavailable
        }
        // Freeing parser buffers does not reliably return their heap pages on
        // macOS. Let the worker exit so only the small report stays resident.
        let responseData = try ReportProcess(
            executableURL: executableURL,
            arguments: [TokscaleWorker.argument]
        ).run(input: requestData)
        let response = try CoreJSON.decoder.decode(
            CoreResponse<UsageReport>.self,
            from: responseData
        )
        return try response.value()
    }
}

public enum TokscaleWorker {
    static let argument = "--tokpeek-usage-worker"

    public static func runIfRequested() throws -> Bool {
        guard Array(CommandLine.arguments.dropFirst()) == [argument] else {
            return false
        }

        let requestData = try FileHandle.standardInput.readToEnd() ?? Data()
        guard let requestJSON = String(data: requestData, encoding: .utf8) else {
            throw TokscaleClientError.invalidUTF8
        }
        guard let output = requestJSON.withCString({ tokpeek_graph_report($0) }) else {
            throw TokscaleClientError.noResponse
        }
        defer { tokpeek_string_free(output) }
        try FileHandle.standardOutput.write(
            contentsOf: Data(bytes: output, count: strlen(output))
        )
        return true
    }
}

struct ReportProcess {
    let executableURL: URL
    let arguments: [String]

    func run(input: Data) throws -> Data {
        let process = Process()
        let request = Pipe()
        let response = Pipe()
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardInput = request
        process.standardOutput = response
        defer {
            try? request.fileHandleForWriting.close()
            try? response.fileHandleForReading.close()
        }

        try process.run()
        defer {
            if process.isRunning {
                process.terminate()
                process.waitUntilExit()
            }
        }
        try request.fileHandleForWriting.write(contentsOf: input)
        try request.fileHandleForWriting.close()
        // Drain before waiting: a large all-time report can fill the pipe and
        // prevent the worker from exiting until the parent consumes it.
        let output = try response.fileHandleForReading.readToEnd() ?? Data()
        process.waitUntilExit()
        guard process.terminationReason == .exit, process.terminationStatus == 0 else {
            throw TokscaleClientError.scannerFailed(process.terminationStatus)
        }
        return output
    }
}

actor ScanExecutor {
    // There must be no suspension inside this method: different report ranges
    // otherwise launch workers whose full-history allocations overlap.
    func run<Value: Sendable>(
        _ operation: @Sendable () throws -> Value
    ) throws -> Value {
        try Task.checkCancellation()
        return try autoreleasepool(invoking: operation)
    }
}

private enum TokscaleClientError: Error, LocalizedError {
    case noResponse
    case invalidUTF8
    case scannerUnavailable
    case scannerFailed(Int32)

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
        case .scannerUnavailable:
            Localization.string("Usage scanner is unavailable")
        case let .scannerFailed(status):
            Localization.format("Usage scanner exited with status %d", [status])
        }
    }
}
