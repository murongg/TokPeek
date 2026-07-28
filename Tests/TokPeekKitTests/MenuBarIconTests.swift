import AppKit
import Testing

#if SWIFT_PACKAGE
    @testable import TokPeekKit
#endif

@Test("The menu bar icon uses an available monochrome system symbol")
func menuBarIconUsesSystemSymbol() throws {
    #expect(MenuBarIcon.systemName == "chart.bar")
    #expect(MenuBarIcon.usesBrandMarkInSummary)
    #expect(MenuBarIcon.usesBrandMarkInIconOnly)

    let image = try #require(
        NSImage(
            systemSymbolName: MenuBarIcon.systemName,
            accessibilityDescription: "TokPeek"
        )
    )

    #expect(image.isTemplate)
}

@Test("App icon artwork fills the canvas without losing rounded corners")
func appIconArtworkFillsCanvas() throws {
    let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let iconURL = repositoryRoot
        .appendingPathComponent("Resources/Assets.xcassets")
        .appendingPathComponent("AppIcon.appiconset")
        .appendingPathComponent("icon_512x512@2x.png")
    let iconData = try Data(contentsOf: iconURL)
    let bitmap = try #require(NSBitmapImageRep(data: iconData))

    var minimumX = bitmap.pixelsWide
    var maximumX = -1
    for y in 0..<bitmap.pixelsHigh {
        for x in 0..<bitmap.pixelsWide
        where bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0 > 0.01 {
            minimumX = min(minimumX, x)
            maximumX = max(maximumX, x)
        }
    }

    let artworkWidth = maximumX - minimumX + 1
    let coverage = Double(artworkWidth) / Double(bitmap.pixelsWide)

    #expect(coverage >= 0.98)
    #expect(bitmap.colorAt(x: 0, y: 0)?.alphaComponent ?? 1 < 0.01)
    #expect(
        bitmap.colorAt(
            x: bitmap.pixelsWide / 2,
            y: bitmap.pixelsHigh / 2
        )?.alphaComponent ?? 0 > 0.99
    )
}
