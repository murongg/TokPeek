import Charts
import Foundation
import SwiftUI

#if canImport(TokPeekKit)
    import TokPeekKit
#endif

struct ClientBreakdown: View {
    let summaries: [ClientUsageSummary]
    @State private var hoveredSliceID: String?

    var body: some View {
        let layout = ClientBreakdownLayout(
            summaries: summaries
        )

        VStack(alignment: .leading, spacing: 10) {
            Text("By client")
                .font(.subheadline.weight(.semibold))

            if layout.slices.isEmpty {
                Text("Client details are not available for this period.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack(alignment: .center, spacing: 16) {
                    donutChart(layout)
                        // The tooltip extends into the legend's bounds, so the
                        // chart's entire sibling layer must rise above it.
                        .zIndex(
                            ClientBreakdownLayout.chartLayer(
                                isTooltipVisible: hoveredSliceID != nil
                            )
                        )

                    VStack(spacing: 8) {
                        ForEach(
                            Array(layout.slices.enumerated()),
                            id: \.element.id
                        ) { index, slice in
                            ClientLegendRow(
                                slice: slice,
                                color: segmentColor(at: index)
                            )
                            .opacity(
                                hoveredSliceID == nil
                                    || hoveredSliceID == slice.id
                                    ? 1
                                    : 0.42
                            )
                            .onHover { isHovering in
                                setHoveredSlice(
                                    isHovering ? slice.id : nil,
                                    ending: slice.id
                                )
                            }
                        }
                    }
                    .zIndex(ClientBreakdownLayout.legendLayer)
                }
            }
        }
        .onChange(of: summaries) {
            hoveredSliceID = nil
        }
    }

    private func donutChart(
        _ layout: ClientBreakdownLayout
    ) -> some View {
        ZStack {
            Chart(
                Array(layout.slices.enumerated()),
                id: \.element.id
            ) { index, slice in
                SectorMark(
                    angle: .value(
                        "Tokens",
                        slice.tokens
                    ),
                    innerRadius: .ratio(0.62)
                )
                .foregroundStyle(segmentColor(at: index))
                .opacity(
                    hoveredSliceID == nil
                        || hoveredSliceID == slice.id
                        ? 1
                        : 0.3
                )
            }
            .chartLegend(.hidden)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            updateHover(
                                phase,
                                proxy: proxy,
                                geometry: geometry,
                                layout: layout
                            )
                        }
                }
            }

            VStack(spacing: 1) {
                Text(
                    UsageFormatting.compactTokens(
                        layout.totalTokens
                    )
                )
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .minimumScaleFactor(0.75)

                Text("Token")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .allowsHitTesting(false)
        }
        .frame(width: 126, height: 126)
        .overlay(alignment: .topLeading) {
            if let hoveredSlice = hoveredSlice(in: layout) {
                let metrics = UsageFormatting.tooltipMetrics(
                    tokens: hoveredSlice.tokens,
                    cost: hoveredSlice.cost,
                    messages: hoveredSlice.messages,
                    fraction: hoveredSlice.fraction
                )

                UsageTooltip(
                    title: displayName(for: hoveredSlice),
                    rows: [
                        UsageTooltipRow(
                            label: Localization.string("Token"),
                            value: metrics.tokens
                        ),
                        UsageTooltipRow(
                            label: Localization.string("Cost"),
                            value: metrics.cost
                        ),
                        UsageTooltipRow(
                            label: Localization.string("Messages"),
                            value: metrics.messages
                        ),
                        UsageTooltipRow(
                            label: Localization.string("Share"),
                            value: metrics.percentage
                        ),
                    ]
                )
                .offset(x: 102, y: -8)
                .zIndex(3)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Total tokens")
        .accessibilityValue(
            Text(
                UsageFormatting.compactTokens(
                    layout.totalTokens
                )
            )
        )
    }

    private func updateHover(
        _ phase: HoverPhase,
        proxy: ChartProxy,
        geometry: GeometryProxy,
        layout: ClientBreakdownLayout
    ) {
        switch phase {
        case .active(let location):
            guard let plotFrame = proxy.plotFrame else {
                setHoveredSlice(nil)
                return
            }

            let frame = geometry[plotFrame]
            let deltaX = location.x - frame.midX
            let deltaY = location.y - frame.midY
            let radius = sqrt(deltaX * deltaX + deltaY * deltaY)
            let outerRadius = min(frame.width, frame.height) / 2
            guard
                radius >= outerRadius * 0.62,
                radius <= outerRadius
            else {
                setHoveredSlice(nil)
                return
            }

            // SectorMark starts at 12 o'clock and advances clockwise, so the
            // hover angle must use the same origin and direction.
            var angle = atan2(deltaX, -deltaY)
            if angle < 0 {
                angle += 2 * .pi
            }
            let fraction = angle / (2 * .pi)
            setHoveredSlice(
                layout.slice(atFraction: fraction)?.id
            )

        case .ended:
            setHoveredSlice(nil)
        }
    }

    private func hoveredSlice(
        in layout: ClientBreakdownLayout
    ) -> ClientUsageSlice? {
        layout.slices.first { $0.id == hoveredSliceID }
    }

    private func setHoveredSlice(
        _ id: String?,
        ending expectedID: String? = nil
    ) {
        if let expectedID,
            id == nil,
            hoveredSliceID != expectedID
        {
            return
        }
        guard hoveredSliceID != id else {
            return
        }
        hoveredSliceID = id
    }

    private func displayName(
        for slice: ClientUsageSlice
    ) -> String {
        guard !slice.isOther else {
            return Localization.string("Other")
        }

        return slice.client
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }

    private func segmentColor(
        at index: Int
    ) -> Color {
        let opacities = [0.92, 0.72, 0.54, 0.38, 0.22]
        return Color.primary.opacity(
            opacities[min(index, opacities.count - 1)]
        )
    }
}

private struct ClientLegendRow: View {
    let slice: ClientUsageSlice
    let color: Color

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(displayName)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)

                Text(
                    UsageFormatting.compactTokens(
                        slice.tokens
                    )
                )
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            Text(percentage)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 20)
        .accessibilityElement(children: .combine)
    }

    private var displayName: String {
        guard !slice.isOther else {
            return Localization.string("Other")
        }

        return slice.client
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }

    private var percentage: String {
        slice.fraction.formatted(
            .percent.precision(
                .fractionLength(
                    slice.fraction < 0.01 ? 1 : 0
                )
            )
        )
    }
}
