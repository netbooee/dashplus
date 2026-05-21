import SwiftUI
import SwiftData

struct ListsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DashList.createdAt) private var lists: [DashList]
    @State private var showingNewList = false
    @State private var editingList: DashList?
    @State private var expandedLists: Set<UUID> = []
    @State private var completedCollapsed: Set<UUID> = []
    @State private var somedayCollapsed: Set<UUID> = []
    @State private var showingImporter = false
    @State private var importError: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(lists) { list in
                    Section {
                        if expandedLists.contains(list.id) {
                            let active = list.itemList
                                .filter { $0.symbol != .plus && $0.symbol != .someday }
                                .sorted {
                                    $0.sortOrder == $1.sortOrder
                                        ? $0.createdAt < $1.createdAt
                                        : $0.sortOrder < $1.sortOrder
                                }
                            let someday = list.itemList
                                .filter { $0.symbol == .someday }
                                .sorted { $0.createdAt < $1.createdAt }
                            let completed = list.itemList
                                .filter { $0.symbol == .plus }
                                .sorted { $0.createdAt < $1.createdAt }

                            ForEach(active) { item in
                                DashItemRow(item: item, showPrefix: false)
                            }

                            if !someday.isEmpty {
                                CompletedArchiveDivider(
                                    title: "Someday / Maybe",
                                    isCollapsed: somedayCollapsed.contains(list.id),
                                    count: someday.count
                                ) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if somedayCollapsed.contains(list.id) {
                                            somedayCollapsed.remove(list.id)
                                        } else {
                                            somedayCollapsed.insert(list.id)
                                        }
                                    }
                                }
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))

                                if !somedayCollapsed.contains(list.id) {
                                    ForEach(someday) { item in
                                        DashItemRow(item: item, isCompact: true, showPrefix: false)
                                    }
                                }
                            }

                            if !completed.isEmpty {
                                CompletedArchiveDivider(
                                    isCollapsed: completedCollapsed.contains(list.id),
                                    count: completed.count
                                ) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if completedCollapsed.contains(list.id) {
                                            completedCollapsed.remove(list.id)
                                        } else {
                                            completedCollapsed.insert(list.id)
                                        }
                                    }
                                }
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))

                                if !completedCollapsed.contains(list.id) {
                                    ForEach(completed) { item in
                                        DashItemRow(item: item, isCompact: true, showPrefix: false)
                                    }
                                }
                            }

                            InlineAddItemRow(list: list)
                        }
                    } header: {
                        HStack(spacing: 0) {
                            // Expand / collapse toggle
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if expandedLists.contains(list.id) {
                                        expandedLists.remove(list.id)
                                    } else {
                                        expandedLists.insert(list.id)
                                    }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: expandedLists.contains(list.id) ? "chevron.down" : "chevron.right")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 14)

                                    if !list.prefix.isEmpty {
                                        Text(list.prefix)
                                            .font(.system(.caption, design: .monospaced, weight: .bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.secondary.opacity(0.12))
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    }

                                    Text(list.name)
                                        .font(.headline)
                                        .textCase(nil)
                                        .foregroundStyle(.primary)

                                    Text("·")
                                        .foregroundStyle(.tertiary)

                                    Text("\(list.itemList.count)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button { editingList = list } label: {
                                    Label("Edit List", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    modelContext.delete(list)
                                } label: {
                                    Label("Delete List", systemImage: "trash")
                                }
                            }

                            Spacer()

                            // Navigate to full list view
                            NavigationLink(destination: DashListView(list: list)) {
                                Image(systemName: "arrow.right.circle")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.trailing, 4)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Lists")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { showingNewList = true } label: {
                            Label("New List", systemImage: "plus")
                        }
                        Button { showingImporter = true } label: {
                            Label("Import as New List", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingNewList) {
                ListEditSheet()
            }
            .sheet(item: $editingList) { list in
                ListEditSheet(list: list)
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.plainText],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result: result)
            }
            .alert("Import Error", isPresented: .constant(importError != nil), presenting: importError) { _ in
                Button("OK") { importError = nil }
            } message: { error in
                Text(error)
            }
            .overlay {
                if lists.isEmpty {
                    ContentUnavailableView(
                        "No Lists",
                        systemImage: "folder",
                        description: Text("Tap + to create your first list")
                    )
                }
            }
        }
    }

    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                importError = "Could not access the selected file."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                DashPlusExporter.importAsNewList(from: text, context: modelContext)
            } catch {
                importError = error.localizedDescription
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }
}
