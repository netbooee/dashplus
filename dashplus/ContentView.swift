import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("happensnext.hasSeenOnboarding") private var hasSeenOnboarding = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("HappensNext", systemImage: "list.bullet") }
            ListsView()
                .tabItem { Label("Projects", systemImage: "folder") }
            KPIView()
                .tabItem { Label("Dashboard", systemImage: "chart.bar.xaxis") }
            PeopleView()
                .tabItem { Label("People", systemImage: "person.2") }
            NotesView()
                .tabItem { Label("Notes", systemImage: "triangle") }
        }
        .fullScreenCover(isPresented: .constant(!hasSeenOnboarding)) {
            OnboardingView {
                hasSeenOnboarding = true
                // Unlock tips the moment onboarding is dismissed for the first time.
                DeleteItemTip.unlockAfterOnboarding()
            }
        }
        .task {
            SampleDataSeeder.seedIfNeeded(context: modelContext)
            // Returning users who already completed onboarding before tips were
            // introduced need the gate opened on every cold launch.
            if hasSeenOnboarding {
                DeleteItemTip.unlockAfterOnboarding()
            }
        }
    }
}
