import Foundation

/// Manages reader appearance settings with UserDefaults persistence.
final class SettingsStore: ObservableObject {
    @Published var settings: ReaderSettings {
        didSet { save() }
    }

    private let key = "readerSettings"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(ReaderSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = .default
        }
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // MARK: - Convenience Methods

    func increaseFontSize() {
        settings.fontSize = min(settings.fontSize + 2, 32)
    }

    func decreaseFontSize() {
        settings.fontSize = max(settings.fontSize - 2, 14)
    }

    func nextTheme() {
        let allThemes = ReaderSettings.ReaderTheme.allCases
        guard let currentIndex = allThemes.firstIndex(of: settings.theme) else { return }
        let nextIndex = (currentIndex + 1) % allThemes.count
        settings.theme = allThemes[nextIndex]
    }
}
