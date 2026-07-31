import SwiftUI

#if canImport(TokPeekKit)
    import TokPeekKit
#endif

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var launchAtLogin: LaunchAtLoginController
    @ObservedObject var updates: UpdateCoordinator

    var body: some View {
        TabView {
            general
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            budget
                .tabItem {
                    Label(
                        "Budget",
                        systemImage: "gauge.with.dots.needle.67percent"
                    )
                }

            data
                .tabItem {
                    Label("Data", systemImage: "externaldrive")
                }

            about
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 520, height: 390)
        .tint(.primary)
        .onAppear {
            launchAtLogin.refresh()
        }
    }

    private var general: some View {
        Form {
            Section("Menu Bar") {
                Picker("Display", selection: $settings.menuBarMetric) {
                    ForEach(MenuBarMetric.allCases) { metric in
                        Text(metric.title)
                            .tag(metric)
                    }
                }

                Picker("Refresh", selection: $settings.refreshFrequency) {
                    ForEach(RefreshFrequency.allCases) { frequency in
                        Text(frequency.title)
                            .tag(frequency)
                    }
                }
            }

            Section("System") {
                Toggle(
                    "Launch TokPeek at login",
                    isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: { enabled in
                            launchAtLogin.setEnabled(enabled)
                        }
                    )
                )

                if let errorMessage = launchAtLogin.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
            }

            Section("Updates") {
                Toggle(
                    "Automatically check for updates",
                    isOn: Binding(
                        get: {
                            updates.automaticallyChecksForUpdates
                        },
                        set: {
                            updates.setAutomaticallyChecksForUpdates($0)
                        }
                    )
                )

                Button("Check for Updates…") {
                    updates.checkForUpdates()
                }
                .disabled(!updates.canCheckForUpdates)

                Text(
                    "TokPeek checks GitHub Releases once a day. Updates are installed only after confirmation."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var budget: some View {
        Form {
            Section("Budget") {
                Toggle(
                    "Enable budget tracking",
                    isOn: $settings.isBudgetEnabled
                )

                if settings.isBudgetEnabled {
                    Picker(
                        "Metric",
                        selection: $settings.budgetMetric
                    ) {
                        ForEach(UsageBudgetMetric.allCases) { metric in
                            Text(metric.title)
                                .tag(metric)
                        }
                    }

                    Picker(
                        "Period",
                        selection: $settings.budgetPeriod
                    ) {
                        ForEach(UsageBudgetPeriod.allCases) { period in
                            Text(period.title)
                                .tag(period)
                        }
                    }

                    LabeledContent("Limit") {
                        HStack(spacing: 6) {
                            TextField(
                                "Limit",
                                value: $settings.budgetLimit,
                                format: .number.precision(
                                    .fractionLength(0...2)
                                )
                            )
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)

                            Text(
                                settings.budgetMetric == .cost
                                    ? "USD"
                                    : Localization.string("tokens")
                            )
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if settings.isBudgetEnabled {
                Section("Alerts") {
                    Toggle(
                        "Notify at 80% and 100%",
                        isOn: $settings.budgetNotificationsEnabled
                    )

                    Text(
                        "Budget alerts are delivered by macOS and calculated entirely on this Mac."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var data: some View {
        Form {
            Section("Report") {
                Picker("Default range", selection: $settings.usagePeriod) {
                    ForEach(UsagePeriod.allCases) { period in
                        Text(period.title)
                            .tag(period)
                    }
                }

                if settings.usagePeriod == .custom {
                    Text(customRangeDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Toggle(
                    "Include paths from Tokscale environment variables",
                    isOn: $settings.useEnvironmentRoots
                )
            }

            Section("Privacy") {
                Label {
                    Text(
                        "Session parsing and aggregation happen locally through Tokscale Core. TokPeek does not upload session contents."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(.primary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var about: some View {
        VStack(spacing: 12) {
            AppMark(size: 64)

            Text("TokPeek")
                .font(.title2.weight(.semibold))

            Text(
                Localization.format(
                    "Version %@",
                    [appVersion]
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Text("A native, local-first menu bar for AI token usage.")
                .font(.body)

            Text("Powered by Tokscale Core 4.7.0 · MIT licensed")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 18) {
                if let url = URL(
                    string: "https://github.com/murongg/TokPeek"
                ) {
                    Link("View TokPeek on GitHub", destination: url)
                }

                if let url = URL(
                    string: "https://github.com/junhoyeo/tokscale"
                ) {
                    Link("View Tokscale on GitHub", destination: url)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var appVersion: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "0.1.0"
    }

    private var customRangeDescription: String {
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
}
