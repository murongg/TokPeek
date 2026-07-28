import Combine
import Sparkle

#if canImport(TokPeekKit)
    import TokPeekKit
#endif

@MainActor
final class SparkleUpdateChecker: UpdateChecking {
    private let updaterController: SPUStandardUpdaterController
    private var availabilityCancellable: AnyCancellable?

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var canCheckForUpdates: Bool {
        updaterController.updater.canCheckForUpdates
    }

    var automaticallyChecksForUpdates: Bool {
        get {
            updaterController.updater.automaticallyChecksForUpdates
        }
        set {
            updaterController.updater.automaticallyChecksForUpdates =
                newValue
        }
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    func observeCanCheckForUpdates(
        _ observer: @escaping (Bool) -> Void
    ) {
        availabilityCancellable = updaterController.updater
            .publisher(for: \.canCheckForUpdates)
            .sink(receiveValue: observer)
    }
}
