import Testing

#if SWIFT_PACKAGE
    @testable import TokPeekKit
#endif

@MainActor
@Test("Launch-at-login changes are delegated and published")
func launchAtLoginChangesAreDelegated() {
    let service = MockLoginItemService(isEnabled: false)
    let controller = LaunchAtLoginController(service: service)

    controller.setEnabled(true)

    #expect(service.requestedValues == [true])
    #expect(controller.isEnabled)
    #expect(controller.errorMessage == nil)
}

@MainActor
@Test("Launch-at-login explains when macOS still requires approval")
func launchAtLoginExplainsPendingApproval() {
    let service = MockLoginItemService(
        isEnabled: false,
        acceptsChanges: false
    )
    let controller = LaunchAtLoginController(service: service)

    controller.setEnabled(true)

    #expect(controller.isEnabled == false)
    #expect(
        controller.errorMessage
            == "Allow TokPeek in System Settings → General → Login Items."
    )
}

@MainActor
private final class MockLoginItemService: LoginItemServicing {
    var isEnabled: Bool
    var requestedValues: [Bool] = []
    let acceptsChanges: Bool

    init(
        isEnabled: Bool,
        acceptsChanges: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.acceptsChanges = acceptsChanges
    }

    func setEnabled(_ enabled: Bool) throws {
        requestedValues.append(enabled)
        if acceptsChanges {
            isEnabled = enabled
        }
    }
}
