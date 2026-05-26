import SwiftUI
import SwiftData
import TipKit

// MARK: - Tile sub-views

private struct ProjectTile: View {
    let list: DashList

    private var todoCount: Int      { list.itemList.filter { $0.symbol == .dash }.count }
    private var scheduleCount: Int  { list.itemList.filter { $0.symbol == .square }.count }
    private var delegatedCount: Int { list.itemList.filter { $0.symbol == .leftArrow }.count }
    private var waitingCount: Int   { list.itemList.filter { $0.symbol == .rightArrow }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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

            // Activity summary — only visible symbols with count > 0
            HStack(spacing: 8) {
                statBadge("minus",       count: todoCount,      color: ItemSymbol.dash.color)
                statBadge("square",      count: scheduleCount,  color: ItemSymbol.square.color)
                statBadge("arrow.left",  count: delegatedCount, color: ItemSymbol.leftArrow.color)
                statBadge("arrow.right", count: waitingCount,   color: ItemSymbol.rightArrow.color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func statBadge(_ icon: String, count: Int, color: Color) -> some View {
        if count > 0 {
            HStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .bold))
                Text("\(count)")
                    .font(.system(size: 9, weight: .semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(color)
        }
    }
}

// MARK: - ListsView

struct ListsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DashList.name) private var lists: [DashList]
    @State private var showingNewList = false
    @State private var editingList: DashList?
    @State private var showingImporter = false
    @State private var importError: String?

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    private let manageProjectTip = ManageProjectTip()

    // MARK: Tip helper — attaches popover only to the first project tile.
    @ViewBuilder
    private func tileView(for list: DashList) -> some View {
        let isFirst = list.id == lists.first?.id
        if isFirst {
            NavigationLink(destination: DashListView(list: list)) {
                ProjectTile(list: list)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button { editingList = list } label: {
                    Label("Edit Project", systemImage: "pencil")
                }
                Button(role: .destructive) { modelContext.delete(list) } label: {
                    Label("Delete Project", systemImage: "trash")
                }
            }
            .popoverTip(manageProjectTip, arrowEdge: .bottom)
        } else {
            NavigationLink(destination: DashListView(list: list)) {
                ProjectTile(list: list)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button { editingList = list } label: {
                    Label("Edit Project", systemImage: "pencil")
                }
                Button(role: .destructive) { modelContext.delete(list) } label: {
                    Label("Delete Project", systemImage: "trash")
                }
            }
        }
    }

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
                            tileView(for: list)
                        }
                    }
                    .padding(16)
                }
            }
            .background(Color.warmBg)
            .navigationTitle("Projects")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showingNewList = true } label: {
                        Label("New Project", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ShareLink(
                            item: DashPlusExporter.writeAllToTemp(lists: lists),
                            preview: SharePreview(
                                DashPlusExporter.exportAllFileName(),
                                icon: Image(systemName: "doc.text")
                            )
                        ) {
                            Label("Export All Projects", systemImage: "square.and.arrow.up.on.square")
                        }
                        Button { showingImporter = true } label: {
                            Label("Import Projects", systemImage: "square.and.arrow.down")
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
                if DashPlusExporter.isFullBackup(text) {
                    DashPlusExporter.importAll(from: text, context: modelContext)
                } else {
                    DashPlusExporter.importAsNewList(from: text, context: modelContext)
                }
            } catch {
                importError = error.localizedDescription
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }
}
