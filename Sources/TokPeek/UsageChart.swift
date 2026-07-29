import AppKit
import Charts
import SwiftUI

#if canImport(TokPeekKit)
    import TokPeekKit
#endif

struct UsageChart: View {
    let report: UsageReport
    let period: UsagePeriod

    @State private var hoveredPoint: UsageChartPoint?

    var body: some View {
        let layout = UsageChartLayout(
            report: report,
            period: period
        )

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(
                    Localization.string(
                        layout.granularity == .hourly
                            ? "Hourly usage"
                            : "Daily usage"
                    )
                )
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text(rangeTitle(for: layout))
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            if layout.points.isEmpty {
                Text("Usage will appear here after TokPeek finds local sessions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                chart(layout)
            }
        }
        .padding(12)
        .background(TokPeekTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .onChange(of: report.meta.generatedAt) {
            hoveredPoint = nil
        }
    }

    private func chart(
        _ layout: UsageChartLayout
    ) -> some View {
        Chart {
            ForEach(layout.points) { point in
                let isHighlighted =
                    hoveredPoint == nil
                    || hoveredPoint?.id == point.id

                BarMark(
                    x: .value(
                        layout.granularity == .hourly
                            ? "Hour"
                            : "Date",
                        point.date,
                        unit: layout.granularity.calendarComponent
                    ),
                    y: .value(
                        "Tokens",
                        point.totals.tokens
                    ),
                    width: layout.fixedBarWidth.map {
                        .fixed(CGFloat($0))
                    } ?? .automatic
                )
                .foregroundStyle(
                    Color.primary.opacity(
                        isHighlighted ? 0.9 : 0.34
                    )
                )
                .cornerRadius(
                    min(
                        CGFloat(layout.fixedBarWidth ?? 5) / 2,
                        1.5
                    )
                )
            }

            if layout.averageTokens > 0 {
                RuleMark(
                    y: .value(
                        "Average",
                        layout.averageTokens
                    )
                )
                .foregroundStyle(Color.primary.opacity(0.26))
                .lineStyle(
                    StrokeStyle(
                        lineWidth: 1,
                        dash: [3, 3]
                    )
                )
            }

            if let hoveredPoint {
                RuleMark(
                    x: .value(
                        "Date",
                        layout.indicatorDate(
                            for: hoveredPoint
                        )
                    )
                )
                .foregroundStyle(Color.primary.opacity(0.24))
                .lineStyle(StrokeStyle(lineWidth: 1))
                .annotation(
                    position: .overlay,
                    alignment: tooltipAlignment(
                        for: hoveredPoint,
                        in: layout
                    ),
                    spacing: 6
                ) {
                    tooltip(for: hoveredPoint)
                }
            }
        }
        .chartXScale(domain: layout.chartDomain)
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: layout.axisDates) { value in
                AxisValueLabel(
                    centered: false,
                    anchor: UnitPoint(
                        x: value.as(Date.self).map {
                            layout.axisValueLabelAnchorX(
                                for: $0
                            )
                        } ?? 0.5,
                        y: 0
                    )
                ) {
                    if let date = value.as(Date.self) {
                        axisLabel(
                            for: date,
                            granularity: layout.granularity
                        )
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(
                position: .leading,
                values: .automatic(desiredCount: 3)
            ) { value in
                AxisGridLine()
                    .foregroundStyle(
                        TokPeekTheme.divider.opacity(0.7)
                    )
                AxisValueLabel {
                    if let tokens = value.as(Int64.self) {
                        Text(
                            UsageFormatting.compactTokens(tokens)
                        )
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
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
        .frame(height: 158)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Localization.string(
                layout.granularity == .hourly
                    ? "Hourly token usage chart"
                    : "Daily token usage chart"
            )
        )
        .accessibilityValue(accessibilityValue(for: layout))
    }

    private func updateHover(
        _ phase: HoverPhase,
        proxy: ChartProxy,
        geometry: GeometryProxy,
        layout: UsageChartLayout
    ) {
        switch phase {
        case .active(let location):
            guard let plotFrame = proxy.plotFrame else {
                setHoveredPoint(nil)
                return
            }

            let frame = geometry[plotFrame]
            guard
                frame.contains(location),
                let date: Date = proxy.value(
                    atX: location.x - frame.origin.x
                )
            else {
                setHoveredPoint(nil)
                return
            }

            setHoveredPoint(
                layout.point(nearestTo: date)
            )

        case .ended:
            setHoveredPoint(nil)
        }
    }

    private func setHoveredPoint(
        _ point: UsageChartPoint?
    ) {
        guard hoveredPoint?.id != point?.id else {
            return
        }
        hoveredPoint = point
    }

    private func tooltipAlignment(
        for point: UsageChartPoint,
        in layout: UsageChartLayout
    ) -> Alignment {
        let midpoint = layout.startDate.addingTimeInterval(
            layout.endDate.timeIntervalSince(layout.startDate) / 2
        )
        return point.date > midpoint
            ? .topTrailing
            : .topLeading
    }

    private func tooltip(
        for point: UsageChartPoint
    ) -> some View {
        UsageTooltip(
            title: point.date.formatted(
                period.usesHourlyChart
                    ? .dateTime
                        .year()
                        .month(.abbreviated)
                        .day()
                        .hour()
                    : .dateTime
                        .year()
                        .month(.abbreviated)
                        .day()
            ),
            rows: [
                UsageTooltipRow(
                    label: Localization.string("Token"),
                    value: UsageFormatting.compactTokens(
                        point.totals.tokens
                    )
                ),
                UsageTooltipRow(
                    label: Localization.string("Cost"),
                    value: UsageFormatting.cost(
                        point.totals.cost
                    )
                ),
                UsageTooltipRow(
                    label: Localization.string("Messages"),
                    value: String(
                        point.totals.messages
                    )
                ),
            ]
        )
    }

    private func rangeTitle(
        for layout: UsageChartLayout
    ) -> String {
        if layout.granularity == .hourly {
            return period.title
        }
        return Localization.format(
            "Last %lld days",
            [Int64(layout.dayCount)]
        )
    }

    @ViewBuilder
    private func axisLabel(
        for date: Date,
        granularity: UsageChartGranularity
    ) -> some View {
        if granularity == .hourly {
            Text(
                date,
                format: .dateTime.hour(.twoDigits(amPM: .omitted))
            )
        } else {
            Text(
                date,
                format: .dateTime
                    .month(.defaultDigits)
                    .day(.defaultDigits)
            )
        }
    }

    private func accessibilityValue(
        for layout: UsageChartLayout
    ) -> String {
        if layout.granularity == .hourly {
            return Localization.format(
                "%lld total tokens over 24 displayed hours",
                [layout.totalTokens]
            )
        }
        return Localization.format(
            "%lld total tokens over %lld displayed days",
            [
                layout.totalTokens,
                Int64(layout.dayCount),
            ]
        )
    }
}
