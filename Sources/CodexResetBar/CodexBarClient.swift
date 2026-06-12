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

    init(executablePath: String = "/opt/homebrew/bin/codexbar", timeout: TimeInterval = 45) {
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

        let timedOut = await self.waitForTermination(of: process, arguments: arguments)
        process.terminationHandler = nil

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

    private func waitForTermination(of process: Process, arguments: [String]) async -> Bool {
        await withCheckedContinuation { continuation in
            let observer = ProcessTerminationObserver(continuation: continuation)

            process.terminationHandler = { _ in
                observer.resume(timedOut: false)
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + self.timeout) {
                guard process.isRunning else {
                    observer.resume(timedOut: false)
                    return
                }

                AppLog.codexbar.error("codexbar timed out: \(arguments.joined(separator: " "), privacy: .public)")
                process.terminate()
                observer.resume(timedOut: true)
            }

            if !process.isRunning {
                observer.resume(timedOut: false)
            }
        }
    }
}

private final class ProcessTerminationObserver: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false
    private let continuation: CheckedContinuation<Bool, Never>

    init(continuation: CheckedContinuation<Bool, Never>) {
        self.continuation = continuation
    }

    func resume(timedOut: Bool) {
        self.lock.lock()
        defer { self.lock.unlock() }

        guard !self.didResume else { return }
        self.didResume = true
        self.continuation.resume(returning: timedOut)
    }
}
