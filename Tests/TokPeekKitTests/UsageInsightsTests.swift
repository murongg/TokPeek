import Foundation
import Testing

#if SWIFT_PACKAGE
    @testable import TokPeekKit
#endif

@Test("Usage insights aggregate token composition and clients")
func aggregatesUsageInsights() throws {
    let report = try CoreJSON.decoder.decode(
        UsageReport.self,
        from: Data(insightsFixture.utf8)
    )

    #expect(report.tokenComposition.input == 650)
    #expect(report.tokenComposition.output == 500)
    #expect(report.tokenComposition.cache == 325)
    #expect(report.tokenComposition.reasoning == 25)
    #expect(report.clientSummaries.map(\.client) == ["codex", "claude"])
    #expect(report.clientSummaries.first?.tokens == 900)
    #expect(report.clientSummaries.first?.messages == 6)
}

@Test("Model insights aggregate repeated models and rank by tokens")
func aggregatesAndRanksModels() throws {
    let report = modelRankingReport()

    #expect(
        report.modelSummaries.map(\.modelId)
            == ["mock-model-beta", "mock-model-alpha"]
    )
    #expect(report.modelSummaries.first?.providerId == "mock-provider")
    #expect(report.modelSummaries.first?.tokens == 700)
    #expect(report.modelSummaries.first?.cost == 0.7)
    #expect(report.modelSummaries.first?.messages == 7)
}

@Test("Model ranking uses two columns and shows up to eight items")
func modelRankingUsesTwoColumnsAndShowsEightItems() {
    #expect(ModelRankingLayout.columnCount == 2)
    #expect(ModelRankingLayout.maximumVisibleItems == 8)
}

@Test("Model filtering rebuilds every report aggregate")
func filtersReportByModel() {
    let report = modelRankingReport().filtered(
        modelId: "mock-model-beta"
    )

    #expect(report.summary.totalTokens == 700)
    #expect(report.summary.totalCost == 0.7)
    #expect(report.summary.totalDays == 2)
    #expect(report.summary.activeDays == 2)
    #expect(report.summary.averagePerDay == 0.35)
    #expect(report.summary.maxCostInSingleDay == 0.5)
    #expect(
        report.summary.clients
            == ["mock-client-alpha", "mock-client-gamma"]
    )
    #expect(report.summary.models == ["mock-model-beta"])

    #expect(report.contributions.map(\.totals.tokens) == [200, 500])
    #expect(
        report.contributions.flatMap(\.clients).map(\.modelId)
            == ["mock-model-beta", "mock-model-beta"]
    )
    #expect(report.tokenComposition.total == 700)
    #expect(
        report.clientSummaries.map(\.client)
            == ["mock-client-gamma", "mock-client-alpha"]
    )
    #expect(report.modelSummaries.map(\.modelId) == ["mock-model-beta"])
    #expect(report.years.map(\.totalTokens) == [700])
    #expect(report.hourlyContributions.map(\.totals.tokens) == [200, 500])
    #expect(
        report.hourlyContributions
            .flatMap(\.clients)
            .map(\.modelId)
            == ["mock-model-beta", "mock-model-beta"]
    )
}

@Test("Menu bar metrics produce compact stable labels")
func menuBarMetricsProduceLabels() throws {
    let report = try CoreJSON.decoder.decode(
        UsageReport.self,
        from: Data(insightsFixture.utf8)
    )

    #expect(UsageFormatting.menuBarTitle(for: .tokens, report: report) == "1.5K")
    #expect(UsageFormatting.menuBarTitle(for: .cost, report: report) == "$1.25")
    #expect(UsageFormatting.menuBarTitle(for: .summary, report: report) == nil)
    #expect(UsageFormatting.menuBarTitle(for: .iconOnly, report: report) == nil)

    let summary = UsageFormatting.menuBarSummary(for: report)
    #expect(summary.tokens == "1.5K")
    #expect(summary.cost == "$1.25")
    #expect(summary.stackedText == "$1.25\n1.5K")
}

