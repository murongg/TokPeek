import Combine

@MainActor
public protocol UpdateChecking: AnyObject {
    var canCheckForUpdates: Bool { get }
    var automaticallyChecksForUpdates: Bool { get set }

    func checkForUpdates()
    func observeCanCheckForUpdates(
        _ observer: @escaping (Bool) -> Void
    )
}

@MainActor
public final class UpdateCoordinator: ObservableObject {
    @Published public private(set) var canCheckForUpdates: Bool
    @Published public private(set) var automaticallyChecksForUpdates: Bool

    private let checker: any UpdateChecking

    public init(checker: any UpdateChecking) {
        self.checker = checker
        canCheckForUpdates = checker.canCheckForUpdates
        automaticallyChecksForUpdates =
            checker.automaticallyChecksForUpdates

        checker.observeCanCheckForUpdates { [weak self] canCheck in
            self?.canCheckForUpdates = canCheck
        }
    }

    public func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        checker.automaticallyChecksForUpdates = enabled
        automaticallyChecksForUpdates =
            checker.automaticallyChecksForUpdates
    }

    public func checkForUpdates() {
        guard canCheckForUpdates else {
            return
        }

        checker.checkForUpdates()
    }
}
