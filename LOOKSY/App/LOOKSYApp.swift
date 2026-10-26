import SwiftUI
import SwiftData

@main
struct LOOKSYApp: App {
    @State private var router = AppRouter()
    @State private var preferences = PreferencesService()
    private let container: ModelContainer

    init() {
        container = LOOKSYApp.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(router)
                .environment(preferences)
                .tint(Theme.accent)
        }
        .modelContainer(container)
    }

    static let schema = Schema([
        Garment.self,
        Look.self,
        LookCollection.self,
        PlannedOutfit.self,
        InspirationReference.self
    ])

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Never crash on a corrupted store: fall back to memory and log the event.
            AppLogger.storage.fault("Persistent store could not be opened; using in-memory store")
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            // swiftlint:disable:next force_try
            return try! ModelContainer(for: schema, configurations: [fallback])
        }
    }
}
