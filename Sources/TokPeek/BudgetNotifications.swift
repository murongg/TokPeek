import Combine
import Foundation
import UserNotifications

#if canImport(TokPeekKit)
    import TokPeekKit
#endif

@MainActor
final class BudgetNotificationCoordinator: ObservableObject {
    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults
    private var pendingAlertIDs: Set<String> = []

    init(
        center: UNUserNotificationCenter = .current(),
        defaults: UserDefaults = .standard
    ) {
        self.center = center
        self.defaults = defaults
    }

    func evaluate(
        snapshot: UsageBudgetSnapshot
    ) async {
        guard snapshot.budget.notificationsEnabled else {
            return
        }
        guard
            let threshold = snapshot.nextAlert(
                after: checkpoint
            )
        else {
            return
        }

        let alertID =
            snapshot.cycleID
            + ".\(threshold.rawValue)"
        guard pendingAlertIDs.insert(alertID).inserted else {
            return
        }
        defer { pendingAlertIDs.remove(alertID) }

        guard await canSendNotifications() else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = Localization.string(
            threshold == .limitReached
                ? "Budget limit reached"
                : "Budget is 80% used"
        )
        content.body = Localization.format(
            "Used %@ of %@ for the %@ budget.",
            [
                UsageFormatting.budgetValue(
                    snapshot.used,
                    metric: snapshot.budget.metric
                ),
                UsageFormatting.budgetValue(
                    snapshot.budget.limit,
                    metric: snapshot.budget.metric
                ),
                snapshot.budget.period.title.lowercased(),
            ]
        )
        content.sound = .default

        let request = UNNotificationRequest(
            identifier:
                "tokpeek.budget."
                + alertID,
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
            checkpoint = UsageBudgetAlertCheckpoint(
                cycleID: snapshot.cycleID,
                threshold: threshold
            )
        } catch {
            // A notification failure must never interrupt local usage refresh.
        }
    }

    private func canSendNotifications() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(
                options: [.alert, .sound]
            )) == true
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private var checkpoint: UsageBudgetAlertCheckpoint? {
        get {
            guard
                let data = defaults.data(
                    forKey: Key.alertCheckpoint
                )
            else {
                return nil
            }
            return try? JSONDecoder().decode(
                UsageBudgetAlertCheckpoint.self,
                from: data
            )
        }
        set {
            guard
                let newValue,
                let data = try? JSONEncoder().encode(newValue)
            else {
                defaults.removeObject(
                    forKey: Key.alertCheckpoint
                )
                return
            }
            defaults.set(data, forKey: Key.alertCheckpoint)
        }
    }
}

private enum Key {
    static let alertCheckpoint = "budgetAlertCheckpoint"
}
