import Combine
import Foundation

public enum UsagePeriod: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case week
    case month
    case quarter
    case all

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .week: Localization.string("Last 7 days")
        case .month: Localization.string("Last 30 days")
        case .quarter: Localization.string("Last 90 days")
        case .all: Localization.string("All time")
        }
    }

    public var shortTitle: String {
        switch self {
        case .week: Localization.string("7D")
        case .month: Localization.string("30D")
        case .quarter: Localization.string("90D")
        case .all: Localization.string("All")
        }
    }

    fileprivate var dayCount: Int? {
        switch self {
        case .week: 7
        case .month: 30
        case .quarter: 90
        case .all: nil
        }
    }
}

public enum RefreshFrequency: Int, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case manual = 0
    case thirtySeconds = 30
    case minute = 60
    case fiveMinutes = 300

    public var id: Int { rawValue }
    public var seconds: TimeInterval? {
        self == .manual ? nil : TimeInterval(rawValue)
    }

    public var title: String {
        switch self {
        case .manual: Localization.string("Manually")
        case .thirtySeconds: Localization.string("Every 30 seconds")
        case .minute: Localization.string("Every minute")
        case .fiveMinutes: Localization.string("Every 5 minutes")
        }
    }
}

public enum MenuBarMetric: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case summary
    case tokens
    case cost
    case iconOnly

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .summary: Localization.string("Token and cost")
        case .tokens: Localization.string("Total tokens")
        case .cost: Localization.string("Estimated cost")
        case .iconOnly: Localization.string("Icon only")
        }
    }
}

public struct SettingsValues: Sendable, Equatable, Hashable {
    public var usagePeriod: UsagePeriod
    public var refreshFrequency: RefreshFrequency
    public var menuBarMetric: MenuBarMetric
    public var useEnvironmentRoots: Bool

    public init(
        usagePeriod: UsagePeriod,
        refreshFrequency: RefreshFrequency,
        menuBarMetric: MenuBarMetric,
        useEnvironmentRoots: Bool
    ) {
        self.usagePeriod = usagePeriod
        self.refreshFrequency = refreshFrequency
        self.menuBarMetric = menuBarMetric
        self.useEnvironmentRoots = useEnvironmentRoots
    }

    public func usageRequest(
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> UsageRequest {
        guard let dayCount = usagePeriod.dayCount else {
            return UsageRequest(
                useEnvironmentRoots: useEnvironmentRoots
            )
        }

        let end = calendar.startOfDay(for: now)
        let start = calendar.date(
            byAdding: .day,
            value: -(dayCount - 1),
            to: end
        )

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"

        return UsageRequest(
            since: start.map(formatter.string(from:)),
            until: formatter.string(from: end),
            useEnvironmentRoots: useEnvironmentRoots
        )
    }
}

@MainActor
public final class SettingsStore: ObservableObject {
    @Published public var usagePeriod: UsagePeriod {
        didSet { defaults.set(usagePeriod.rawValue, forKey: Key.usagePeriod) }
    }

    @Published public var refreshFrequency: RefreshFrequency {
        didSet {
            defaults.set(
                refreshFrequency.rawValue,
                forKey: Key.refreshFrequency
            )
        }
    }

    @Published public var menuBarMetric: MenuBarMetric {
        didSet {
            defaults.set(menuBarMetric.rawValue, forKey: Key.menuBarMetric)
        }
    }

    @Published public var useEnvironmentRoots: Bool {
        didSet {
            defaults.set(
                useEnvironmentRoots,
                forKey: Key.useEnvironmentRoots
            )
        }
    }

    public var values: SettingsValues {
        SettingsValues(
            usagePeriod: usagePeriod,
            refreshFrequency: refreshFrequency,
            menuBarMetric: menuBarMetric,
            useEnvironmentRoots: useEnvironmentRoots
        )
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        usagePeriod =
            UsagePeriod(
                rawValue: defaults.string(forKey: Key.usagePeriod) ?? ""
            ) ?? .month
        if defaults.object(forKey: Key.refreshFrequency) != nil {
            refreshFrequency =
                RefreshFrequency(
                    rawValue: defaults.integer(forKey: Key.refreshFrequency)
                ) ?? .minute
        } else {
            refreshFrequency = .minute
        }
        menuBarMetric =
            MenuBarMetric(
                rawValue: defaults.string(forKey: Key.menuBarMetric) ?? ""
            ) ?? .summary
        useEnvironmentRoots = defaults.bool(forKey: Key.useEnvironmentRoots)
    }
}

private enum Key {
    static let usagePeriod = "usagePeriod"
    static let refreshFrequency = "refreshFrequency"
    static let menuBarMetric = "menuBarMetric"
    static let useEnvironmentRoots = "useEnvironmentRoots"
}
