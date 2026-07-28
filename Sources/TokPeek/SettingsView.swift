import SwiftUI

#if canImport(TokPeekKit)
    import TokPeekKit
#endif

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var launchAtLogin: LaunchAtLoginController

    var body: some View {
        TabView {
            general
                .tabItem {
                    Label("General", systemImage: "gearshape")
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
        .frame(width: 520, height: 360)
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

            if let url = URL(string: "https://github.com/junhoyeo/tokscale") {
                Link("View Tokscale on GitHub", destination: url)
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
}
