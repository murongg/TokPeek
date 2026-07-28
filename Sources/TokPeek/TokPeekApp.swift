import AppKit
import SwiftUI

#if canImport(TokPeekBridge)
    import TokPeekBridge
#endif
#if canImport(TokPeekKit)
    import TokPeekKit
#endif

@main
struct TokPeekApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    @StateObject private var store = UsageStore(
        loader: TokscaleClient()
    )
    @StateObject private var settings = SettingsStore()
    @StateObject private var launchAtLogin = LaunchAtLoginController()

    var body: some Scene {
        MenuBarExtra {
            DashboardView(
                store: store,
                settings: settings
            )
        } label: {
            menuBarLabel
                .task(id: menuBarRefreshTaskID) {
                    await refreshMenuBarUsage()
                }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(
                settings: settings,
                launchAtLogin: launchAtLogin
            )
        }
    }

    @ViewBuilder
    private var menuBarLabel: some View {
        if settings.menuBarMetric == .summary {
            MenuBarSummaryLabel(
                summary: store.report.map {
                    UsageFormatting.menuBarSummary(
                        for: $0
                    )
                }
            )
        } else if let report = store.report,
            let title = UsageFormatting.menuBarTitle(
                for: settings.menuBarMetric,
                report: report
            )
        {
            Label {
                Text(title)
            } icon: {
                menuBarGlyph
            }
        } else if settings.menuBarMetric == .iconOnly {
            menuBarGlyph
                .accessibilityLabel("TokPeek")
        } else {
            Label {
                Text("TokPeek")
            } icon: {
                menuBarGlyph
            }
        }
    }

    private var menuBarGlyph: some View {
        Image(systemName: MenuBarIcon.systemName)
    }

    private var menuBarRefreshTaskID: String {
        [
            settings.usagePeriod.rawValue,
            String(settings.refreshFrequency.rawValue),
            String(settings.useEnvironmentRoots),
        ].joined(separator: "|")
    }

    private func refreshMenuBarUsage() async {
        store.request = settings.values.usageRequest()
        await store.refreshIfNeeded(
            maxAge: settings.refreshFrequency.seconds
        )
    }
}

private struct MenuBarSummaryLabel: View {
    let summary: MenuBarSummary?

    var body: some View {
        Image(nsImage: artwork)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("TokPeek")
            .accessibilityValue(accessibilityValue)
    }

    private var artwork: NSImage {
        let renderer = ImageRenderer(
            content: MenuBarSummaryArtwork(summary: summary)
        )
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2

        guard let image = renderer.nsImage else {
            return NSImage()
        }

        // A single template image keeps the two lines inside one status-item
        // box and lets macOS apply its normal/selected menu bar tint.
        image.isTemplate = true
        return image
    }

    private var accessibilityValue: String {
        guard let summary else {
            return Localization.string("Refreshing usage")
        }

        return Localization.format(
            "%@ tokens, %@ estimated cost",
            [summary.tokens, summary.cost]
        )
    }
}

private struct MenuBarSummaryArtwork: View {
    let summary: MenuBarSummary?

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            if MenuBarIcon.usesBrandMarkInSummary {
                MenuBarPeekMark()
            } else {
                Image(systemName: MenuBarIcon.systemName)
                    .font(.system(size: 14, weight: .regular))
                    .frame(width: 15, height: 18)
            }

            VStack(alignment: .leading, spacing: -3.5) {
                Text(summary?.cost ?? "$—")
                Text(summary?.tokens ?? "—")
            }
            .font(
                .system(
                    size: 10.5,
                    weight: .semibold,
                    design: .monospaced
                )
            )
            .lineLimit(1)
        }
        .foregroundStyle(.black)
        .frame(width: 82, height: 22, alignment: .leading)
    }
}

private struct MenuBarPeekMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3.5)
                .stroke(.black, lineWidth: 1.25)

            PeekGlyph(
                panelColor: .black,
                tokenColor: .black.opacity(0.42)
            )
            .frame(width: 12, height: 12)
        }
        .frame(width: 17, height: 17)
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(
        _ notification: Notification
    ) {
        NSApp.setActivationPolicy(.accessory)
    }
}
