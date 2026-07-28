import Testing

#if SWIFT_PACKAGE
    @testable import TokPeekKit
#endif

@Test("Client breakdown keeps major clients and groups the long tail")
func clientBreakdownGroupsLongTail() throws {
    let summaries = [
        clientSummary("mock-alpha", tokens: 600, cost: 6, messages: 60),
        clientSummary("mock-beta", tokens: 200, cost: 2, messages: 20),
        clientSummary("mock-gamma", tokens: 100, cost: 1, messages: 10),
        clientSummary("mock-delta", tokens: 50, cost: 0.5, messages: 5),
        clientSummary("mock-epsilon", tokens: 30, cost: 0.3, messages: 3),
        clientSummary("mock-zeta", tokens: 20, cost: 0.2, messages: 2),
    ]

    let layout = ClientBreakdownLayout(summaries: summaries)

    #expect(layout.totalTokens == 1_000)
    #expect(
        layout.slices.map(\.client)
            == [
                "mock-alpha",
                "mock-beta",
                "mock-gamma",
                "mock-delta",
                "other",
            ]
    )
    #expect(layout.slices.first?.fraction == 0.6)
    #expect(layout.slices.last?.tokens == 50)
    #expect(layout.slices.last?.cost == 0.5)
    #expect(layout.slices.last?.messages == 5)
    #expect(layout.slices.last?.isOther == true)
    #expect(
        abs(layout.slices.reduce(0) { $0 + $1.fraction } - 1)
            < 0.000_001
    )

    #expect(layout.slice(atFraction: 0)?.client == "mock-alpha")
    #expect(layout.slice(atFraction: 0.59)?.client == "mock-alpha")
    #expect(layout.slice(atFraction: 0.7)?.client == "mock-beta")
    #expect(layout.slice(atFraction: 0.85)?.client == "mock-gamma")
    #expect(layout.slice(atFraction: 0.98)?.client == "other")
    #expect(layout.slice(atFraction: -0.1) == nil)
    #expect(layout.slice(atFraction: 1) == nil)
}

private func clientSummary(
    _ client: String,
    tokens: Int64,
    cost: Double,
    messages: Int
) -> ClientUsageSummary {
    ClientUsageSummary(
        client: client,
        tokens: tokens,
        cost: cost,
        messages: messages
    )
}
