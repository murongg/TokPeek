import AppKit
import Testing

#if SWIFT_PACKAGE
    @testable import TokPeekKit
#endif

@MainActor
@Test("Visibility follows a retained window when it is shown and hidden")
func retainedWindowVisibility() async throws {
    _ = NSApplication.shared
    let window = NSWindow(
        contentRect: NSRect(x: 100, y: 100, width: 20, height: 20),
        styleMask: [.borderless], backing: .buffered, defer: false
    )
    window.isReleasedWhenClosed = false
    defer { window.close() }
    let view = WindowVisibilityView()
    var visibility: Bool?
    view.onChange = { visibility = $0 }
    window.contentView = view
    try await Task.sleep(for: .milliseconds(20))
    #expect(visibility == false)

    window.orderFront(nil)
    try await Task.sleep(for: .milliseconds(100))
    #expect(visibility == true)

    window.orderOut(nil)
    try await Task.sleep(for: .milliseconds(100))
    #expect(visibility == false)
    #expect(window.contentView === view)

    window.orderFront(nil)
    try await Task.sleep(for: .milliseconds(100))
    #expect(visibility == true)

    window.contentView = nil
    try await Task.sleep(for: .milliseconds(20))
    #expect(visibility == false)
}
