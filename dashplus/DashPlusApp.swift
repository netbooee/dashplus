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
            UserDefaults.standard.set("✅ Active", forKey: "happensnext.cloudKitStatus")
            UserDefaults.standard.removeObject(forKey: "happensnext.cloudKitError")
            print("✅ HappensNext: CloudKit container initialised successfully")
        } catch {
            let msg = error.localizedDescription
            UserDefaults.standard.set("❌ Failed", forKey: "happensnext.cloudKitStatus")
            UserDefaults.standard.set(msg, forKey: "happensnext.cloudKitError")
            print("❌ HappensNext: CloudKit init failed — \(error)")
            // Fallback to local-only
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
