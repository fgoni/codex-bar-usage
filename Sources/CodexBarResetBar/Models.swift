import Foundation

enum Provider: String, CaseIterable, Sendable {
    case claude
    case codex

    var displayName: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex"
        }
    }

    var menuSymbol: String {
        switch self {
        case .claude: "C"
        case .codex: "X"
        }
    }
}

struct ProviderReset: Equatable, Sendable {
    let provider: Provider
    let resetsAt: Date?
    let resetDescription: String?
    let usedPercent: Double?
    let updatedAt: Date?
    let source: String?
    let errorMessage: String?
}

struct ResetSnapshot: Equatable, Sendable {
    let providers: [ProviderReset]
    let fetchedAt: Date

    func reset(for provider: Provider) -> ProviderReset? {
        self.providers.first { $0.provider == provider }
    }
}

struct CodexBarPayload: Decodable {
    let provider: String
    let source: String?
    let usage: UsageSnapshot?
    let error: ProviderError?
}

struct ProviderError: Decodable {
    let message: String?
}

struct UsageSnapshot: Decodable {
    let primary: RateWindow?
    let updatedAt: Date?
}

struct RateWindow: Decodable {
    let usedPercent: Double?
    let windowMinutes: Int?
    let resetsAt: Date?
    let resetDescription: String?
}

enum CodexBarJSON {
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func parse(_ data: Data, expectedProvider: Provider) throws -> ProviderReset {
        let payloads = try self.decoder.decode([CodexBarPayload].self, from: data)
        let match = payloads.first { $0.provider == expectedProvider.rawValue } ?? payloads.first

        guard let match else {
            return ProviderReset(
                provider: expectedProvider,
                resetsAt: nil,
                resetDescription: nil,
                usedPercent: nil,
                updatedAt: nil,
                source: nil,
                errorMessage: "No payload returned")
        }

        return ProviderReset(
            provider: expectedProvider,
            resetsAt: match.usage?.primary?.resetsAt,
            resetDescription: match.usage?.primary?.resetDescription,
            usedPercent: match.usage?.primary?.usedPercent,
            updatedAt: match.usage?.updatedAt,
            source: match.source,
            errorMessage: match.error?.message)
    }
}
