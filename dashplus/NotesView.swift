import SwiftUI
import SwiftData

struct NotesView: View {
    @Query private var items: [DashItem]

    private var noteItems: [DashItem] {
        items.filter { $0.symbol == .triangle }
    }

    private var groupedByList: [(header: String, items: [DashItem])] {
        let groups = Dictionary(grouping: noteItems) { item -> String in
            item.list?.id.uuidString ?? ""
        }
        return groups
            .sorted { a, b in
                let aPrefix = a.value.first?.list?.prefix ?? ""
                let bPrefix = b.value.first?.list?.prefix ?? ""
                if aPrefix.isEmpty && !bPrefix.isEmpty { return false }
                if !aPrefix.isEmpty && bPrefix.isEmpty { return true }
                return aPrefix < bPrefix
            }
            .map { _, groupItems in
                let list = groupItems.first?.list
                let header: String
                if let list {
                    header = list.prefix.isEmpty ? list.name : "\(list.prefix)  ·  \(list.name)"
                } else {
                    header = "General"
                }
                let sorted = groupItems.sorted { $0.createdAt < $1.createdAt }
                return (header: header, items: sorted)
            }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedByList, id: \.header) { group in
                    Section {
                        ForEach(group.items) { item in
                            DashItemRow(item: item)
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Image(systemName: "triangle")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.purple)
                            Text(group.header)
                                .textCase(nil)
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Notes")
            .overlay {
                if noteItems.isEmpty {
                    ContentUnavailableView(
                        "No Notes",
                        systemImage: "triangle",
                        description: Text("Items marked △ appear here grouped by list")
                    )
                }
            }
        }
    }
}
