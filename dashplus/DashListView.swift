import SwiftUI
import SwiftData

struct DashListView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var list: DashList
    @State private var showingAddItem = false
    @State private var showingEditList = false
    @State private var showingImporter = false
    @State private var importError: String?
    @State private var completedCollapsed = false
    @State private var somedayCollapsed = false

    private var activeItems: [DashItem] {
        list.itemList
            .filter { $0.symbol != .plus && $0.symbol != .someday }
            .sorted {
                $0.sortOrder == $1.sortOrder
                    ? $0.createdAt < $1.createdAt
                    : $0.sortOrder < $1.sortOrder
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

    var body: some View {
        List {
            ForEach(activeItems) { item in
                DashItemRow(item: item, showPrefix: false)
            }
            .onDelete(perform: deleteActive)
            .onMove(perform: moveItems)

            if !somedayItems.isEmpty {
                CompletedArchiveDivider(
                    title: "Someday / Maybe",
                    isCollapsed: somedayCollapsed,
                    count: somedayItems.count
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        somedayCollapsed.toggle()
                    }
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

            if !completedItems.isEmpty {
                CompletedArchiveDivider(
                    isCollapsed: completedCollapsed,
                    count: completedItems.count
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        completedCollapsed.toggle()
                    }
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

                    Button {
                        showingImporter = true
                    } label: {
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
            handleImport(result: result, asNewList: false)
        }
        .alert("Import Error", isPresented: .constant(importError != nil), presenting: importError) { _ in
            Button("OK") { importError = nil }
        } message: { error in
            Text(error)
        }
    }

    private func deleteActive(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(activeItems[index]) }
    }

    private func deleteSomeday(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(somedayItems[index]) }
    }

    private func deleteCompleted(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(completedItems[index]) }
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        var sorted = activeItems
        sorted.move(fromOffsets: source, toOffset: destination)
        for (index, item) in sorted.enumerated() {
            item.sortOrder = index
        }
    }

    private func handleImport(result: Result<[URL], Error>, asNewList: Bool) {
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
