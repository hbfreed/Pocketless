import SwiftUI
import SwiftData

@main
struct PocketlessApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    let modelContainer: ModelContainer

    init() {
        let schema = Schema([Recording.self, Transcript.self, Summary.self])
        let config = ModelConfiguration(schema: schema)

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Schema migration failed — delete the old store and retry
            // This is acceptable during development; ship with a proper migration for production
            let storeURL = config.url
            try? FileManager.default.removeItem(at: storeURL)
            // Also remove WAL/SHM files
            let walURL = storeURL.appendingPathExtension("wal")  // not right but close
            let shmURL = storeURL.appendingPathExtension("shm")
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + "-wal"))
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + "-shm"))

            do {
                modelContainer = try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Failed to create ModelContainer even after reset: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
            } else {
                OnboardingView()
            }
        }
        .modelContainer(modelContainer)
    }
}
