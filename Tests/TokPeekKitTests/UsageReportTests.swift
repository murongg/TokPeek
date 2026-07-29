import Foundation
import Testing

#if SWIFT_PACKAGE
    @testable import TokPeekKit
#endif

@Test("Tokscale graph JSON decodes into the UI report model")
func decodesGraphReport() throws {
    let json = """
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
                "input": 300,
                "output": 200,
                "cache_read": 80,
                "cache_write": 20,
                "reasoning": 0
              },
              "clients": []
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
              "clients": []
            }
          ]
        }
        """

    let report = try CoreJSON.decoder.decode(
        UsageReport.self,
        from: Data(json.utf8)
    )

    #expect(report.summary.totalTokens == 1_500)
    #expect(report.summary.totalCost == 1.25)
    #expect(report.latestContribution?.date == "2026-07-27")
    #expect(report.latestContribution?.tokenBreakdown.reasoning == 25)
}

@Test("A request uses the camel-case JSON contract expected by the Rust bridge")
func encodesUsageRequest() throws {
    let request = UsageRequest(
        clients: ["claude", "codex"],
        since: "2026-07-01",
        hourly: true,
        startTimeMs: 1_785_283_200_000,
        endTimeMs: 1_785_369_600_000,
        useEnvironmentRoots: true
    )

    let data = try CoreJSON.encoder.encode(request)
    let object = try #require(
        JSONSerialization.jsonObject(with: data) as? [String: Any]
    )

    #expect(object["clients"] as? [String] == ["claude", "codex"])
    #expect(object["since"] as? String == "2026-07-01")
    #expect(object["hourly"] as? Bool == true)
    #expect(object["startTimeMs"] as? Int64 == 1_785_283_200_000)
    #expect(object["endTimeMs"] as? Int64 == 1_785_369_600_000)
    #expect(object["useEnvironmentRoots"] as? Bool == true)
}

@Test("Hourly contributions decode with model-level details")
func decodesHourlyContributions() throws {
    let json = """
        {
          "meta": {
            "generated_at": "2026-07-27T10:00:00Z",
            "version": "4.7.0",
            "date_range_start": "2026-07-27",
            "date_range_end": "2026-07-27",
            "processing_time_ms": 12
          },
          "summary": {
            "total_tokens": 100,
            "total_cost": 0.10,
            "total_days": 1,
            "active_days": 1,
            "average_per_day": 100,
            "max_cost_in_single_day": 0.10,
            "clients": ["codex"],
            "models": ["gpt-5"]
          },
          "years": [],
          "contributions": [],
          "hourly_contributions": [
            {
              "hour": "2026-07-27 09:00",
              "totals": { "tokens": 100, "cost": 0.10, "messages": 2 },
              "token_breakdown": {
                "input": 60,
                "output": 40,
                "cache_read": 0,
                "cache_write": 0,
                "reasoning": 0
              },
              "clients": [
                {
                  "client": "codex",
                  "model_id": "gpt-5",
                  "provider_id": "openai",
                  "tokens": {
                    "input": 60,
                    "output": 40,
                    "cache_read": 0,
                    "cache_write": 0,
                    "reasoning": 0
                  },
                  "cost": 0.10,
                  "messages": 2
                }
              ]
            }
          ]
        }
        """

    let report = try CoreJSON.decoder.decode(
        UsageReport.self,
        from: Data(json.utf8)
    )

    #expect(report.hourlyContributions.count == 1)
    #expect(report.hourlyContributions.first?.hour == "2026-07-27 09:00")
    #expect(report.hourlyContributions.first?.totals.tokens == 100)
    #expect(report.hourlyContributions.first?.clients.first?.modelId == "gpt-5")
}
