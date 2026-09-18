import SwiftUI

#if canImport(TokPeekKit)
    import TokPeekKit
#endif

struct RefreshButton: View {
    let isRefreshing: Bool
    var isVisible = true
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var title: String {
        Localization.string(isRefreshing ? "Refreshing usage" : "Refresh usage")
    }

    var body: some View {
        Button(action: action) {
            Group {
                if isRefreshing && isVisible && !reduceMotion {
                    RotatingRefreshSymbol()
                } else {
                    Image(systemName: isRefreshing ? "hourglass" : "arrow.clockwise")
                }
            }
            .frame(width: 20, height: 20)
            .foregroundStyle(Color.primary)
        }
        .buttonStyle(.borderless)
        .disabled(isRefreshing)
        .help(title)
        .accessibilityLabel(title)
        .keyboardShortcut("r", modifiers: .command)
    }
}

private struct RotatingRefreshSymbol: View {
    @State private var isRotating = false

    var body: some View {
        Image(systemName: "arrow.clockwise")
            .rotationEffect(.degrees(isRotating ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                    isRotating = true
                }
            }
    }
}