@Test("Every menu bar display setting resolves to a distinct presentation")
func menuBarDisplaySettingsResolveDistinctPresentations() throws {
    let report = try CoreJSON.decoder.decode(
        UsageReport.self,
        from: Data(insightsFixture.utf8)
    )
    let summary = UsageFormatting.menuBarSummary(for: report)

    #expect(
        UsageFormatting.menuBarPresentation(
            for: .summary,
            report: report
        ) == .summary(summary)
    )
    #expect(
        UsageFormatting.menuBarPresentation(
            for: .tokens,
            report: report
        ) == .tokens("1.5K")
    )
    #expect(
        UsageFormatting.menuBarPresentation(
            for: .cost,
            report: report
        ) == .cost("$1.25")
    )
    #expect(
        UsageFormatting.menuBarPresentation(
            for: .iconOnly,
            report: report
        ) == .iconOnly
    )
    #expect(
        UsageFormatting.menuBarPresentation(
            for: .tokens,
            report: nil
        ) == .tokens(nil)
    )
    #expect(
        UsageFormatting.menuBarPresentation(
            for: .cost,
            report: nil
        ) == .cost(nil)
    )
}

@Test("Only single-metric menu bar modes expose visible text")
func singleMetricMenuBarModesExposeVisibleText() {
    #expect(
        MenuBarPresentation.tokens("1.5K").singleLineText == "1.5K"
    )
    #expect(
        MenuBarPresentation.cost("$1.25").singleLineText == "$1.25"
    )
    #expect(
        MenuBarPresentation.tokens(nil).singleLineText == "—"
    )
    #expect(
        MenuBarPresentation.cost(nil).singleLineText == "$—"
    )
    #expect(
        MenuBarPresentation.summary(nil).singleLineText == nil
    )
    #expect(
        MenuBarPresentation.iconOnly.singleLineText == nil
    )
}

private func modelRankingReport() -> UsageReport {
    UsageReport(
        meta: ReportMetadata(
            generatedAt: "2026-07-27T10:00:00Z",
            version: "4.7.0",
            dateRangeStart: "2026-07-26",
            dateRangeEnd: "2026-07-27",
            processingTimeMs: 1
        ),
        summary: UsageSummary(
            totalTokens: 1_100,
            totalCost: 1.1,
            totalDays: 2,
            activeDays: 2,
            averagePerDay: 550,
            maxCostInSingleDay: 0.7,
            clients: [
                "mock-client-alpha",
                "mock-client-beta",
                "mock-client-gamma",
            ],
            models: ["mock-model-alpha", "mock-model-beta"]
        ),
        years: [],
        contributions: [
            modelRankingDay(
                date: "2026-07-26",
                clients: [
                    modelRankingContribution(
                        client: "mock-client-alpha",
                        model: "mock-model-beta",
                        tokens: 200,
                        cost: 0.2,
                        messages: 2
                    ),
                    modelRankingContribution(
                        client: "mock-client-beta",
                        model: "mock-model-alpha",
                        tokens: 400,
                        cost: 0.4,
                        messages: 4
                    ),
                ]
            ),
            modelRankingDay(
                date: "2026-07-27",
                clients: [
                    modelRankingContribution(
                        client: "mock-client-gamma",
                        model: "mock-model-beta",
                        tokens: 500,
                        cost: 0.5,
                        messages: 5
                    )
                ]
            ),
        ],
        hourlyContributions: [
            modelRankingHour(
                hour: "2026-07-26 09:00",
                clients: [
                    modelRankingContribution(
                        client: "mock-client-alpha",
                        model: "mock-model-beta",
                        tokens: 200,
                        cost: 0.2,
                        messages: 2
                    ),
                    modelRankingContribution(
                        client: "mock-client-beta",
                        model: "mock-model-alpha",
                        tokens: 400,
                        cost: 0.4,
                        messages: 4
                    ),
                ]
            ),
            modelRankingHour(
                hour: "2026-07-27 10:00",
                clients: [
                    modelRankingContribution(
                        client: "mock-client-gamma",
                        model: "mock-model-beta",
                        tokens: 500,
                        cost: 0.5,
                        messages: 5
                    )
                ]
            ),
        ]
    )
}

