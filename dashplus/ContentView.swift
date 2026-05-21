import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("All Items", systemImage: "list.bullet") }
            ListsView()
                .tabItem { Label("Lists", systemImage: "folder") }
            PeopleView()
                .tabItem { Label("People", systemImage: "person.2") }
            NotesView()
                .tabItem { Label("Notes", systemImage: "triangle") }
        }
    }
}
