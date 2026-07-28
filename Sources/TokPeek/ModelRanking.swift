import SwiftUI

#if canImport(TokPeekKit)
    import TokPeekKit
#endif

struct ModelRanking: View {
    let summaries: [ModelUsageSummary]

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(
                .flexible(minimum: 0),
                spacing: 16,
                alignment: .top
            ),
            count: ModelRankingLayout.columnCount
        )
    }

    private var rankedSummaries: [ModelUsageSummary] {
        Array(
            summaries
                .filter { $0.tokens > 0 }
                .sorted {
                    if $0.tokens == $1.tokens {
                        return $0.modelId < $1.modelId
                    }
                    return $0.tokens > $1.tokens
                }
                .prefix(ModelRankingLayout.maximumVisibleItems)
        )
    }

    private var totalTokens: Int64 {
        summaries.reduce(0) { partialResult, summary in
            let (value, overflow) = partialResult.addingReportingOverflow(
                summary.tokens
            )
            return overflow ? .max : value
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("By model")
                .font(.subheadline.weight(.semibold))

            if rankedSummaries.isEmpty {
                Text("Model details are not available for this period.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(
                    columns: gridColumns,
                    alignment: .leading,
                    spacing: 12
                ) {
                    ForEach(
                        Array(rankedSummaries.enumerated()),
                        id: \.element.id
                    ) { index, summary in
                        ModelRankRow(
                            rank: index + 1,
                            summary: summary,
                            totalTokens: totalTokens,
                            maximumTokens: rankedSummaries.first?.tokens ?? 1
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}

private struct ModelRankRow: View {
    let rank: Int
    let summary: ModelUsageSummary
    let totalTokens: Int64
    let maximumTokens: Int64
    @State private var isHoveringBar = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(String(rank))
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 14, alignment: .leading)

            VStack(spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(displayName)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(summary.modelId)

                        if !summary.providerId.isEmpty {
                            Text(providerName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 1) {
                        Text(
                            UsageFormatting.compactTokens(
                                summary.tokens
                            )
                        )
                        .font(.caption.monospacedDigit())

                        Text(percentage)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(TokPeekTheme.surface)
                            .frame(height: 5)

                        Capsule()
                            .fill(Color.primary.opacity(0.82))
                            .frame(
                                width: proxy.size.width
                                    * progress,
                                height: 5
                            )
                    }
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.height
                    )
                }
                .frame(height: 12)
                .contentShape(Rectangle())
                .onHover { isHoveringBar = $0 }
                .overlay(alignment: .topTrailing) {
                    if isHoveringBar {
                        UsageTooltip(
                            title: displayName,
                            rows: [
                                UsageTooltipRow(
                                    label: Localization.string("Token"),
                                    value: tooltipMetrics.tokens
                                ),
                                UsageTooltipRow(
                                    label: Localization.string("Cost"),
                                    value: tooltipMetrics.cost
                                ),
                                UsageTooltipRow(
                                    label: Localization.string("Messages"),
                                    value: tooltipMetrics.messages
                                ),
                                UsageTooltipRow(
                                    label: Localization.string("Share"),
                                    value: tooltipMetrics.percentage
                                ),
                            ]
                        )
                        .offset(y: -91)
                    }
                }
            }
        }
        .zIndex(isHoveringBar ? 2 : 0)
        .accessibilityElement(children: .combine)
    }

    private var displayName: String {
        summary.modelId.isEmpty
            ? Localization.string("Unknown model")
            : summary.modelId
    }

    private var providerName: String {
        summary.providerId
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }

    private var progress: CGFloat {
        CGFloat(
            Double(summary.tokens)
                / Double(max(maximumTokens, 1))
        )
    }

    private var percentage: String {
        UsageFormatting.percentage(
            Double(summary.tokens)
                / Double(max(totalTokens, 1))
        )
    }

    private var tooltipMetrics: UsageTooltipMetrics {
        UsageFormatting.tooltipMetrics(
            tokens: summary.tokens,
            cost: summary.cost,
            messages: summary.messages,
            fraction: Double(summary.tokens)
                / Double(max(totalTokens, 1))
        )
    }
}
