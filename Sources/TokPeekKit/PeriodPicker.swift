import AppKit
import SwiftUI

public struct PeriodPicker: NSViewRepresentable {
    @Binding var selection: UsagePeriod

    public init(selection: Binding<UsagePeriod>) {
        _selection = selection
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    public func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl(
            labels: UsagePeriod.presetCases.map(\.shortTitle),
            trackingMode: .selectOne,
            target: context.coordinator,
            action: #selector(Coordinator.selectPeriod(_:))
        )
        control.segmentStyle = .rounded
        control.selectedSegmentBezelColor = .labelColor
        // SwiftUI's segmented Picker can retain an intrinsic width larger
        // than its frame. AppKit's fill distribution fits the actual bounds
        // without relying on OS-dependent alignment-inset compensation.
        control.segmentDistribution = .fill
        control.setAccessibilityLabel(Localization.string("Usage period"))
        return control
    }

    public func updateNSView(_ control: NSSegmentedControl, context: Context) {
        context.coordinator.selection = $selection
        for (index, period) in UsagePeriod.presetCases.enumerated() {
            control.setLabel(period.shortTitle, forSegment: index)
        }
        control.selectedSegment = UsagePeriod.presetCases.firstIndex(of: selection) ?? -1
    }

    public func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: NSSegmentedControl,
        context: Context
    ) -> CGSize? {
        CGSize(
            width: DashboardLayoutMetrics.periodPickerWidth,
            height: nsView.intrinsicContentSize.height
        )
    }

    @MainActor
    public final class Coordinator: NSObject {
        var selection: Binding<UsagePeriod>

        init(selection: Binding<UsagePeriod>) {
            self.selection = selection
        }

        @objc func selectPeriod(_ sender: NSSegmentedControl) {
            let periods = UsagePeriod.presetCases
            guard periods.indices.contains(sender.selectedSegment) else { return }
            selection.wrappedValue = periods[sender.selectedSegment]
        }
    }
}
