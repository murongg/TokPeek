import Foundation
import Testing
@testable import TokPeekBridge

@Test("Report scans run one at a time off the main thread")
func scansAreSerialized() async throws {
    let executor = ScanExecutor()
    let activity = ScanActivity()

    try await withThrowingTaskGroup(of: Void.self) { group in
        for _ in 0..<8 {
            group.addTask {
                try await executor.run {
                    #expect(!Thread.isMainThread)
                    activity.begin()
                    defer { activity.end() }
                    Thread.sleep(forTimeInterval: 0.01)
                }
            }
        }
        try await group.waitForAll()
    }

    #expect(activity.peak == 1)
    #expect(activity.completed == 8)
}

@Test("Cancelled queued scans do not perform filesystem work")
func cancelledScanIsSkipped() async throws {
    let executor = ScanExecutor()
    let started = AsyncStream.makeStream(of: Void.self)
    let release = DispatchSemaphore(value: 0)
    let running = Task {
        try await executor.run {
            started.continuation.yield(())
            started.continuation.finish()
            release.wait()
        }
    }
    for await _ in started.stream { break }

    let queued = Task {
        try await executor.run {
            Issue.record("Cancelled scan should never start")
        }
    }
    queued.cancel()
    release.signal()
    try await running.value

    do {
        try await queued.value
        Issue.record("Expected cancellation")
    } catch is CancellationError {
    }
}

@Test("A failed scan does not block the next report")
func scanFailureDoesNotBlockQueue() async throws {
    struct SyntheticFailure: Error {}
    let executor = ScanExecutor()

    do {
        try await executor.run { throw SyntheticFailure() }
        Issue.record("Expected the scan error")
    } catch is SyntheticFailure {
    }

    #expect(try await executor.run { 42 } == 42)
}

private final class ScanActivity: @unchecked Sendable {
    private let lock = NSLock()
    private var active = 0
    private var peakCount = 0
    private var completedCount = 0

    var peak: Int { lock.withLock { peakCount } }
    var completed: Int { lock.withLock { completedCount } }

    func begin() {
        lock.withLock {
            active += 1
            peakCount = max(peakCount, active)
        }
    }

    func end() {
        lock.withLock {
            active -= 1
            completedCount += 1
        }
    }
}
