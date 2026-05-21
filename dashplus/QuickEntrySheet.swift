import SwiftUI
import SwiftData

struct QuickEntrySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DashList.prefix) private var lists: [DashList]

    @State private var selectedListID: UUID?
    @State private var text = ""
    @FocusState private var textFocused: Bool

    private var sortedLists: [DashList] {
        let gen = lists.filter { $0.prefix == "GEN" }
        let rest = lists.filter { $0.prefix != "GEN" }.sorted { $0.prefix < $1.prefix }
        return gen + rest
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {

                // List prefix pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(sortedLists) { list in
                            let label = list.prefix.isEmpty ? list.name : list.prefix
                            PrefixPill(label: label, isSelected: selectedListID == list.id) {
                                selectedListID = list.id
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .background(Color(.secondarySystemBackground))

                Divider()

                // Entry row
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "minus")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 24, height: 24)
                        .padding(.top, 3)

                    TextField("What needs to be done?", text: $text, axis: .vertical)
                        .font(.system(.body, design: .monospaced))
                        .focused($textFocused)
                        .lineLimit(1...5)
                        .submitLabel(.done)
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
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func addItem() {
        let trimmedText = text.trimmingCharacters(in: .whitespaces)
        guard !trimmedText.isEmpty else { return }

        let targetList = lists.first { $0.id == selectedListID } ?? findOrCreateGEN()
        let item = DashItem(
            symbol: .dash,
            categoryCode: targetList.prefix,
            text: trimmedText,
            sortOrder: targetList.itemList.count
        )
        item.list = targetList
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

struct PrefixPill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.tertiarySystemFill))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
