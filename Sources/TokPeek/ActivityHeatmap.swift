import SwiftUI

#if canImport(TokPeekKit)
    import TokPeekKit
#endif

struct ActivityHeatmap: View {
    private static let contentPadding = 12.0

    let report: UsageReport?
    let isLoading: Bool
    let errorMessage: String?
    let retry: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var metric = ActivityMetric.tokens

    private let geometry = ActivityHeatmapGeometry(
        contentWidth: DashboardLayoutMetrics.contentWidth
            - contentPadding * 2
    )

    init(
        report: UsageReport?,
        isLoading: Bool = false,
        errorMessage: String? = nil,
        retry: @escaping () -> Void = {}
    ) {
        self.report = report
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.retry = retry
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if let report {
                let layout = ActivityHeatmapLayout(
                    report: report,
                    metric: metric
                )
                reportContent(layout)
            } else {
                emptyReportState
            }
        }
        .padding(CGFloat(Self.contentPadding))
        .background(
            TokPeekTheme.surface,
            in: RoundedRectangle(cornerRadius: 12)
        )
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.18),
            value: metric
        )
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Label("Activity by hour", systemImage: "calendar")
                    .font(.subheadline.weight(.semibold))

                Text("Last 30 days")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("Metric", selection: $metric) {
                ForEach(ActivityMetric.allCases) { metric in
                    Text(metric.localizedTitle)
                        .tag(metric)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.small)
            .frame(width: 178)
            .accessibilityLabel("Metric")
        }
    }

    @ViewBuilder
    private func reportContent(
        _ layout: ActivityHeatmapLayout
    ) -> some View {
        if layout.isMetricAvailable {
            ActivityHeatmapGrid(
                layout: layout,
                geometry: geometry,
                metric: metric
            )
        } else {
            unavailableState
        }

        if isLoading {
            activityStatus(
                title: Localization.string("Loading hourly activity"),
                systemImage: nil,
                showsRetry: false
            )
        } else if errorMessage != nil {
            activityStatus(
                title: Localization.string(
                    "Couldn’t load hourly activity."
                ),
                systemImage: "exclamationmark.triangle",
                showsRetry: true
            )
        }
    }

    private var unavailableState: some View {
        Text(
            Localization.string(
                metric == .duration
                    ? "Duration details are not available for this selection."
                    : "Hourly activity is not available for this period."
            )
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: 112)
    }

    @ViewBuilder
    private var emptyReportState: some View {
        if isLoading {
            ProgressView {
                Text("Loading hourly activity")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .controlSize(.small)
            .frame(maxWidth: .infinity, minHeight: 112)
        } else if errorMessage != nil {
            VStack(spacing: 8) {
                Label(
                    "Couldn’t load hourly activity.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .help(errorMessage ?? "")

                Button("Retry", action: retry)
                    .controlSize(.small)
            }
            .frame(maxWidth: .infinity, minHeight: 112)
        } else {
            unavailableState
        }
    }

    private func activityStatus(
        title: String,
        systemImage: String?,
        showsRetry: Bool
    ) -> some View {
        HStack(spacing: 6) {
            if isLoading {
                ProgressView()
                    .controlSize(.mini)
            } else if let systemImage {
                Image(systemName: systemImage)
            }

            Text(title)
                .lineLimit(1)

            Spacer()

            if showsRetry {
                Button("Retry", action: retry)
                    .buttonStyle(.borderless)
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .help(errorMessage ?? "")
    }

}

private struct ActivityHeatmapGrid: View {
    let layout: ActivityHeatmapLayout
    let geometry: ActivityHeatmapGeometry
    let metric: ActivityMetric

    @State private var hoveredCellID: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            heatmap
            intensityLegend
        }
        .onChange(of: layout) {
            hoveredCellID = nil
        }
        .onChange(of: metric) {
            hoveredCellID = nil
        }
    }

    private var heatmap: some View {
        VStack(
            alignment: .leading,
            spacing: CGFloat(ActivityHeatmapGeometry.rowSpacing)
        ) {
            ForEach(ActivityHeatmapLayout.weekdays, id: \.self) { weekday in
                HStack(
                    spacing: CGFloat(
                        ActivityHeatmapGeometry.labelSpacing
                    )
                ) {
                    Text(weekdayTitle(weekday))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(
                            width: CGFloat(
                                ActivityHeatmapGeometry
                                    .weekdayLabelWidth
                            ),
                            alignment: .leading
                        )

                    HStack(
                        spacing: CGFloat(
                            ActivityHeatmapGeometry.cellSpacing
                        )
                    ) {
                        ForEach(ActivityHeatmapLayout.hours, id: \.self) { hour in
                            if let cell = layout.cell(
                                weekday: weekday,
                                hour: hour
                            ) {
                                heatmapCell(cell)
                            }
                        }
                    }
                }
            }

            HStack(
                spacing: CGFloat(
                    ActivityHeatmapGeometry.labelSpacing
                )
            ) {
                Color.clear
                    .frame(
                        width: CGFloat(
                            ActivityHeatmapGeometry.weekdayLabelWidth
                        ),
                        height: 1
                    )

                hourAxis
            }
        }
        .contentShape(Rectangle())
        // One tracker avoids 168 cell-level tracking areas churning while the
        // ScrollView moves underneath a stationary pointer.
        .onContinuousHover(perform: updateHover)
    }

    private func heatmapCell(
        _ cell: ActivityHeatmapCell
    ) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(cellColor(cell.intensity))
            .frame(
                width: CGFloat(geometry.cellSize),
                height: CGFloat(geometry.cellSize)
            )
            .overlay(alignment: tooltipAlignment(for: cell.hour)) {
                if hoveredCellID == cell.id {
                    tooltip(for: cell)
                        .offset(y: -76)
                }
            }
            .zIndex(hoveredCellID == cell.id ? 2 : 0)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                Localization.format(
                    "%@ at %@",
                    [
                        weekdayTitle(cell.weekday),
                        hourTitle(cell.hour),
                    ]
                )
            )
            .accessibilityValue(metric.valueTitle(cell.value))
    }

    private var hourAxis: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(stride(from: 0, through: 21, by: 3)), id: \.self) { hour in
                Text(String(format: "%02d", hour))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .offset(
                        x: CGFloat(hour)
                            * CGFloat(
                                geometry.cellSize
                                    + ActivityHeatmapGeometry.cellSpacing
                            ) - 1
                    )
            }
        }
        .frame(
            width: CGFloat(geometry.gridWidth),
            height: 12,
            alignment: .topLeading
        )
    }

    private var intensityLegend: some View {
        HStack(spacing: 5) {
            Spacer()

            Text("Less")
                .font(.caption2)
                .foregroundStyle(.secondary)

            ForEach(0...ActivityHeatmapLayout.maximumIntensity, id: \.self) {
                intensity in
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(cellColor(intensity))
                    .frame(width: 10, height: 10)
            }

            Text("More")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func updateHover(
        _ phase: HoverPhase
    ) {
        let nextID: Int?
        switch phase {
        case .active(let location):
            if let index = geometry.cellIndex(
                atX: Double(location.x),
                y: Double(location.y)
            ), layout.cells.indices.contains(index) {
                nextID = layout.cells[index].id
            } else {
                nextID = nil
            }
        case .ended:
            nextID = nil
        }

        guard hoveredCellID != nextID else {
            return
        }
        hoveredCellID = nextID
    }

    private func tooltip(
        for cell: ActivityHeatmapCell
    ) -> some View {
        UsageTooltip(
            title: Localization.format(
                "%@ at %@",
                [
                    weekdayTitle(cell.weekday),
                    hourTitle(cell.hour),
                ]
            ),
            rows: [
                UsageTooltipRow(
                    label: metric.localizedTitle,
                    value: metric.valueTitle(cell.value)
                )
            ]
        )
    }

    private func weekdayTitle(
        _ weekday: Int
    ) -> String {
        let symbols = Calendar.current.shortWeekdaySymbols
        guard symbols.indices.contains(weekday - 1) else {
            return String(weekday)
        }
        return symbols[weekday - 1]
    }

    private func hourTitle(
        _ hour: Int
    ) -> String {
        String(
            format: "%02d:00–%02d:00",
            hour,
            (hour + 1) % 24
        )
    }

    private func cellColor(
        _ intensity: Int
    ) -> Color {
        let opacities: [Double] = [
            0.065,
            0.20,
            0.32,
            0.45,
            0.59,
            0.74,
            0.92,
        ]
        return Color.primary.opacity(
            opacities[min(max(intensity, 0), opacities.count - 1)]
        )
    }

    private func tooltipAlignment(
        for hour: Int
    ) -> Alignment {
        hour >= 16 ? .topTrailing : .topLeading
    }
}

extension ActivityMetric {
    fileprivate var localizedTitle: String {
        switch self {
        case .tokens:
            Localization.string("Token")
        case .cost:
            Localization.string("Cost")
        case .duration:
            Localization.string("Duration")
        }
    }

    fileprivate func valueTitle(
        _ value: Double
    ) -> String {
        switch self {
        case .tokens:
            UsageFormatting.compactTokens(
                Int64(value.rounded())
            )
        case .cost:
            UsageFormatting.cost(value)
        case .duration:
            UsageFormatting.activeDuration(
                milliseconds: Int64(value.rounded())
            )
        }
    }
}
