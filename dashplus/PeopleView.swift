import SwiftUI
import SwiftData

struct PeopleView: View {
    @Query private var items: [DashItem]

    private var delegatedItems: [DashItem] {
        items.filter { $0.symbol == .leftArrow }
    }

    private var contactItems: [DashItem] {
        items
            .filter { $0.symbol == .person }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var groupedByPerson: [(String, [DashItem])] {
        let named = delegatedItems.filter { !$0.assignedTo.isEmpty }
        let unnamed = delegatedItems.filter { $0.assignedTo.isEmpty }

        var groups = Dictionary(grouping: named) { $0.assignedTo }
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }

        if !unnamed.isEmpty {
            groups.append(("Unassigned", unnamed))
        }
        return groups
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedByPerson, id: \.0) { person, personItems in
                    Section {
                        ForEach(personItems) { item in
                            DashItemRow(item: item)
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Image(systemName: "person.circle.fill")
                                .foregroundStyle(.blue)
                            Text(person == "Unassigned" ? person : "@\(person)")
                                .textCase(nil)
                                .font(.headline)
                        }
                    }
                }

                if !contactItems.isEmpty {
                    Section {
                        ForEach(contactItems) { item in
                            DashItemRow(item: item)
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Image(systemName: "person.badge.plus")
                                .foregroundStyle(.cyan)
                            Text("New Contacts")
                                .textCase(nil)
                                .font(.headline)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("People")
            .overlay {
                if delegatedItems.isEmpty && contactItems.isEmpty {
                    ContentUnavailableView(
                        "No People",
                        systemImage: "person.2",
                        description: Text("Delegated items and new contacts appear here")
                    )
                }
            }
        }
    }
}
