import AppKit
import SwiftUI

#if canImport(TokPeekKit)
    import TokPeekKit
#endif

struct DashboardView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var settings: SettingsStore
    @ObservedObject var updates: UpdateCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openSettings) private var openSettings
    @State private var selectedClientID: String?
    @State private var selectedModelID: String?

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    filterBar

                    usageContent
                        .animation(
                            reduceMotion
                                ? nil
                                : .easeOut(duration: 0.18),
                            value: showsLoadingPlaceholder
                        )

                    if let errorMessage = store.errorMessage {
                        ErrorBanner(message: errorMessage)
                    }
                }
                .padding(16)
            }
            .scrollIndicators(.never)

            Divider()
            footer
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .frame(width: 480, height: 560)
        .background(.regularMaterial)
        .tint(.primary)
        .task(id: refreshTaskID) {
            await refreshLoop()
        }
        .onChange(of: availableModelIDs) {
            guard
                let selectedModelID,
                !availableModelIDs.contains(selectedModelID)
            else {
                return
            }
            self.selectedModelID = nil
        }
        .onChange(of: availableClientIDs) {
            guard
                let selectedClientID,
                !availableClientIDs.contains(selectedClientID)
            else {
                return
            }
            self.selectedClientID = nil
        }
    }

    @ViewBuilder
    private var usageContent: some View {
        if showsLoadingPlaceholder {
            LoadingView()
                .transition(.opacity)
        } else if let report = store.report {
            let filteredReport = filteredReport(report)
            let comparison = store.comparisonReport.map {
                filteredReport.compared(
                    to: self.filteredReport($0)
                )
            }
            VStack(alignment: .leading, spacing: 16) {
                reportContent(
                    filteredReport,
                    comparison: comparison
                )
            }
            .transition(.opacity)
        } else {
            EmptyUsageView(refresh: refresh)
                .transition(.opacity)
        }
    }

    private var showsLoadingPlaceholder: Bool {
        store.isLoading
            && (store.report == nil || store.isLoadingNewRequest)
    }

    private var header: some View {
        HStack(spacing: 10) {
            AppMark(size: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text("TokPeek")
                    .font(.headline)
                Label("Local usage", systemImage: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
            }

            Spacer()

            Button {
                refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.borderless)
            .help("Refresh usage")
            .disabled(store.isLoading)
            .accessibilityLabel(
                Localization.string(
                    store.isLoading
                        ? "Refreshing usage"
                        : "Refresh usage"
                )
            )
            .keyboardShortcut("r", modifiers: .command)
        }
    }

    private var filterBar: some View {
        UsageFilterBar(
            settings: settings,
            clients: availableClients,
            models: availableModels,
            selectedClientID: $selectedClientID,
            selectedModelID: $selectedModelID,
            isEnabled: store.report != nil
        )
    }

    private var availableModels: [String] {
        Array(
            Set(
                store.modelCatalog
                    + (store.report?.modelFilterOptions ?? [])
            )
        ).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    private var availableModelIDs: [String] {
        availableModels
    }

    private var availableClients: [String] {
        store.report?.summary.clients.sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        } ?? []
    }

    private var availableClientIDs: [String] {
        availableClients
    }

    private var selectedClient: String? {
        guard
            let selectedClientID,
            availableClients.contains(selectedClientID)
        else {
            return nil
        }
        return selectedClientID
    }

    private var selectedModel: String? {
        guard
            let selectedModelID,
            availableModels.contains(selectedModelID)
        else {
            return nil
        }
        return selectedModelID
    }

    private func filteredReport(
        _ report: UsageReport
    ) -> UsageReport {
        var filteredReport = report
        if let selectedClient {
            filteredReport = filteredReport.filtered(
                client: selectedClient
            )
        }
        if let selectedModel {
            filteredReport = filteredReport.filtered(
                modelId: selectedModel
            )
        }
        return filteredReport
    }

    @ViewBuilder
    private func reportContent(
        _ report: UsageReport,
        comparison: UsageComparison?
    ) -> some View {
        UsageOverview(
            report: report,
            comparison: comparison
        )
        if let budgetSnapshot {
            BudgetOverview(snapshot: budgetSnapshot)
        }
        UsageChart(
            report: report,
            period: settings.usagePeriod
        )
        ClientBreakdown(summaries: report.clientSummaries)
        ModelRanking(summaries: report.modelSummaries)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                presentSettings()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .buttonStyle(.borderless)

            Spacer()

            if let report = store.report {
                Text(
                    Localization.format(
                        "%lld ms",
                        [Int64(report.meta.processingTimeMs)]
                    )
                )
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
                .accessibilityLabel(
                    Localization.format(
                        "Report generated in %lld milliseconds",
                        [Int64(report.meta.processingTimeMs)]
                    )
                )
            }

            Menu {
                Button {
                    updates.checkForUpdates()
                } label: {
                    Label(
                        "Check for Updates…",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                }
                .disabled(!updates.canCheckForUpdates)

                Divider()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .frame(width: 20, height: 20)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .help("More actions")
            .accessibilityLabel("More actions")
        }
        .font(.caption)
    }

    private func presentSettings() {
        SettingsPresenter(
            activateApplication: {
                NSApplication.shared.activate(
                    ignoringOtherApps: true
                )
            },
            openSettings: {
                openSettings()
            }
        )
        .present()
    }

    private var refreshTaskID: String {
        let values = settings.values
        let request = values.usageRequest()
        let budgetRequest = values.budget.analyticsRequest(
            useEnvironmentRoots: values.useEnvironmentRoots
        )
        let components: [String] = [
            settings.usagePeriod.rawValue,
            String(settings.refreshFrequency.rawValue),
            String(settings.useEnvironmentRoots),
            String(settings.isBudgetEnabled),
            settings.budgetPeriod.rawValue,
            settings.budgetMetric.rawValue,
            String(settings.budgetLimit),
            String(settings.budgetNotificationsEnabled),
            request.since ?? "",
            request.until ?? "",
            request.startTimeMs.map(String.init) ?? "",
            request.endTimeMs.map(String.init) ?? "",
            budgetRequest?.since ?? "",
            budgetRequest?.until ?? "",
        ]
        return components.joined(separator: "|")
    }

    private func refresh() {
        Task {
            await loadUsage()
            await store.refreshModelCatalogIfNeeded(
                maxAge: 0
            )
        }
    }

    private func loadUsage() async {
        configureRequests()
        await store.refresh()
        await store.refreshComparisonIfNeeded()
        await store.refreshBudgetIfNeeded(maxAge: 0)
    }

    private func refreshLoop() async {
        configureRequests()
        await store.refreshIfNeeded(
            maxAge: settings.refreshFrequency.seconds
        )
        await store.refreshComparisonIfNeeded()
        await store.refreshBudgetIfNeeded(
            maxAge: settings.refreshFrequency.seconds
        )
        await store.refreshModelCatalogIfNeeded(
            maxAge: 300
        )

        guard let seconds = settings.refreshFrequency.seconds else {
            return
        }

        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(seconds))
            } catch {
                return
            }
            await loadUsage()
            await store.refreshModelCatalogIfNeeded(
                maxAge: 300
            )
        }
    }

    private func configureRequests(
        now: Date = Date()
    ) {
        let values = settings.values
        let request = values.usageRequest(now: now)
        store.request = request
        store.comparisonRequest = request.previousPeriod()
        store.budgetRequest = values.budget.analyticsRequest(
            now: now,
            useEnvironmentRoots: values.useEnvironmentRoots
        )
    }

    private var budgetSnapshot: UsageBudgetSnapshot? {
        guard let report = store.budgetReport else {
            return nil
        }
        return settings.budget.snapshot(report: report)
    }
}

