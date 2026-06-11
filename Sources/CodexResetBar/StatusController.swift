import AppKit
import Foundation

@MainActor
final class StatusController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let client: CodexBarRunning
    private let settingsStore: ProviderSettingsStore
    private var snapshot: ResetSnapshot?
    private var refreshTask: Task<Void, Never>?
    private var timer: Timer?

    init(
        client: CodexBarRunning = CodexBarClient(),
        settingsStore: ProviderSettingsStore = ProviderSettingsStore())
    {
        self.client = client
        self.settingsStore = settingsStore
        super.init()
        AppLog.app.info("Starting CodexResetBar")
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
        self.statusItem.button?.attributedTitle = self.makeTitle(parts: self.loadingTitleParts())
        self.statusItem.button?.toolTip = self.toolTipText()
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
            for provider in self.settingsStore.enabledProviders {
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
        menu.addItem(self.makeProvidersMenuItem())

        let refresh = NSMenuItem(title: "Refresh", action: #selector(refreshFromMenu), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        let quit = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    private func updateTitle() {
        guard let snapshot else {
            self.statusItem.button?.attributedTitle = self.makeTitle(parts: self.loadingTitleParts())
            return
        }
        self.statusItem.button?.attributedTitle = self.makeTitle(parts: ResetFormatter.menuTitleParts(
            for: snapshot,
            providers: self.settingsStore.enabledProviders))
    }

    private func loadingTitleParts() -> [(Provider, String)] {
        self.settingsStore.enabledProviders.map { ($0, "--") }
    }

    private func makeTitle(parts: [(Provider, String)]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var foregroundColor = NSColor.labelColor
        self.statusItem.button?.effectiveAppearance.performAsCurrentDrawingAppearance {
            foregroundColor = NSColor.labelColor
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.menuBarFont(ofSize: 0),
            .foregroundColor: foregroundColor,
        ]

        for (index, part) in parts.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: "   ", attributes: attributes))
            }
            result.append(BrandIcon.attachment(for: part.0, color: .white))
            result.append(NSAttributedString(string: " \(part.1)", attributes: attributes))
        }

        return result
    }

    private func refresh() {
        if self.refreshTask != nil { return }
        self.statusItem.button?.toolTip = "Refreshing \(self.providerListText()) reset timers..."
        let providers = self.settingsStore.enabledProviders
        AppLog.providers.info("Refreshing providers: \(providers.map(\.displayName).joined(separator: ", "), privacy: .public)")

        self.refreshTask = Task { [client] in
            let resets = await withTaskGroup(of: ProviderReset.self, returning: [ProviderReset].self) { group in
                for provider in providers {
                    group.addTask {
                        await client.fetch(provider: provider)
                    }
                }

                var values: [ProviderReset] = []
                for await reset in group {
                    values.append(reset)
                }
                return values.sorted {
                    let left = providers.firstIndex(of: $0.provider) ?? providers.endIndex
                    let right = providers.firstIndex(of: $1.provider) ?? providers.endIndex
                    return left < right
                }
            }
            let snapshot = ResetSnapshot(providers: resets, fetchedAt: Date())
            await MainActor.run {
                self.snapshot = snapshot
                self.refreshTask = nil
                self.updateTitle()
                self.rebuildMenu()
                self.statusItem.button?.toolTip = self.toolTipText()
            }
        }
    }

    private func makeProvidersMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Providers", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        let enabled = self.settingsStore.enabledProviders

        for provider in Provider.allCases {
            let providerItem = NSMenuItem(
                title: provider.displayName,
                action: #selector(toggleProvider(_:)),
                keyEquivalent: "")
            providerItem.target = self
            providerItem.representedObject = provider.rawValue
            providerItem.state = enabled.contains(provider) ? .on : .off
            providerItem.isEnabled = enabled.count > 1 || !enabled.contains(provider)
            submenu.addItem(providerItem)
        }

        item.submenu = submenu
        return item
    }

    private func providerListText() -> String {
        self.settingsStore.enabledProviders.map(\.displayName).joined(separator: " and ")
    }

    private func toolTipText() -> String {
        "\(self.providerListText()) 5h reset timers"
    }

    @objc private func refreshFromMenu() {
        self.refresh()
    }

    @objc private func toggleProvider(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let provider = Provider(rawValue: raw)
        else {
            return
        }

        self.settingsStore.setEnabled(!self.settingsStore.isEnabled(provider), for: provider)
        let isEnabled = self.settingsStore.isEnabled(provider)
        AppLog.providers.info("Provider \(provider.displayName, privacy: .public) \(isEnabled ? "enabled" : "disabled", privacy: .public)")
        self.snapshot = nil
        self.updateTitle()
        self.rebuildMenu()
        self.refresh()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
