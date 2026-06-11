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
                AppLog.codexbar.info("Running codexbar for \(provider.displayName, privacy: .public): \(args.joined(separator: " "), privacy: .public)")
                let data = try await self.run(args)
                let parsed = try CodexBarJSON.parse(data, expectedProvider: provider)
                if parsed.resetsAt != nil || parsed.resetDescription != nil {
                    AppLog.codexbar.info("Loaded reset for \(provider.displayName, privacy: .public) from \(parsed.source ?? "unknown", privacy: .public)")
                    return parsed
                }
                lastError = parsed.errorMessage ?? "No reset returned"
                AppLog.codexbar.warning("No reset returned for \(provider.displayName, privacy: .public): \(lastError ?? "unknown", privacy: .public)")
            } catch {
                lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                AppLog.codexbar.warning("codexbar failed for \(provider.displayName, privacy: .public): \(lastError ?? "unknown", privacy: .public)")
            }
        }

        AppLog.codexbar.error("Giving up on \(provider.displayName, privacy: .public): \(lastError ?? "Unknown error", privacy: .public)")
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
        let base = ["usage", "--provider", provider.codexBarProviderID, "--format", "json"]
        switch provider {
        case .codex:
            return [base + ["--source", "cli"], base + ["--source", "auto"]]
        case .claude:
            return [base + ["--source", "oauth"], base + ["--source", "auto"], base + ["--source", "cli"]]
        default:
            return [base + ["--source", "auto"], base]
        }
    }

    private func run(_ arguments: [String]) async throws -> Data {
        guard FileManager.default.isExecutableFile(atPath: self.executableURL.path) else {
            AppLog.codexbar.error("codexbar CLI not found at \(self.executableURL.path, privacy: .public)")
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
            AppLog.codexbar.error("codexbar timed out: \(arguments.joined(separator: " "), privacy: .public)")
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
