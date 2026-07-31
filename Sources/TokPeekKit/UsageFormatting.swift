import Foundation

public struct MenuBarSummary: Sendable, Equatable {
    public let tokens: String
    public let cost: String
    public let tokenTrendSymbol: String?
    public let costTrendSymbol: String?

    public init(
        tokens: String,
        cost: String,
        tokenTrendSymbol: String? = nil,
        costTrendSymbol: String? = nil
    ) {
        self.tokens = tokens
        self.cost = cost
        self.tokenTrendSymbol = tokenTrendSymbol
        self.costTrendSymbol = costTrendSymbol
    }

    public var stackedText: String {
        "\(cost)\n\(tokens)"
    }
}

public enum MenuBarPresentation: Sendable, Equatable {
    case summary(MenuBarSummary?)
    case tokens(String?)
    case cost(String?)
    case iconOnly

    public var singleLineText: String? {
        switch self {
        case .summary, .iconOnly:
            nil
        case let .tokens(tokens):
            tokens ?? "—"
        case let .cost(cost):
            cost ?? "$—"
        }
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
    public static func activeFilterCount(
        client: String?,
        model: String?
    ) -> Int {
        [client, model].compactMap { $0 }.count
    }

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

    public static func budgetValue(
        _ value: Double,
        metric: UsageBudgetMetric
    ) -> String {
        switch metric {
        case .cost:
            cost(value)
        case .tokens:
            compactTokens(Int64(value.rounded()))
        }
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
        for report: UsageReport,
        comparison: UsageComparison? = nil
    ) -> MenuBarSummary {
        MenuBarSummary(
            tokens: compactTokens(report.summary.totalTokens),
            cost: menuBarCost(report.summary.totalCost),
            tokenTrendSymbol: comparison.flatMap {
                trendSymbol($0.tokens)
            },
            costTrendSymbol: comparison.flatMap {
                trendSymbol($0.cost)
            }
        )
    }

    public static func menuBarPresentation(
        for metric: MenuBarMetric,
        report: UsageReport?,
        comparison: UsageComparison? = nil
    ) -> MenuBarPresentation {
        switch metric {
        case .summary:
            .summary(
                report.map {
                    menuBarSummary(
                        for: $0,
                        comparison: comparison
                    )
                }
            )
        case .tokens:
            .tokens(
                report.flatMap {
                    menuBarTitle(for: .tokens, report: $0).map {
                        $0 + (
                            comparison.flatMap {
                                trendSymbol($0.tokens)
                            } ?? ""
                        )
                    }
                }
            )
        case .cost:
            .cost(
                report.flatMap {
                    menuBarTitle(for: .cost, report: $0).map {
                        $0 + (
                            comparison.flatMap {
                                trendSymbol($0.cost)
                            } ?? ""
                        )
                    }
                }
            )
        case .iconOnly:
            .iconOnly
        }
    }

    public static func trendText(
        _ trend: UsageTrend
    ) -> String {
        switch trend.direction {
        case .newActivity:
            return "↑ \(Localization.string("New"))"
        case .unchanged:
            return "→ 0%"
        case .increase, .decrease:
            let symbol = trend.direction == .increase ? "↑" : "↓"
            let percentage = abs(trend.fraction ?? 0) * 100
            let value: String
            if percentage > 0 && percentage < 1 {
                value = String(
                    format: "%.1f",
                    locale: Locale(identifier: "en_US_POSIX"),
                    percentage
                )
            } else {
                value = String(
                    format: "%.0f",
                    locale: Locale(identifier: "en_US_POSIX"),
                    percentage
                )
            }
            return "\(symbol) \(value)%"
        }
    }

    public static func trendSymbol(
        _ trend: UsageTrend
    ) -> String? {
        switch trend.direction {
        case .increase, .newActivity: "↑"
        case .decrease: "↓"
        case .unchanged: nil
        }
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
