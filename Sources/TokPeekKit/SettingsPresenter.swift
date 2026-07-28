@MainActor
public struct SettingsPresenter {
    private let activateApplication: () -> Void
    private let openSettings: () -> Void

    public init(
        activateApplication: @escaping () -> Void,
        openSettings: @escaping () -> Void
    ) {
        self.activateApplication = activateApplication
        self.openSettings = openSettings
    }

    public func present() {
        // An accessory app needs a window before activation can bring it forward.
        openSettings()
        activateApplication()
    }
}
