import Foundation

public struct UsageReportSnapshot: Codable, Sendable, Equatable {
    public let request: UsageRequest
    public let report: UsageReport
    public let refreshedAt: Date

    public init(
        request: UsageRequest,
        report: UsageReport,
        refreshedAt: Date
    ) {
        self.request = request
        self.report = report
        self.refreshedAt = refreshedAt
    }
}

public protocol UsageReportCaching: Sendable {
    func load() async -> UsageReportSnapshot?
    func save(_ snapshot: UsageReportSnapshot) async
}

public actor FileUsageReportCache: UsageReportCaching {
    private struct Envelope: Codable {
        let version: Int
        let snapshot: UsageReportSnapshot
    }

    private static let formatVersion = 1
    private let fileURL: URL

    public init() {
        fileURL = Self.defaultFileURL()
    }

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() async -> UsageReportSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }

        guard
            let envelope = try? JSONDecoder().decode(
                Envelope.self,
                from: data
            ),
            envelope.version == Self.formatVersion
        else {
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }

        return envelope.snapshot
    }

    public func save(_ snapshot: UsageReportSnapshot) async {
        let envelope = Envelope(
            version: Self.formatVersion,
            snapshot: snapshot
        )

        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(envelope)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // A disposable startup cache must never make a successful usage
            // refresh look like a failure.
        }
    }

    private static func defaultFileURL() -> URL {
        let baseDirectory =
            FileManager.default.urls(
                for: .cachesDirectory,
                in: .userDomainMask
            ).first ?? FileManager.default.temporaryDirectory

        return baseDirectory
            .appendingPathComponent(
                "com.tokpeek.app",
                isDirectory: true
            )
            .appendingPathComponent(
                "usage-report-v1.json",
                isDirectory: false
            )
    }
}
