import Testing

#if SWIFT_PACKAGE
    @testable import TokPeekKit
#endif

@MainActor
@Test("Update coordinator mirrors availability and forwards user actions")
func updateCoordinatorForwardsUserActions() {
    let checker = MockUpdateChecker(
        canCheckForUpdates: false,
        automaticallyChecksForUpdates: true
    )
    let coordinator = UpdateCoordinator(checker: checker)

    #expect(coordinator.canCheckForUpdates == false)
    #expect(coordinator.automaticallyChecksForUpdates)

    coordinator.setAutomaticallyChecksForUpdates(false)

    #expect(coordinator.automaticallyChecksForUpdates == false)
    #expect(checker.automaticallyChecksForUpdates == false)

    coordinator.checkForUpdates()
    #expect(checker.checkCount == 0)

    checker.emitCanCheckForUpdates(true)

    #expect(coordinator.canCheckForUpdates)

    coordinator.checkForUpdates()
    #expect(checker.checkCount == 1)
}

@MainActor
private final class MockUpdateChecker: UpdateChecking {
    var canCheckForUpdates: Bool
    var automaticallyChecksForUpdates: Bool
    private(set) var checkCount = 0

    private var availabilityObserver: ((Bool) -> Void)?

    init(
        canCheckForUpdates: Bool,
        automaticallyChecksForUpdates: Bool
    ) {
        self.canCheckForUpdates = canCheckForUpdates
        self.automaticallyChecksForUpdates =
            automaticallyChecksForUpdates
    }

    func checkForUpdates() {
        checkCount += 1
    }

    func observeCanCheckForUpdates(
        _ observer: @escaping (Bool) -> Void
    ) {
        availabilityObserver = observer
    }

    func emitCanCheckForUpdates(_ canCheckForUpdates: Bool) {
        self.canCheckForUpdates = canCheckForUpdates
        availabilityObserver?(canCheckForUpdates)
    }
}
