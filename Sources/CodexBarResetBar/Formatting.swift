import Foundation

enum ResetFormatter {
    static func menuTitleParts(
        for snapshot: ResetSnapshot,
        providers: [Provider] = Provider.allCases,
        now: Date = .init()) -> [(Provider, String)]
    {
        providers.map { provider in
            (provider, self.compactTitle(for: snapshot.reset(for: provider), now: now))
        }
    }

    static func menuTitle(
        for snapshot: ResetSnapshot,
        providers: [Provider] = Provider.allCases,
        now: Date = .init()) -> String
    {
        self.menuTitleParts(for: snapshot, providers: providers, now: now)
            .map { "\($0.displayName) \($1)" }
            .joined(separator: "   ")
    }

    static func compactTitle(for reset: ProviderReset?, now: Date = .init()) -> String {
        guard let reset else { return "--" }
        if let date = reset.resetsAt {
            return self.durationUntil(date, now: now, includeSpace: false)
        }
        if let description = reset.resetDescription?.trimmingCharacters(in: .whitespacesAndNewlines),
           !description.isEmpty
        {
            return description.replacingOccurrences(of: "Resets ", with: "")
        }
        if reset.errorMessage != nil { return "err" }
        return "--"
    }

    static func menuDetail(for reset: ProviderReset, now: Date = .init()) -> String {
        if let error = reset.errorMessage, reset.resetsAt == nil {
            return "\(reset.provider.displayName): \(error)"
        }

        let resetText: String
        if let date = reset.resetsAt {
            resetText = self.durationUntil(date, now: now, includeSpace: true)
        } else if let description = reset.resetDescription, !description.isEmpty {
            resetText = description
        } else {
            resetText = "unknown"
        }

        var parts = ["\(reset.provider.displayName): \(resetText)"]
        if let used = reset.usedPercent {
            parts.append("\(Int(round(used)))% used")
        }
        if let source = reset.source {
            parts.append(source)
        }
        return parts.joined(separator: " · ")
    }

    static func updatedText(for snapshot: ResetSnapshot, now: Date = .init()) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(snapshot.fetchedAt)))
        if seconds < 60 { return "Updated just now" }
        let minutes = max(1, seconds / 60)
        return "Updated \(minutes)m ago"
    }

    static func durationUntil(_ date: Date, now: Date = .init(), includeSpace: Bool) -> String {
        let seconds = max(0, date.timeIntervalSince(now))
        if seconds < 1 { return "now" }

        let totalMinutes = max(1, Int(ceil(seconds / 60.0)))
        let days = totalMinutes / 1440
        let hours = (totalMinutes / 60) % 24
        let minutes = totalMinutes % 60
        let separator = includeSpace ? " " : ""

        if days > 0 {
            if hours > 0 { return "\(days)d\(separator)\(hours)h" }
            return "\(days)d"
        }
        if hours > 0 {
            if minutes > 0 { return "\(hours)h\(separator)\(minutes)m" }
            return "\(hours)h"
        }
        return "\(totalMinutes)m"
    }
}
