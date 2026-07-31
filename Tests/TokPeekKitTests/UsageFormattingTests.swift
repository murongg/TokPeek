import Testing

#if SWIFT_PACKAGE
    @testable import TokPeekKit
#endif

@Test(
    "Token totals use compact menu-bar-friendly formatting",
    arguments: [
        (950 as Int64, "950"),
        (1_500 as Int64, "1.5K"),
        (1_250_000 as Int64, "1.3M"),
    ]
)
func formatsCompactTokenTotals(value: Int64, expected: String) {
    #expect(UsageFormatting.compactTokens(value) == expected)
}

@Test("Chart tooltip metrics use consistent compact formatting")
func formatsChartTooltipMetrics() {
    let metrics = UsageFormatting.tooltipMetrics(
        tokens: 1_250_000,
        cost: 3.5,
        messages: 42,
        fraction: 0.125
    )

    #expect(metrics.tokens == "1.3M")
    #expect(metrics.cost == UsageFormatting.cost(3.5))
    #expect(metrics.messages == "42")
    #expect(metrics.percentage == "12%")
}

@Test("Budget values follow the selected cost or token metric")
func formatsBudgetValues() {
    #expect(
        UsageFormatting.budgetValue(
            12.5,
            metric: .cost
        ) == UsageFormatting.cost(12.5)
    )
    #expect(
        UsageFormatting.budgetValue(
            1_250_000,
            metric: .tokens
        ) == "1.3M"
    )
}

@Test("Chart tooltip surface is fully opaque in every appearance")
func chartTooltipSurfaceIsOpaque() {
    #expect(UsageTooltipAppearance.backgroundOpacity == 1)
    #expect((0...1).contains(UsageTooltipAppearance.lightBackgroundWhite))
    #expect((0...1).contains(UsageTooltipAppearance.darkBackgroundWhite))
}
