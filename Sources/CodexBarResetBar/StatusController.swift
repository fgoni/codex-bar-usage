import AppKit
import Foundation

@MainActor
final class StatusController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let client: CodexBarRunning
    private var snapshot: ResetSnapshot?
    private var refreshTask: Task<Void, Never>?
    private var timer: Timer?

    init(client: CodexBarRunning = CodexBarClient()) {
        self.client = client
        super.init()
        self.configureStatusItem()
        self.configureMenu()
        self.refresh()
        self.timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    private func configureStatusItem() {
        self.statusItem.button?.imageScaling = .scaleNone
        self.statusItem.button?.attributedTitle = self.makeTitle(parts: [(.claude, "--"), (.codex, "--")])
        self.statusItem.button?.toolTip = "Claude and Codex 5h reset timers"
    }

    private func configureMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Loading...", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Refresh", action: #selector(refreshFromMenu), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        self.statusItem.menu = menu
    }

    private func rebuildMenu() {
        guard let menu = self.statusItem.menu else { return }
        menu.removeAllItems()

        if let snapshot {
            for provider in Provider.allCases {
                if let reset = snapshot.reset(for: provider) {
                    menu.addItem(NSMenuItem(title: ResetFormatter.menuDetail(for: reset), action: nil, keyEquivalent: ""))
                } else {
                    menu.addItem(NSMenuItem(title: "\(provider.displayName): unavailable", action: nil, keyEquivalent: ""))
                }
            }
            menu.addItem(NSMenuItem(title: ResetFormatter.updatedText(for: snapshot), action: nil, keyEquivalent: ""))
        } else {
            menu.addItem(NSMenuItem(title: "Loading...", action: nil, keyEquivalent: ""))
        }

        menu.addItem(.separator())
        let refresh = NSMenuItem(title: "Refresh", action: #selector(refreshFromMenu), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        let quit = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    private func updateTitle() {
        guard let snapshot else {
            self.statusItem.button?.attributedTitle = self.makeTitle(parts: [(.claude, "--"), (.codex, "--")])
            return
        }
        self.statusItem.button?.attributedTitle = self.makeTitle(parts: ResetFormatter.menuTitleParts(for: snapshot))
    }

    private func makeTitle(parts: [(Provider, String)]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .medium),
            .foregroundColor: NSColor.white,
        ]

        for (index, part) in parts.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: "   ", attributes: attributes))
            }
            result.append(BrandIcon.attachment(for: part.0))
            result.append(NSAttributedString(string: " \(part.1)", attributes: attributes))
        }

        return result
    }

    private func refresh() {
        if self.refreshTask != nil { return }
        self.statusItem.button?.toolTip = "Refreshing Claude and Codex reset timers..."

        self.refreshTask = Task { [client] in
            async let claude = client.fetch(provider: .claude)
            async let codex = client.fetch(provider: .codex)
            let snapshot = await ResetSnapshot(providers: [claude, codex], fetchedAt: Date())
            await MainActor.run {
                self.snapshot = snapshot
                self.refreshTask = nil
                self.updateTitle()
                self.rebuildMenu()
                self.statusItem.button?.toolTip = "Claude and Codex 5h reset timers"
            }
        }
    }

    @objc private func refreshFromMenu() {
        self.refresh()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
