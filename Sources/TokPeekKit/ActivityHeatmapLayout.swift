import Foundation

public enum ActivityMetric: String, CaseIterable, Identifiable, Sendable {
    case tokens
    case cost
    case duration

    public var id: String { rawValue }
}

public struct ActivityHeatmapGeometry: Sendable, Equatable {
    public static let weekdayLabelWidth = 30.0
    public static let labelSpacing = 8.0
    public static let cellSpacing = 3.0
    public static let rowSpacing = 6.0
    public static let columnCount = 24
    public static let rowCount = 7

    public let cellSize: Double
    public let gridWidth: Double
    public let totalWidth: Double

    public init(contentWidth: Double) {
        let gridSpacing =
            Self.cellSpacing
            * Double(Self.columnCount - 1)
        let availableCellWidth =
            contentWidth
            - Self.weekdayLabelWidth
            - Self.labelSpacing
            - gridSpacing
        cellSize = max(
            availableCellWidth / Double(Self.columnCount),
            0
        )
        gridWidth =
            cellSize * Double(Self.columnCount)
            + gridSpacing
        totalWidth =
            Self.weekdayLabelWidth
            + Self.labelSpacing
            + gridWidth
    }

    public func cellIndex(
        atX x: Double,
        y: Double
    ) -> Int? {
        guard cellSize > 0, y >= 0 else {
            return nil
        }

        let gridX = x - Self.weekdayLabelWidth - Self.labelSpacing
        guard gridX >= 0 else {
            return nil
        }

        let columnStep = cellSize + Self.cellSpacing
        let rowStep = cellSize + Self.rowSpacing
        let column = Int(gridX / columnStep)
        let row = Int(y / rowStep)
        guard
            column >= 0,
            column < Self.columnCount,
            row >= 0,
            row < Self.rowCount,
            gridX - Double(column) * columnStep < cellSize,
            y - Double(row) * rowStep < cellSize
        else {
            return nil
        }

        return row * Self.columnCount + column
    }
}

public struct ActivityHeatmapCell: Identifiable, Sendable, Equatable {
    public var id: Int { weekday * 24 + hour }

    public let weekday: Int
    public let hour: Int
    public let value: Double
    public let intensity: Int
}

public struct ActivityHeatmapLayout: Sendable, Equatable {
    public static let hours = Array(0..<24)
    public static let maximumIntensity = 6

    public let weekdays: [Int]
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
        var latestDate: Date?
        let hourFormatter = Self.hourFormatter(calendar: calendar)

        for contribution in report.hourlyContributions {
            guard let date = hourFormatter.date(from: contribution.hour) else {
                continue
            }

            parsedContributionCount += 1
            latestDate = max(latestDate ?? date, date)
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

        let endDate =
            latestDate
            ?? Self.day(
                from: report.meta.dateRangeEnd,
                calendar: calendar
            )
            ?? Date()
        weekdays = Self.weekdayOrder(
            endingAt: endDate,
            calendar: calendar
        )

        isMetricAvailable =
            switch metric {
            case .tokens, .cost:
                parsedContributionCount > 0
            case .duration:
                hasActiveTime
            }

        let values = weekdays.flatMap { weekday in
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
            let row = weekdays.firstIndex(of: weekday),
            Self.hours.contains(hour)
        else {
            return nil
        }
        return cells[row * Self.hours.count + hour]
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

    private static func weekdayOrder(
        endingAt endDate: Date,
        calendar: Calendar
    ) -> [Int] {
        let endDay = calendar.startOfDay(for: endDate)
        return (-6...0).compactMap { offset in
            calendar.date(
                byAdding: .day,
                value: offset,
                to: endDay
            ).map {
                calendar.component(.weekday, from: $0)
            }
        }
    }

    private static func hourFormatter(
        calendar: Calendar
    ) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }

    private static func day(
        from value: String,
        calendar: Calendar
    ) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
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
