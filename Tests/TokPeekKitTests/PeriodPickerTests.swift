import AppKit
import SwiftUI
import Testing

#if SWIFT_PACKAGE
    @testable import TokPeekKit
#endif

@MainActor
@Test(
    "Period control fits its allocated space after selection and reopening",
    arguments: [
        ["Today", "24H", "7D", "30D", "90D", "All"],
        ["今天", "24小时", "7天", "30天", "90天", "全部"],
    ], [NSAppearance.Name.aqua, .darkAqua]
)
func periodPickerFits(labels: [String], appearance: NSAppearance.Name) async throws {
    _ = NSApplication.shared
    let host = NSHostingView(rootView: PeriodPicker(selection: .constant(.today)))
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 328, height: 40),
        styleMask: [.borderless], backing: .buffered, defer: false
    )
    window.appearance = NSAppearance(named: appearance)
    window.isReleasedWhenClosed = false
    defer { window.close() }
    window.contentView = host

    for period in [UsagePeriod.today, .all, .custom, .week] {
        host.rootView = PeriodPicker(selection: .constant(period))
        window.orderFront(nil)
        try await Task.sleep(for: .milliseconds(30))
        host.layoutSubtreeIfNeeded()
        let control = try #require(segmentedControl(in: host))
        for (index, label) in labels.enumerated() {
            control.setLabel(label, forSegment: index)
        }
        #expect(control.selectedSegment == (UsagePeriod.presetCases.firstIndex(of: period) ?? -1))
        // Intrinsic overflow can draw across the neighboring calendar even
        // when SwiftUI reports a correctly sized outer frame.
        #expect(control.intrinsicContentSize.width <= control.bounds.width + 1)
        let rect = control.convert(control.bounds, to: host)
        #expect(rect.minX >= 0)
        #expect(rect.maxX <= host.bounds.width + 1)
        window.orderOut(nil)
    }
}

@MainActor
private func segmentedControl(in view: NSView) -> NSSegmentedControl? {
    if let control = view as? NSSegmentedControl { return control }
    return view.subviews.lazy.compactMap { segmentedControl(in: $0) }.first
}

@MainActor
@Test("Period control sends native selections back to the binding")
func periodPickerSelection() throws {
    var selected = UsagePeriod.custom
    let binding = Binding(get: { selected }, set: { selected = $0 })
    let coordinator = PeriodPicker(selection: binding).makeCoordinator()
    let control = NSSegmentedControl(
        labels: UsagePeriod.presetCases.map(\.shortTitle),
        trackingMode: .selectOne,
        target: coordinator,
        action: #selector(PeriodPicker.Coordinator.selectPeriod(_:))
    )
    for (index, period) in UsagePeriod.presetCases.enumerated() {
        control.selectedSegment = index
        #expect(control.sendAction(control.action, to: control.target))
        #expect(selected == period)
    }
    control.selectedSegment = -1
    control.sendAction(control.action, to: control.target)
    #expect(selected == .all)
}
