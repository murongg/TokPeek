import AppKit
import SwiftUI

#if canImport(TokPeekKit)
    import TokPeekKit
#endif

enum TokPeekTheme {
    static let graphite = Color.black
    static let iconPaper = Color.white
    static let iconToken = Color.white.opacity(0.54)
    static let compositionInput = Color.primary
    static let compositionOutput = Color.primary.opacity(0.74)
    static let compositionCache = Color.primary.opacity(0.48)
    static let compositionReasoning = Color.primary.opacity(0.26)
    static let surface = Color.primary.opacity(0.055)
    static let divider = Color(nsColor: .separatorColor)
}

struct AppMark: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.25)
                .fill(TokPeekTheme.graphite)

            PeekGlyph(
                panelColor: TokPeekTheme.iconPaper,
                tokenColor: TokPeekTheme.iconToken
            )
            .frame(width: size * 0.68, height: size * 0.68)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct PeekGlyph: View {
    let panelColor: Color
    let tokenColor: Color

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)

            ZStack {
                Circle()
                    .fill(tokenColor)
                    .frame(width: side * 0.44, height: side * 0.44)
                    .offset(x: side * 0.10)

                RoundedRectangle(cornerRadius: side * 0.09)
                    .fill(panelColor)
                    .frame(width: side * 0.18, height: side * 0.58)
                    .offset(x: -side * 0.13)
            }
            .frame(
                width: proxy.size.width,
                height: proxy.size.height
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct UsageTooltipRow: Identifiable {
    let label: String
    let value: String

    var id: String { label }
}

struct UsageTooltip: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let rows: [UsageTooltipRow]

    private var surfaceColor: Color {
        // A semantic NSColor becomes translucent inside the menu-bar vibrancy
        // hierarchy, so keep this surface explicitly opaque to mask chart text.
        let white =
            colorScheme == .dark
            ? UsageTooltipAppearance.darkBackgroundWhite
            : UsageTooltipAppearance.lightBackgroundWhite

        return Color(
            .sRGB,
            white: white,
            opacity: UsageTooltipAppearance.backgroundOpacity
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.middle)

            ForEach(rows) { row in
                HStack(spacing: 8) {
                    Text(row.label)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 8)

                    Text(row.value)
                        .monospacedDigit()
                }
                .font(.caption2)
            }
        }
        .padding(8)
        .frame(width: 148, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(surfaceColor)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    TokPeekTheme.divider.opacity(0.8),
                    lineWidth: 1
                )
        }
        .allowsHitTesting(false)
    }
}
