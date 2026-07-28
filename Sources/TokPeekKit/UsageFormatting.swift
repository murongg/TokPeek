import Foundation

public struct MenuBarSummary: Sendable, Equatable {
    public let tokens: String
    public let cost: String

    public var stackedText: String {
        "\(cost)\n\(tokens)"
    }
}

public struct UsageTooltipMetrics: Sendable, Equatable {
    public let tokens: String
    public let cost: String
    public let messages: String
    public let percentage: String
}

public enum UsageTooltipAppearance {
    public static let lightBackgroundWhite = 0.98
    public static let darkBackgroundWhite = 0.12
    public static let backgroundOpacity = 1.0
}

public enum UsageFormatting {
    public static func compactTokens(_ value: Int64) -> String {
        let magnitude = abs(value)

        if magnitude >= 1_000_000_000 {
            return compact(value, divisor: 1_000_000_000, suffix: "B")
        }
        if magnitude >= 1_000_000 {
            return compact(value, divisor: 1_000_000, suffix: "M")
        }
        if magnitude >= 1_000 {
            return compact(value, divisor: 1_000, suffix: "K")
        }

        return String(value)
    }

    public static func cost(_ value: Double) -> String {
        value.formatted(
            .currency(code: "USD")
                .precision(.fractionLength(2))
        )
    }

    public static func percentage(_ fraction: Double) -> String {
        let clamped = min(max(fraction, 0), 1)
        return clamped.formatted(
            .percent.precision(
                .fractionLength(
                    clamped > 0 && clamped < 0.01 ? 1 : 0
                )
            )
        )
    }

    public static func tooltipMetrics(
        tokens: Int64,
        cost: Double,
        messages: Int,
        fraction: Double
    ) -> UsageTooltipMetrics {
        UsageTooltipMetrics(
            tokens: compactTokens(tokens),
            cost: self.cost(cost),
            messages: String(messages),
            percentage: percentage(fraction)
        )
    }

    public static func menuBarTitle(
        for metric: MenuBarMetric,
        report: UsageReport
    ) -> String? {
        switch metric {
        case .summary:
            nil
        case .tokens:
            compactTokens(report.summary.totalTokens)
        case .cost:
            menuBarCost(report.summary.totalCost)
        case .iconOnly:
            nil
        }
    }

    public static func menuBarSummary(
        for report: UsageReport
    ) -> MenuBarSummary {
        MenuBarSummary(
            tokens: compactTokens(report.summary.totalTokens),
            cost: menuBarCost(report.summary.totalCost)
        )
    }

    private static func compact(
        _ value: Int64,
        divisor: Double,
        suffix: String
    ) -> String {
        let scaled = Double(value) / divisor
        let rounded = (scaled * 10).rounded(.toNearestOrAwayFromZero) / 10

        if rounded.rounded() == rounded {
            return "\(Int64(rounded))\(suffix)"
        }

        return String(
            format: "%.1f%@",
            locale: Locale(identifier: "en_US_POSIX"),
            rounded,
            suffix
        )
    }

    private static func menuBarCost(
        _ value: Double
    ) -> String {
        String(
            format: "$%.2f",
            locale: Locale(identifier: "en_US_POSIX"),
            value
        )
    }
}
