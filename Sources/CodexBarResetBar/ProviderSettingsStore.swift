import Foundation

@MainActor
struct ProviderSettingsStore {
    private let defaults: UserDefaults
    private let key = "enabledProviders"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var enabledProviders: [Provider] {
        let raw = self.defaults.stringArray(forKey: self.key)
        let providers = raw?
            .compactMap(Provider.init(rawValue:))
            .filter { Provider.allCases.contains($0) } ?? Provider.allCases
        return providers.isEmpty ? Provider.allCases : providers
    }

    func isEnabled(_ provider: Provider) -> Bool {
        self.enabledProviders.contains(provider)
    }

    func setEnabled(_ isEnabled: Bool, for provider: Provider) {
        var providers = self.enabledProviders
        if isEnabled {
            if !providers.contains(provider) {
                providers.append(provider)
            }
        } else {
            providers.removeAll { $0 == provider }
            if providers.isEmpty {
                providers = [provider]
            }
        }

        self.defaults.set(providers.map(\.rawValue), forKey: self.key)
    }
}
