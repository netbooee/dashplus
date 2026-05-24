import SwiftUI

struct ContentView: View {
    @AppStorage("happensnext.hasSeenOnboarding") private var hasSeenOnboarding = false

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
            OnboardingView { hasSeenOnboarding = true }
        }
    }
}
