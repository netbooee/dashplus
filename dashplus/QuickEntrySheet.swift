import SwiftUI
import SwiftData

struct QuickEntrySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DashList.prefix) private var lists: [DashList]

    @State private var selectedListID: UUID?
    @State private var selectedSymbol: ItemSymbol = .dash
    @State private var text = ""
    @State private var showingNewProject = false
    @FocusState private var textFocused: Bool

    private var sortedLists: [DashList] {
        let gen = lists.filter { $0.prefix == "GEN" }
        let rest = lists.filter { $0.prefix != "GEN" }.sorted { $0.prefix < $1.prefix }
        return gen + rest
    }

    private let symbolColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {

                // Project pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        // New project button
                        Button { showingNewProject = true } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.appAccent)
                                .frame(width: 44, height: 44)
                                .background(Color.appAccent.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.appAccent.opacity(0.3), lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)

                        ForEach(sortedLists) { list in
                            let label = list.prefix.isEmpty ? list.name : list.prefix
                            PrefixPill(label: label, isSelected: selectedListID == list.id) {
                                selectedListID = list.id
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color(.secondarySystemBackground))

                Divider()

                // Symbol grid — 2 rows of 5
                LazyVGrid(columns: symbolColumns, spacing: 10) {
                    ForEach(ItemSymbol.allCases, id: \.self) { symbol in
                        LargeSymbolChip(symbol: symbol, isSelected: selectedSymbol == symbol) {
                            selectedSymbol = symbol
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground))

                Divider()

                // Text entry — two visible rows
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: selectedSymbol.systemImageName)
                        .foregroundStyle(selectedSymbol.color)
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 26, height: 26)
                        .padding(.top, 2)
                        .animation(.easeInOut(duration: 0.15), value: selectedSymbol)

                    TextField("What happens next?", text: $text, axis: .vertical)
                        .font(.system(.body, design: .monospaced))
                        .focused($textFocused)
                        .lineLimit(2...6)
                        .submitLabel(.done)
                        .frame(minHeight: 52, alignment: .topLeading)
                }
                .padding(16)

                Spacer()
            }
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addItem() }
                        .fontWeight(.semibold)
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                selectedListID = sortedLists.first?.id
                textFocused = true
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showingNewProject) {
            ListEditSheet()
        }
    }

    private func addItem() {
        let trimmedText = text.trimmingCharacters(in: .whitespaces)
        guard !trimmedText.isEmpty else { return }

        let targetList = lists.first { $0.id == selectedListID } ?? findOrCreateGEN()
        let item = DashItem(
            symbol: selectedSymbol,
            categoryCode: targetList.prefix,
            text: trimmedText,
            sortOrder: targetList.itemList.count
        )
        item.list = targetList
        if selectedSymbol == .leftArrow { item.delegatedAt = Date() }
        modelContext.insert(item)
        dismiss()
    }

    private func findOrCreateGEN() -> DashList {
        if let gen = lists.first(where: { $0.prefix == "GEN" }) { return gen }
        let gen = DashList(name: "General", prefix: "GEN")
        modelContext.insert(gen)
        return gen
    }
}

struct SymbolChip: View {
    let symbol: ItemSymbol
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol.systemImageName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isSelected ? .white : symbol.color)
                .frame(width: 38, height: 34)
                .background(isSelected ? symbol.color : symbol.color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

struct LargeSymbolChip: View {
    let symbol: ItemSymbol
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol.systemImageName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : symbol.color)
                Text(symbol.label)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(isSelected ? .white.opacity(0.9) : symbol.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? symbol.color : symbol.color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

struct PrefixPill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(isSelected ? Color.appAccent : Color(.tertiarySystemFill))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
