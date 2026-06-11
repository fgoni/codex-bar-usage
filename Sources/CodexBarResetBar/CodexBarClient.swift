import Foundation

enum CodexBarClientError: Error, LocalizedError {
    case executableNotFound
    case timedOut
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            "codexbar CLI not found"
        case .timedOut:
            "codexbar timed out"
        case let .failed(message):
            message
        }
    }
}

protocol CodexBarRunning: Sendable {
    func fetch(provider: Provider) async -> ProviderReset
}

final class CodexBarClient: CodexBarRunning, @unchecked Sendable {
    private let executableURL: URL
    private let timeout: TimeInterval

    init(executablePath: String = "/opt/homebrew/bin/codexbar", timeout: TimeInterval = 20) {
        self.executableURL = URL(fileURLWithPath: executablePath)
        self.timeout = timeout
    }

    func fetch(provider: Provider) async -> ProviderReset {
        let attempts = self.arguments(for: provider)
        var lastError: String?

        for args in attempts {
            do {
                let data = try await self.run(args)
                let parsed = try CodexBarJSON.parse(data, expectedProvider: provider)
                if parsed.resetsAt != nil || parsed.resetDescription != nil {
                    return parsed
                }
                lastError = parsed.errorMessage ?? "No reset returned"
            } catch {
                lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }

        return ProviderReset(
            provider: provider,
            resetsAt: nil,
            resetDescription: nil,
            usedPercent: nil,
            updatedAt: nil,
            source: nil,
            errorMessage: lastError ?? "Unknown error")
    }

    private func arguments(for provider: Provider) -> [[String]] {
        let base = ["usage", "--provider", provider.rawValue, "--format", "json"]
        switch provider {
        case .codex:
            return [base + ["--source", "cli"], base + ["--source", "auto"]]
        case .claude:
            return [base + ["--source", "oauth"], base + ["--source", "auto"], base + ["--source", "cli"]]
        }
    }

    private func run(_ arguments: [String]) async throws -> Data {
        guard FileManager.default.isExecutableFile(atPath: self.executableURL.path) else {
            throw CodexBarClientError.executableNotFound
        }

        let process = Process()
        process.executableURL = self.executableURL
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()

        let timedOut = await withTaskGroup(of: Bool.self, returning: Bool.self) { group in
            group.addTask {
                while process.isRunning {
                    try? await Task.sleep(for: .milliseconds(100))
                }
                return false
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(self.timeout))
                if process.isRunning {
                    process.terminate()
                    return true
                }
                return false
            }
            let result = await group.next() ?? false
            group.cancelAll()
            return result
        }

        process.waitUntilExit()

        if timedOut {
            throw CodexBarClientError.timedOut
        }

        let output = stdout.fileHandleForReading.readDataToEndOfFile()
        if process.terminationStatus == 0 || !output.isEmpty {
            return output
        }

        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
        let message = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        throw CodexBarClientError.failed(message?.isEmpty == false ? message! : "codexbar exited with \(process.terminationStatus)")
    }
}
