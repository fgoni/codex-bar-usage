import Foundation

enum Provider: String, CaseIterable, Sendable {
    case claude
    case codex
    case cursor
    case minimax
    case grok
    case groqCloud = "groqcloud"
    case zai
    case gemini
    case antigravity
    case copilot
    case openRouter = "openrouter"
    case kilo
    case kiro
    case factory
    case vertexAI = "vertexai"

    static let defaultEnabled: [Provider] = [.claude, .codex]

    var displayName: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex"
        case .cursor: "Cursor"
        case .minimax: "MiniMax"
        case .grok: "Grok"
        case .groqCloud: "Groq Cloud"
        case .zai: "z.ai"
        case .gemini: "Gemini"
        case .antigravity: "Antigravity"
        case .copilot: "Copilot"
        case .openRouter: "OpenRouter"
        case .kilo: "Kilo"
        case .kiro: "Kiro"
        case .factory: "Droid"
        case .vertexAI: "Vertex AI"
        }
    }

    var menuSymbol: String {
        String(self.displayName.prefix(1))
    }

    var codexBarProviderID: String {
        self.rawValue
    }

    var payloadProviderIDs: Set<String> {
        switch self {
        case .groqCloud:
            [self.rawValue, "groq"]
        default:
            [self.rawValue]
        }
    }

    var iconResourceName: String {
        switch self {
        case .groqCloud:
            "ProviderIcon-groq"
        default:
            "ProviderIcon-\(self.rawValue)"
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
        let match = payloads.first { expectedProvider.payloadProviderIDs.contains($0.provider) } ?? payloads.first

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
