import SwiftUI

#if canImport(TokPeekKit)
    import TokPeekKit
#endif

struct BudgetOverview: View {
    let snapshot: UsageBudgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(
                    "Budget",
                    systemImage: "gauge.with.dots.needle.67percent"
                )
                .font(.caption.weight(.semibold))

                Spacer()

                Text(snapshot.budget.period.title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(usageText)
                    .font(.caption.monospacedDigit().weight(.medium))

                Spacer()

                Text(progressText)
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(progressColor)
            }

            ProgressView(
                value: min(max(snapshot.progress, 0), 1)
            )
            .progressViewStyle(.linear)
            .tint(progressColor)

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(
                    Localization.format(
                        "Remaining %@",
                        [
                            UsageFormatting.budgetValue(
                                snapshot.remaining,
                                metric: snapshot.budget.metric
                            )
                        ]
                    )
                )

                Spacer()

                Text(
                    Localization.format(
                        "Projected this month %@",
                        [
                            UsageFormatting.cost(
                                snapshot.forecast.projectedCost
                            )
                        ]
                    )
                )
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            TokPeekTheme.surface,
            in: RoundedRectangle(cornerRadius: 12)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Budget")
        .accessibilityValue(
            "\(usageText), \(progressText)"
        )
    }

    private var usageText: String {
        let used = UsageFormatting.budgetValue(
            snapshot.used,
            metric: snapshot.budget.metric
        )
        let limit = UsageFormatting.budgetValue(
            snapshot.budget.limit,
            metric: snapshot.budget.metric
        )
        return "\(used) / \(limit)"
    }

    private var progressText: String {
        snapshot.progress >= 1
            ? Localization.string("Limit reached")
            : UsageFormatting.percentage(snapshot.progress)
    }

    private var progressColor: Color {
        if snapshot.progress >= 1 {
            return .red
        }
        if snapshot.progress >= 0.8 {
            return .orange
        }
        return .primary
    }
}