private func modelRankingHour(
    hour: String,
    clients: [ClientContribution]
) -> HourlyContribution {
    let tokens = clients.reduce(0) {
        $0 + $1.tokens.totalTokens
    }
    return HourlyContribution(
        hour: hour,
        totals: DailyTotals(
            tokens: tokens,
            cost: clients.reduce(0) { $0 + $1.cost },
            messages: clients.reduce(0) { $0 + $1.messages }
        ),
        tokenBreakdown: TokenBreakdown(
            input: tokens,
            output: 0,
            cacheRead: 0,
            cacheWrite: 0,
            reasoning: 0
        ),
        clients: clients
    )
}

private func modelRankingDay(
    date: String,
    clients: [ClientContribution]
) -> DailyContribution {
    let tokens = clients.reduce(0) {
        $0 + $1.tokens.totalTokens
    }
    return DailyContribution(
        date: date,
        totals: DailyTotals(
            tokens: tokens,
            cost: clients.reduce(0) { $0 + $1.cost },
            messages: clients.reduce(0) { $0 + $1.messages }
        ),
        intensity: 1,
        tokenBreakdown: TokenBreakdown(
            input: tokens,
            output: 0,
            cacheRead: 0,
            cacheWrite: 0,
            reasoning: 0
        ),
        clients: clients,
        activeTimeMs: nil
    )
}

private func modelRankingContribution(
    client: String,
    model: String,
    tokens: Int64,
    cost: Double,
    messages: Int
) -> ClientContribution {
    ClientContribution(
        client: client,
        modelId: model,
        providerId: "mock-provider",
        tokens: TokenBreakdown(
            input: tokens,
            output: 0,
            cacheRead: 0,
            cacheWrite: 0,
            reasoning: 0
        ),
        cost: cost,
        messages: messages
    )
}

private let insightsFixture = """
    {
      "meta": {
        "generated_at": "2026-07-27T10:00:00Z",
        "version": "4.7.0",
        "date_range_start": "2026-07-26",
        "date_range_end": "2026-07-27",
        "processing_time_ms": 12
      },
      "summary": {
        "total_tokens": 1500,
        "total_cost": 1.25,
        "total_days": 2,
        "active_days": 2,
        "average_per_day": 750,
        "max_cost_in_single_day": 0.75,
        "clients": ["claude", "codex"],
        "models": ["claude-sonnet-4", "gpt-5"]
      },
      "years": [],
      "contributions": [
        {
          "date": "2026-07-26",
          "totals": { "tokens": 600, "cost": 0.50, "messages": 4 },
          "intensity": 2,
          "token_breakdown": {
            "input": 250,
            "output": 200,
            "cache_read": 100,
            "cache_write": 50,
            "reasoning": 0
          },
          "clients": [
            {
              "client": "claude",
              "model_id": "claude-sonnet-4",
              "provider_id": "anthropic",
              "tokens": {
                "input": 250,
                "output": 200,
                "cache_read": 100,
                "cache_write": 50,
                "reasoning": 0
              },
              "cost": 0.50,
              "messages": 4
            }
          ]
        },
        {
          "date": "2026-07-27",
          "totals": { "tokens": 900, "cost": 0.75, "messages": 6 },
          "intensity": 4,
          "token_breakdown": {
            "input": 400,
            "output": 300,
            "cache_read": 150,
            "cache_write": 25,
            "reasoning": 25
          },
          "clients": [
            {
              "client": "codex",
              "model_id": "gpt-5",
              "provider_id": "openai",
              "tokens": {
                "input": 400,
                "output": 300,
                "cache_read": 150,
                "cache_write": 25,
                "reasoning": 25
              },
              "cost": 0.75,
              "messages": 6
            }
          ]
        }
      ]
    }
    """
