import SwiftUI

#if canImport(TokPeekKit)
    import TokPeekKit
#endif

struct ActivityHeatmap: View {
    let report: UsageReport?
    let isLoading: Bool
    let errorMessage: String?
    let retry: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var metric = ActivityMetric.tokens
    @State private var hoveredCellID: Int?

    private let cellSize: CGFloat = 12
    private let cellSpacing: CGFloat = 3
    private let weekdayLabelWidth: CGFloat = 30

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
        .padding(12)
        .background(
            TokPeekTheme.surface,
            in: RoundedRectangle(cornerRadius: 12)
        )
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.18),
            value: metric
        )
        .onChange(of: report?.meta.generatedAt) {
            hoveredCellID = nil
        }
        .onChange(of: metric) {
            hoveredCellID = nil
        }
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
                    Text(metricTitle(metric))
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
            heatmap(layout)
            intensityLegend
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

    private func heatmap(
        _ layout: ActivityHeatmapLayout
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(ActivityHeatmapLayout.weekdays, id: \.self) { weekday in
                HStack(spacing: 8) {
                    Text(weekdayTitle(weekday))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(
                            width: weekdayLabelWidth,
                            alignment: .leading
                        )

                    HStack(spacing: cellSpacing) {
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

            HStack(spacing: 8) {
                Color.clear
                    .frame(width: weekdayLabelWidth, height: 1)

                hourAxis
            }
        }
    }

    private func heatmapCell(
        _ cell: ActivityHeatmapCell
    ) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(cellColor(cell.intensity))
            .frame(width: cellSize, height: cellSize)
            .contentShape(RoundedRectangle(cornerRadius: 3))
            .onHover { isHovering in
                hoveredCellID = isHovering ? cell.id : nil
            }
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
            .accessibilityValue(valueTitle(cell.value))
    }

    private var hourAxis: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(stride(from: 0, through: 21, by: 3)), id: \.self) { hour in
                Text(String(format: "%02d", hour))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .offset(
                        x: CGFloat(hour) * (cellSize + cellSpacing) - 1
                    )
            }
        }
        .frame(
            width: gridWidth,
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
                    label: metricTitle(metric),
                    value: valueTitle(cell.value)
                )
            ]
        )
    }

    private func metricTitle(
        _ metric: ActivityMetric
    ) -> String {
        switch metric {
        case .tokens:
            Localization.string("Token")
        case .cost:
            Localization.string("Cost")
        case .duration:
            Localization.string("Duration")
        }
    }

    private func valueTitle(
        _ value: Double
    ) -> String {
        switch metric {
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

    private var gridWidth: CGFloat {
        cellSize * CGFloat(ActivityHeatmapLayout.hours.count)
            + cellSpacing * CGFloat(ActivityHeatmapLayout.hours.count - 1)
    }
}
