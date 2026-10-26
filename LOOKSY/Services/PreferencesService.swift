import Foundation
import Observation

/// Loads and saves the personal style profile as a local JSON file.
@Observable
final class PreferencesService {
    var preferences: UserPreferences {
        didSet {
            guard preferences != oldValue else { return }
            save()
        }
    }

    @ObservationIgnored private let fileURL: URL

    init(fileURL: URL? = nil) {
        let url = fileURL ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LOOKSY/preferences.json")
        self.fileURL = url
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(UserPreferences.self, from: data) {
            preferences = decoded
        } else {
            preferences = UserPreferences()
        }
    }

    func replace(with newPreferences: UserPreferences) {
        preferences = newPreferences
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(preferences)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            AppLogger.storage.error("Could not save preferences")
        }
    }
}
