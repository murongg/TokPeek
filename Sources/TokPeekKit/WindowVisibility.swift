import AppKit
import SwiftUI

public struct WindowVisibility: NSViewRepresentable {
    private let onChange: @MainActor (Bool) -> Void

    public init(_ onChange: @escaping @MainActor (Bool) -> Void) {
        self.onChange = onChange
    }

    public func makeNSView(context: Context) -> NSView {
        let view = WindowVisibilityView()
        view.onChange = onChange
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? WindowVisibilityView)?.onChange = onChange
    }
}

final class WindowVisibilityView: NSView {
    var onChange: (@MainActor (Bool) -> Void)?
    private var lastVisibility: Bool?
    private var observation: NSKeyValueObservation?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        observation = window?.observe(\.isVisible, options: [.initial, .new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.updateVisibility()
            }
        }
        updateVisibility()
    }

    private func updateVisibility() {
        // MenuBarExtra can keep its view tree alive after ordering the window
        // out. SwiftUI appearance callbacks alone cannot stop its scan loop.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let visible = window?.isVisible ?? false
            guard visible != lastVisibility else { return }
            lastVisibility = visible
            onChange?(visible)
        }
    }
}
