import Foundation

public enum ActivityMetric: String, CaseIterable, Identifiable, Sendable {
    case tokens
    case cost
    case duration

    public var id: String { rawValue }
}

public struct ActivityHeatmapCell: Identifiable, Sendable, Equatable {
    public var id: Int { weekday * 24 + hour }

    public let weekday: Int
    public let hour: Int
    public let value: Double
    public let intensity: Int
}

public struct ActivityHeatmapLayout: Sendable, Equatable {
    public static let weekdays = Array(1...7)
    public static let hours = Array(0..<24)
    public static let maximumIntensity = 6

    public let cells: [ActivityHeatmapCell]
    public let isMetricAvailable: Bool
    public let maximumValue: Double

    public init(
        report: UsageReport,
        metric: ActivityMetric,
        calendar: Calendar = .current
    ) {
        var buckets: [Slot: Bucket] = [:]
        var parsedContributionCount = 0
        var hasActiveTime = false

        for contribution in report.hourlyContributions {
            guard
                let date = Self.date(
                    from: contribution.hour,
                    calendar: calendar
                )
            else {
                continue
            }

            parsedContributionCount += 1
            let slot = Slot(
                weekday: calendar.component(.weekday, from: date),
                hour: calendar.component(.hour, from: date)
            )
            var bucket = buckets[slot] ?? Bucket()
            bucket.tokens = bucket.tokens.saturatingAdd(
                contribution.totals.tokens
            )
            bucket.cost += contribution.totals.cost
            if let activeTimeMs = contribution.activeTimeMs {
                hasActiveTime = true
                bucket.activeTimeMs = bucket.activeTimeMs.saturatingAdd(
                    activeTimeMs
                )
            }
            buckets[slot] = bucket
        }

        isMetricAvailable =
            switch metric {
            case .tokens, .cost:
                parsedContributionCount > 0
            case .duration:
                hasActiveTime
            }

        let values = Self.weekdays.flatMap { weekday in
            Self.hours.map { hour in
                let bucket =
                    buckets[
                        Slot(weekday: weekday, hour: hour)
                    ] ?? Bucket()
                return Value(
                    weekday: weekday,
                    hour: hour,
                    value: bucket.value(for: metric)
                )
            }
        }
        let maximumValue = values.map(\.value).max() ?? 0
        self.maximumValue = maximumValue
        cells = values.map { value in
            ActivityHeatmapCell(
                weekday: value.weekday,
                hour: value.hour,
                value: value.value,
                intensity: Self.intensity(
                    value: value.value,
                    maximumValue: maximumValue
                )
            )
        }
    }

    public func cell(
        weekday: Int,
        hour: Int
    ) -> ActivityHeatmapCell? {
        guard
            Self.weekdays.contains(weekday),
            Self.hours.contains(hour)
        else {
            return nil
        }
        return cells[(weekday - 1) * 24 + hour]
    }

    private static func intensity(
        value: Double,
        maximumValue: Double
    ) -> Int {
        guard value > 0, maximumValue > 0 else {
            return 0
        }
        let normalized = sqrt(min(value / maximumValue, 1))
        return min(
            max(Int(ceil(normalized * Double(maximumIntensity))), 1),
            maximumIntensity
        )
    }

    private static func date(
        from value: String,
        calendar: Calendar
    ) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: value)
    }
}

private struct Slot: Hashable {
    let weekday: Int
    let hour: Int
}

private struct Bucket {
    var tokens: Int64 = 0
    var cost = 0.0
    var activeTimeMs: Int64 = 0

    func value(for metric: ActivityMetric) -> Double {
        switch metric {
        case .tokens:
            Double(tokens)
        case .cost:
            cost
        case .duration:
            Double(activeTimeMs)
        }
    }
}

private struct Value {
    let weekday: Int
    let hour: Int
    let value: Double
}
