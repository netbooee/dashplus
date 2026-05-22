import SwiftUI
import SwiftData

// MARK: - Type-safe group model (file-scope for ForEach inference)

fileprivate struct ListItemGroup: Identifiable {
    let title: String
    let symbol: ItemSymbol
    let items: [DashItem]
    var id: String { title }
}

// MARK: - DashListView

struct DashListView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var list: DashList
    @State private var showingAddItem = false
    @State private var showingEditList = false
    @State private var showingImporter = false
    @State private var importError: String?
    @State private var completedCollapsed = false
    @State private var somedayCollapsed = false

    // MARK: Symbol group order (mirrors All Items view)

    private static let symbolGroups: [(title: String, symbols: [ItemSymbol])] = [
        ("To Do",                    [.dash]),
        ("Meetings Need Scheduling", [.square]),
        ("Meetings Scheduled",       [.scheduledMeeting]),
        ("Delegated",                [.leftArrow]),
        ("Waiting For",              [.rightArrow]),
        ("Notes",                    [.triangle]),
        ("People",                   [.person]),
    ]

    // MARK: Computed item lists

    private var activeItems: [DashItem] {
        list.itemList
            .filter { $0.symbol != .plus && $0.symbol != .someday }
            .sorted {
                $0.sortOrder == $1.sortOrder
                    ? $0.createdAt < $1.createdAt
                    : $0.sortOrder < $1.sortOrder
            }
    }

    private var activeGroups: [ListItemGroup] {
        Self.symbolGroups.compactMap { group in
            let filtered = activeItems.filter { group.symbols.contains($0.symbol) }
            guard !filtered.isEmpty else { return nil }
            return ListItemGroup(title: group.title, symbol: group.symbols.first!, items: filtered)
        }
    }

    private var somedayItems: [DashItem] {
        list.itemList
            .filter { $0.symbol == .someday }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var completedItems: [DashItem] {
        list.itemList
            .filter { $0.symbol == .plus }
            .sorted { $0.createdAt < $1.createdAt }
    }

    // MARK: Body

    var body: some View {
        List {
            // Active items — grouped by symbol type
            ForEach(activeGroups) { group in
                groupHeader(title: group.title, symbol: group.symbol, count: group.items.count)

                ForEach(group.items) { item in
                    DashItemRow(item: item, showPrefix: false, showDate: true)
                }
                .onDelete { offsets in
                    for i in offsets { modelContext.delete(group.items[i]) }
                }
            }

            // Someday / Maybe
            if !somedayItems.isEmpty {
                CompletedArchiveDivider(
                    title: "Someday / Maybe",
                    isCollapsed: somedayCollapsed,
                    count: somedayItems.count
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) { somedayCollapsed.toggle() }
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))

                if !somedayCollapsed {
                    ForEach(somedayItems) { item in
                        DashItemRow(item: item, isCompact: true, showPrefix: false)
                    }
                    .onDelete(perform: deleteSomeday)
                }
            }

            // Completed
            if !completedItems.isEmpty {
                CompletedArchiveDivider(
                    isCollapsed: completedCollapsed,
                    count: completedItems.count
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) { completedCollapsed.toggle() }
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))

                if !completedCollapsed {
                    ForEach(completedItems) { item in
                        DashItemRow(item: item, isCompact: true, showPrefix: false)
                    }
                    .onDelete(perform: deleteCompleted)
                }
            }

            InlineAddItemRow(list: list)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.warmBg)
        .navigationTitle(list.prefix.isEmpty ? list.name : "\(list.prefix) · \(list.name)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    ShareLink(
                        item: DashPlusExporter.writeToTemp(list: list),
                        preview: SharePreview(
                            DashPlusExporter.exportFileName(for: list),
                            icon: Image(systemName: "doc.text")
                        )
                    ) {
                        Label("Export List", systemImage: "square.and.arrow.up")
                    }
                    Button { showingImporter = true } label: {
                        Label("Import into List", systemImage: "square.and.arrow.down")
                    }
                    Divider()
                    Button { showingAddItem = true } label: {
                        Label("New Item (Full)", systemImage: "square.and.pencil")
                    }
                    Button { showingEditList = true } label: {
                        Label("Edit List Name", systemImage: "pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }
        }
        .sheet(isPresented: $showingAddItem) {
            AddItemView(list: list)
        }
        .sheet(isPresented: $showingEditList) {
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

    // MARK: Group header (matches All Items styling)

    @ViewBuilder
    private func groupHeader(title: String, symbol: ItemSymbol, count: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol.systemImageName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(symbol.color)
                .frame(width: 16)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(symbol.color)
                .textCase(.uppercase)
            Spacer()
            Text("\(count)")
                .font(.caption.weight(.medium))
                .foregroundStyle(symbol.color)
                .monospacedDigit()
        }
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(symbol.color.opacity(0.12))
    }

    // MARK: Delete handlers

    private func deleteSomeday(at offsets: IndexSet) {
        for i in offsets { modelContext.delete(somedayItems[i]) }
    }

    private func deleteCompleted(at offsets: IndexSet) {
        for i in offsets { modelContext.delete(completedItems[i]) }
    }

    // MARK: Import

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
                DashPlusExporter.importItems(from: text, into: list, context: modelContext)
            } catch {
                importError = error.localizedDescription
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }
}