private struct UsageFilterBar: View {
    @ObservedObject var settings: SettingsStore
    let clients: [String]
    let models: [String]
    @Binding var selectedClientID: String?
    @Binding var selectedModelID: String?
    let isEnabled: Bool

    @State private var showsCustomRange = false

    var body: some View {
        HStack(
            spacing: CGFloat(
                DashboardLayoutMetrics.filterSpacing
            )
        ) {
            Picker(
                "Usage period",
                selection: $settings.usagePeriod
            ) {
                ForEach(UsagePeriod.presetCases) { period in
                    Text(period.shortTitle)
                        .tag(period)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(
                width: CGFloat(
                    DashboardLayoutMetrics.periodPickerWidth
                )
            )
            .padding(
                .horizontal,
                CGFloat(
                    DashboardLayoutMetrics
                        .segmentedControlHorizontalAllowance
                )
            )
            .accessibilityLabel("Usage period")

            Button {
                showsCustomRange = true
            } label: {
                Image(systemName: "calendar")
                    .frame(
                        width: CGFloat(
                            DashboardLayoutMetrics.calendarButtonWidth
                        ),
                        height: 24
                    )
                    .background(
                        settings.usagePeriod == .custom
                            ? Color.primary.opacity(0.14)
                            : TokPeekTheme.surface,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
            }
            .buttonStyle(.borderless)
            .help(customRangeTitle)
            .accessibilityLabel("Custom range")
            .accessibilityValue(customRangeTitle)
            .popover(
                isPresented: $showsCustomRange,
                arrowEdge: .top
            ) {
                CustomRangePicker(
                    range: settings.customDateRange
                ) { range in
                    settings.customDateRange = range
                    settings.usagePeriod = .custom
                    showsCustomRange = false
                }
            }

            UsageFiltersMenu(
                clients: clients,
                models: models,
                selectedClientID: $selectedClientID,
                selectedModelID: $selectedModelID,
                clientDisplayName: clientDisplayName,
                modelDisplayName: modelDisplayName
            )
            .frame(
                width: CGFloat(
                    DashboardLayoutMetrics.filtersMenuWidth
                ),
                height: CGFloat(
                    DashboardLayoutMetrics.filtersMenuHitTargetHeight
                )
            )
            // A borderless native Menu reserves trailing indicator space even
            // when the indicator is hidden. Move the complete control so its
            // visible label aligns right without separating it from its hit area.
            .offset(
                x: CGFloat(
                    DashboardLayoutMetrics
                        .filtersMenuNativeTrailingAllowance
                )
            )
            .disabled(!isEnabled)
        }
    }

    private var customRangeTitle: String {
        let start = settings.customDateRange.start.formatted(
            date: .abbreviated,
            time: .omitted
        )
        let end = settings.customDateRange.end.formatted(
            date: .abbreviated,
            time: .omitted
        )
        return "\(start) – \(end)"
    }

    private func clientDisplayName(
        _ client: String
    ) -> String {
        client
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private func modelDisplayName(
        _ model: String
    ) -> String {
        model.isEmpty
            ? Localization.string("Unknown model")
            : model
    }
}

private struct UsageFiltersMenu: View {
    let clients: [String]
    let models: [String]
    @Binding var selectedClientID: String?
    @Binding var selectedModelID: String?
    let clientDisplayName: (String) -> String
    let modelDisplayName: (String) -> String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Menu {
            Menu {
                filterOption(
                    title: Localization.string("All clients"),
                    id: nil,
                    selection: $selectedClientID
                )

                if !clients.isEmpty {
                    Divider()
                }

                ForEach(clients, id: \.self) { client in
                    filterOption(
                        title: clientDisplayName(client),
                        id: client,
                        selection: $selectedClientID
                    )
                }
            } label: {
                Label(
                    selectedClientTitle,
                    systemImage: "desktopcomputer"
                )
            }

            Menu {
                filterOption(
                    title: Localization.string("All models"),
                    id: nil,
                    selection: $selectedModelID
                )

                if !models.isEmpty {
                    Divider()
                }

                ForEach(models, id: \.self) { model in
                    filterOption(
                        title: modelDisplayName(model),
                        id: model,
                        selection: $selectedModelID
                    )
                }
            } label: {
                Label(selectedModelTitle, systemImage: "cpu")
            }

            if activeFilterCount > 0 {
                Divider()

                Button {
                    withFilterAnimation {
                        selectedClientID = nil
                        selectedModelID = nil
                    }
                } label: {
                    Label(
                        "Clear filters",
                        systemImage: "xmark.circle"
                    )
                }
            }
        } label: {
            filtersMenuLabel
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(
            width: CGFloat(
                DashboardLayoutMetrics.filtersMenuHitTargetWidth
            ),
            height: CGFloat(
                DashboardLayoutMetrics.filtersMenuHitTargetHeight
            )
        )
        .help(filterHelp)
        .accessibilityLabel("Filters")
        .accessibilityValue(filterHelp)
    }

    private var filtersMenuLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 10, weight: .semibold))

            if activeFilterCount == 0 {
                Text("Filters")
            } else {
                Text("\(activeFilterCount)")
                    .font(.caption2.monospacedDigit().weight(.semibold))
            }
        }
        .font(.caption.weight(.medium))
        .padding(
            EdgeInsets(
                top: 0,
                leading: CGFloat(
                    DashboardLayoutMetrics
                        .filtersMenuContentLeadingPadding
                ),
                bottom: 0,
                trailing: CGFloat(
                    DashboardLayoutMetrics
                        .filtersMenuContentTrailingPadding
                )
            )
        )
        .frame(
            width: CGFloat(
                DashboardLayoutMetrics.filtersMenuHitTargetWidth
            ),
            height: CGFloat(
                DashboardLayoutMetrics.filtersMenuHitTargetHeight
            ),
            alignment: .trailing
        )
        .background(
            TokPeekTheme.surface,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .contentShape(Rectangle())
    }

    private var activeFilterCount: Int {
        UsageFormatting.activeFilterCount(
            client: selectedClientID,
            model: selectedModelID
        )
    }

    private var selectedClientTitle: String {
        selectedClientID.map(clientDisplayName)
            ?? Localization.string("All clients")
    }

    private var selectedModelTitle: String {
        selectedModelID.map(modelDisplayName)
            ?? Localization.string("All models")
    }

    private var filterHelp: String {
        guard activeFilterCount > 0 else {
            return Localization.string("Filters")
        }
        return [selectedClientID.map(clientDisplayName),
                selectedModelID.map(modelDisplayName)]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    private func filterOption(
        title: String,
        id: String?,
        selection: Binding<String?>
    ) -> some View {
        Button {
            withFilterAnimation {
                selection.wrappedValue = id
            }
        } label: {
            HStack {
                Text(title)

                if selection.wrappedValue == id {
                    Image(systemName: "checkmark")
                }
            }
        }
    }

    private func withFilterAnimation(
        _ update: () -> Void
    ) {
        withAnimation(
            reduceMotion ? nil : .easeOut(duration: 0.18),
            update
        )
    }
}

private struct CustomRangePicker: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var draft: UsageDateRangeDraft
    @State private var pickerState = UsageDatePickerState()
    let apply: (UsageDateRange) -> Void

    init(
        range: UsageDateRange,
        apply: @escaping (UsageDateRange) -> Void
    ) {
        _draft = State(
            initialValue: UsageDateRangeDraft(range: range)
        )
        self.apply = apply
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Custom range")
                .font(.headline)

            HStack(spacing: 8) {
                boundaryButton(
                    title: "From",
                    boundary: .start
                )
                boundaryButton(
                    title: "To",
                    boundary: .end
                )
            }

            if let boundary = pickerState.expandedBoundary {
                // A second NSPopover steals focus from MenuBarExtra and closes
                // the whole menu, so reveal the calendar inside this popover.
                DatePicker(
                    "Date",
                    selection: selectedDate(for: boundary),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .tint(TokPeekTheme.calendarSelectionTint)
                .focusEffectDisabled(
                    DashboardLayoutMetrics
                        .calendarFocusEffectDisabled
                )
                .id(boundary)
            }

            HStack {
                Spacer()

                Button {
                    apply(draft.normalizedRange)
                } label: {
                    Text("Apply")
                        .foregroundStyle(
                            TokPeekTheme.prominentForeground(
                                for: colorScheme
                            )
                        )
                }
                .buttonStyle(.borderedProminent)
                .tint(.primary)
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    private func selectedDate(
        for boundary: UsageDateBoundary
    ) -> Binding<Date> {
        Binding(
            get: {
                draft[boundary]
            },
            set: {
                draft[boundary] = $0
            }
        )
    }

    private func boundaryButton(
        title: LocalizedStringKey,
        boundary: UsageDateBoundary
    ) -> some View {
        Button {
            pickerState.toggle(boundary)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(
                    draft[boundary].formatted(
                        date: .abbreviated,
                        time: .omitted
                    )
                )
                .font(.callout.weight(.medium))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                pickerState.expandedBoundary == boundary
                    ? Color.primary.opacity(0.14)
                    : TokPeekTheme.surface,
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct LoadingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            RoundedRectangle(cornerRadius: 8)
                .fill(TokPeekTheme.surface)
                .frame(height: 58)

            RoundedRectangle(cornerRadius: 12)
                .fill(TokPeekTheme.surface)
                .frame(height: 170)

            VStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 5)
                        .fill(TokPeekTheme.surface)
                        .frame(height: 28)
                }
            }
        }
        .opacity(
            reduceMotion
                ? 1
                : (isPulsing ? 0.46 : 0.82)
        )
        .redacted(reason: .placeholder)
        .onAppear {
            guard !reduceMotion else {
                return
            }
            withAnimation(
                .easeInOut(duration: 0.75)
                    .repeatForever(autoreverses: true)
            ) {
                isPulsing = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading local usage")
    }
}

private struct EmptyUsageView: View {
    @Environment(\.colorScheme) private var colorScheme
    let refresh: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            PeekGlyph(
                panelColor: .primary,
                tokenColor: .secondary
            )
            .frame(width: 30, height: 30)

            Text("No local sessions yet")
                .font(.headline)

            Text(
                "TokPeek reads supported AI coding sessions on this Mac. Nothing is uploaded."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 280)

            Button(action: refresh) {
                Text("Scan again")
                    .foregroundStyle(
                        TokPeekTheme.prominentForeground(
                            for: colorScheme
                        )
                    )
            }
            .buttonStyle(.borderedProminent)
            .tint(.primary)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }
}

private struct ErrorBanner: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }
}
