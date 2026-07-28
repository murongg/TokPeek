import Combine
import Foundation
import ServiceManagement

@MainActor
public protocol LoginItemServicing: AnyObject {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

@MainActor
public final class SystemLoginItemService: LoginItemServicing {
    public init() {}

    public var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

@MainActor
public final class LaunchAtLoginController: ObservableObject {
    @Published public private(set) var isEnabled: Bool
    @Published public private(set) var errorMessage: String?

    private let service: any LoginItemServicing

    public init(
        service: any LoginItemServicing = SystemLoginItemService()
    ) {
        self.service = service
        isEnabled = service.isEnabled
    }

    public func setEnabled(_ enabled: Bool) {
        errorMessage = nil

        do {
            try service.setEnabled(enabled)
            isEnabled = service.isEnabled
            guard isEnabled == enabled else {
                errorMessage =
                    enabled
                    ? Localization.string(
                        "Allow TokPeek in System Settings → General → Login Items."
                    )
                    : Localization.string(
                        "TokPeek is still enabled in System Settings → General → Login Items."
                    )
                return
            }
        } catch {
            isEnabled = service.isEnabled
            errorMessage = error.localizedDescription
        }
    }

    public func refresh() {
        isEnabled = service.isEnabled
    }
}
