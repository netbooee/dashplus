import SwiftUI
import SwiftData
import TipKit

@main
struct DashPlusApp: App {
    let container: ModelContainer

    init() {
        // Show tips immediately on first launch; dismissed tips never reappear.
        try? Tips.configure([.displayFrequency(.immediate)])

        let schema = Schema([DashList.self, DashItem.self])
        do {
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private("iCloud.com.tonymartinez.dashplus")
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
