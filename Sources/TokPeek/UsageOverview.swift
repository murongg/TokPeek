import SwiftUI

#if canImport(TokPeekKit)
    import TokPeekKit
#endif

struct UsageOverview: View {
    let report: UsageReport

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(
                        UsageFormatting.compactTokens(
                            report.summary.totalTokens
                        )
                    )
                    .font(.title2.monospacedDigit().weight(.semibold))

                    Text("tokens")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(UsageFormatting.cost(report.summary.totalCost))
                    .font(.body.monospacedDigit().weight(.semibold))
                    .accessibilityLabel(
                        Localization.format(
                            "Estimated cost %@",
                            [
                                UsageFormatting.cost(
                                    report.summary.totalCost
                                )
                            ]
                        )
                    )
            }

            HStack(spacing: 0) {
                metadata(
                    value: "\(report.summary.activeDays)",
                    label: Localization.string(
                        report.summary.activeDays == 1
                            ? "active day"
                            : "active days"
                    )
                )

                Divider()
                    .frame(height: 22)
                    .padding(.horizontal, 12)

                metadata(
                    value: UsageFormatting.compactTokens(
                        Int64(report.summary.averagePerDay)
                    ),
                    label: Localization.string("daily avg")
                )

                Divider()
                    .frame(height: 22)
                    .padding(.horizontal, 12)

                metadata(
                    value: "\(report.summary.clients.count)",
                    label: Localization.string(
                        report.summary.clients.count == 1
                            ? "source"
                            : "sources"
                    )
                )
            }

            UsageComposition(composition: report.tokenComposition)
        }
    }

    private func metadata(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct UsageComposition: View {
    let composition: TokenComposition
    @State private var hoveredItemID: String?

    private var items: [CompositionItem] {
        [
            CompositionItem(
                name: Localization.string("Input"),
                value: composition.input,
                color: TokPeekTheme.compositionInput
            ),
            CompositionItem(
                name: Localization.string("Output"),
                value: composition.output,
                color: TokPeekTheme.compositionOutput
            ),
            CompositionItem(
                name: Localization.string("Cache"),
                value: composition.cache,
                color: TokPeekTheme.compositionCache
            ),
            CompositionItem(
                name: Localization.string("Reasoning"),
                value: composition.reasoning,
                color: TokPeekTheme.compositionReasoning
            ),
        ]
    }

    private var visibleItems: [CompositionItem] {
        items.filter { $0.value > 0 }
    }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                let spacing = CGFloat(max(visibleItems.count - 1, 0)) * 2
                let availableWidth = max(geometry.size.width - spacing, 0)

                HStack(spacing: 2) {
                    ForEach(visibleItems) { item in
                        Capsule()
                            .fill(item.color)
                            .opacity(
                                hoveredItemID == nil
                                    || hoveredItemID == item.id
                                    ? 1
                                    : 0.3
                            )
                            .frame(
                                width: availableWidth
                                    * CGFloat(item.value)
                                    / CGFloat(max(composition.total, 1)),
                                height: 7
                            )
                            .contentShape(Rectangle())
                            .onHover { isHovering in
                                if isHovering {
                                    hoveredItemID = item.id
                                } else if hoveredItemID == item.id {
                                    hoveredItemID = nil
                                }
                            }
                    }
                }
            }
            .frame(height: 13)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), alignment: .leading),
                    GridItem(.flexible(), alignment: .leading),
                ],
                alignment: .leading,
                spacing: 5
            ) {
                ForEach(items) { item in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(item.color)
                            .frame(width: 7, height: 7)
                        Text(item.name)
                            .foregroundStyle(.secondary)
                        Text(UsageFormatting.compactTokens(item.value))
                            .monospacedDigit()
                    }
                    .font(.caption2)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if let hoveredItem {
                UsageTooltip(
                    title: hoveredItem.name,
                    rows: [
                        UsageTooltipRow(
                            label: Localization.string("Token"),
                            value: UsageFormatting.compactTokens(
                                hoveredItem.value
                            )
                        ),
                        UsageTooltipRow(
                            label: Localization.string("Share"),
                            value: UsageFormatting.percentage(
                                Double(hoveredItem.value)
                                    / Double(max(composition.total, 1))
                            )
                        ),
                    ]
                )
                .offset(y: -62)
                .zIndex(2)
            }
        }
        .onChange(of: composition) {
            hoveredItemID = nil
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Token composition")
        .accessibilityValue(
            Localization.format(
                "Input %lld, output %lld, cache %lld, reasoning %lld",
                [
                    composition.input,
                    composition.output,
                    composition.cache,
                    composition.reasoning,
                ]
            )
        )
    }

    private var hoveredItem: CompositionItem? {
        items.first { $0.id == hoveredItemID }
    }
}

private struct CompositionItem: Identifiable {
    let name: String
    let value: Int64
    let color: Color

    var id: String { name }
}
