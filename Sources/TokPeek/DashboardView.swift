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
    }

    @ViewBuilder
    private var usageContent: some View {
        if showsLoadingPlaceholder {
            LoadingView()
                .transition(.opacity)
        } else if let report = store.report {
            VStack(alignment: .leading, spacing: 16) {
                reportContent(
                    filteredReport(report)
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

    private var periodPicker: some View {
        Picker("Usage period", selection: $settings.usagePeriod) {
            ForEach(UsagePeriod.allCases) { period in
                Text(period.shortTitle)
                    .tag(period)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 288)
        .padding(.leading, 16)
        .accessibilityLabel("Usage period")
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            periodPicker

            Spacer(minLength: 8)

            modelFilter
        }
    }

    private var modelFilter: some View {
        Menu {
            modelFilterButton(
                title: Localization.string("All models"),
                id: nil
            )

            if !availableModels.isEmpty {
                Divider()
            }

            ForEach(availableModels, id: \.self) { model in
                modelFilterButton(
                    title: modelDisplayName(model),
                    id: model
                )
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 10, weight: .semibold))

                Text(selectedModelTitle)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 2)

                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .frame(width: 118, height: 24, alignment: .leading)
            .background(
                TokPeekTheme.surface,
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .disabled(store.report == nil)
        .help(modelFilterHelp)
        .accessibilityLabel("Filter by model")
        .accessibilityValue(selectedModelTitle)
    }

    private func modelFilterButton(
        title: String,
        id: String?
    ) -> some View {
        Button {
            withAnimation(
                reduceMotion ? nil : .easeOut(duration: 0.18)
            ) {
                selectedModelID = id
            }
        } label: {
            HStack {
                Text(title)

                if selectedModelID == id {
                    Image(systemName: "checkmark")
                }
            }
        }
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

    private var selectedModel: String? {
        guard
            let selectedModelID,
            availableModels.contains(selectedModelID)
        else {
            return nil
        }
        return selectedModelID
    }

    private var selectedModelTitle: String {
        selectedModel.map(modelDisplayName)
            ?? Localization.string("All models")
    }

    private var modelFilterHelp: String {
        let filterLabel = Localization.string("Filter by model")
        guard let selectedModel else {
            return filterLabel
        }
        return "\(filterLabel): \(modelDisplayName(selectedModel))"
    }

    private func modelDisplayName(
        _ model: String
    ) -> String {
        model.isEmpty
            ? Localization.string("Unknown model")
            : model
    }

    private func filteredReport(
        _ report: UsageReport
    ) -> UsageReport {
        guard let selectedModel else {
            return report
        }
        return report.filtered(
            modelId: selectedModel
        )
    }

    @ViewBuilder
    private func reportContent(_ report: UsageReport) -> some View {
        UsageOverview(report: report)
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

            Button {
                updates.checkForUpdates()
            } label: {
                Label(
                    "Check for Updates…",
                    systemImage: "arrow.triangle.2.circlepath"
                )
            }
            .buttonStyle(.borderless)
            .disabled(!updates.canCheckForUpdates)

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

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
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
        [
            settings.usagePeriod.rawValue,
            String(settings.refreshFrequency.rawValue),
            String(settings.useEnvironmentRoots),
        ].joined(separator: "|")
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
        store.request = settings.values.usageRequest()
        await store.refresh()
    }

    private func refreshLoop() async {
        store.request = settings.values.usageRequest()
        await store.refreshIfNeeded(
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

            Button("Scan again", action: refresh)
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
