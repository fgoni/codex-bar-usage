import Foundation
import Testing
@testable import CodexBarResetBar

@Test
func parsesPrimaryResetFromCodexBarJSON() throws {
    let json = """
    [
      {
        "provider": "codex",
        "source": "codex-cli",
        "usage": {
          "primary": {
            "resetsAt": "2026-06-11T15:47:09Z",
            "resetDescription": "12:47 PM",
            "usedPercent": 38,
            "windowMinutes": 300
          },
          "updatedAt": "2026-06-11T14:42:43Z"
        }
      }
    ]
    """.data(using: .utf8)!

    let reset = try CodexBarJSON.parse(json, expectedProvider: .codex)

    #expect(reset.provider == .codex)
    #expect(reset.source == "codex-cli")
    #expect(reset.usedPercent == 38)
    #expect(reset.resetsAt == ISO8601DateFormatter().date(from: "2026-06-11T15:47:09Z"))
}

@Test
func formatsCompactMenuTitle() {
    let now = ISO8601DateFormatter().date(from: "2026-06-11T14:00:00Z")!
    let snapshot = ResetSnapshot(
        providers: [
            ProviderReset(
                provider: .claude,
                resetsAt: ISO8601DateFormatter().date(from: "2026-06-11T16:19:59Z"),
                resetDescription: nil,
                usedPercent: 39,
                updatedAt: nil,
                source: "oauth",
                errorMessage: nil),
            ProviderReset(
                provider: .codex,
                resetsAt: ISO8601DateFormatter().date(from: "2026-06-11T15:47:09Z"),
                resetDescription: nil,
                usedPercent: 38,
                updatedAt: nil,
                source: "codex-cli",
                errorMessage: nil),
        ],
        fetchedAt: now)

    #expect(ResetFormatter.menuTitle(for: snapshot, now: now) == "Cl 2h20m | Cx 1h48m")
}

@Test
func displaysErrorWhenResetIsUnavailable() {
    let reset = ProviderReset(
        provider: .claude,
        resetsAt: nil,
        resetDescription: nil,
        usedPercent: nil,
        updatedAt: nil,
        source: nil,
        errorMessage: "codexbar timed out")

    #expect(ResetFormatter.compactTitle(for: reset) == "err")
    #expect(ResetFormatter.menuDetail(for: reset).contains("codexbar timed out"))
}
