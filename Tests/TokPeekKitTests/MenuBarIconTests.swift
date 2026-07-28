import AppKit
import Testing

#if SWIFT_PACKAGE
    @testable import TokPeekKit
#endif

@Test("The menu bar icon uses an available monochrome system symbol")
func menuBarIconUsesSystemSymbol() throws {
    #expect(MenuBarIcon.systemName == "chart.bar")
    #expect(MenuBarIcon.usesBrandMarkInSummary)

    let image = try #require(
        NSImage(
            systemSymbolName: MenuBarIcon.systemName,
            accessibilityDescription: "TokPeek"
        )
    )

    #expect(image.isTemplate)
}
