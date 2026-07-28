import Testing

#if SWIFT_PACKAGE
    @testable import TokPeekKit
#endif

@MainActor
@Test("Settings presentation opens the window before activating the app")
func settingsPresentationOpensBeforeActivating() {
    var events: [String] = []
    let presenter = SettingsPresenter(
        activateApplication: {
            events.append("activate")
        },
        openSettings: {
            events.append("open")
        }
    )

    presenter.present()

    #expect(events == ["open", "activate"])
}
