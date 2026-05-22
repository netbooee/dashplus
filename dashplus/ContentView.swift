import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("All Items", systemImage: "list.bullet") }
            ListsView()
                .tabItem { Label("Projects", systemImage: "folder") }
            KPIView()
                .tabItem { Label("Dashboard", systemImage: "chart.bar.xaxis") }
            PeopleView()
                .tabItem { Label("People", systemImage: "person.2") }
            NotesView()
                .tabItem { Label("Notes", systemImage: "triangle") }
        }
    }
}
