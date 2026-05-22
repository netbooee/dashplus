import SwiftUI
import SwiftData

// MARK: - Tile sub-views

private struct ProjectTile: View {
    let list: DashList
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                PrefixChip(prefix: list.prefix, large: true)
                Spacer()
                Text("\(list.itemList.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Text(list.name)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct NewProjectTile: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.appAccent)
            Text("New Project")
                .font(.headline)
                .foregroundStyle(Color.appAccent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.appAccent.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.appAccent.opacity(0.3), lineWidth: 1.5)
        }
    }
}

// MARK: - ListsView

struct ListsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DashList.createdAt) private var lists: [DashList]
    @State private var showingNewList = false
    @State private var editingList: DashList?
    @State private var showingImporter = false
    @State private var importError: String?

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if lists.isEmpty {
                    // Empty state inside the scroll view
                    VStack(spacing: 16) {
                        Image(systemName: "folder")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No Projects")
                            .font(.title3.weight(.semibold))
                        Text("Tap New Project to get started")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(lists) { list in
                            NavigationLink(destination: DashListView(list: list)) {
                                ProjectTile(list: list)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button { editingList = list } label: {
                                    Label("Edit Project", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    modelContext.delete(list)
                                } label: {
                                    Label("Delete Project", systemImage: "trash")
                                }
                            }
                        }

                        Button { showingNewList = true } label: {
                            NewProjectTile()
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                }
            }
            .background(Color.warmBg)
            .navigationTitle("Projects")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { showingNewList = true } label: {
                            Label("New Project", systemImage: "plus")
                        }
                        Button { showingImporter = true } label: {
                            Label("Import as New Project", systemImage: "square.and.arrow.down")
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
