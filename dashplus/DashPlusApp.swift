import SwiftUI
import SwiftData

@main
struct DashPlusApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([DashList.self, DashItem.self])
        do {
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            // Fallback to local-only if CloudKit is unavailable (e.g. no iCloud account)
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try! ModelContainer(for: schema, configurations: config)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
