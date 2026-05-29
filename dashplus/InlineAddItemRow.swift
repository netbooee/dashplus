import SwiftUI
import SwiftData

struct InlineAddItemRow: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.editMode) private var editMode
    @Bindable var list: DashList

    @State private var text = ""
    @State private var symbol: ItemSymbol = .dash
    @FocusState var isFocused: Bool

    var body: some View {
        if editMode?.wrappedValue.isEditing != true {
            HStack(alignment: .top, spacing: 12) {

                // Symbol picker — persists between submissions
                Menu {
                    ForEach(ItemSymbol.reviewCases, id: \.self) { s in
                        Button {
                            symbol = s
                            // Return focus to the text field after selection
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                isFocused = true
                            }
                        } label: {
                            if s == symbol {
                                Label(s.label, systemImage: s.systemImageName)
                            } else {
                                Label(s.label, systemImage: s.systemImageName)
                            }
                        }
                    }
                } label: {
                    Image(systemName: symbol.systemImageName)
                        .foregroundStyle(symbol == .dash ? AnyShapeStyle(.quaternary) : AnyShapeStyle(symbol.color))
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .padding(.top, 1)

                TextField(symbol.inlinePlaceholder, text: $text)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.primary)
                    .focused($isFocused)
                    .onSubmit { commit() }
                    .submitLabel(.done)
            }
            .padding(.vertical, 2)
        }
    }

    private func commit() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            isFocused = false
            return
        }
        let item = DashItem(
            symbol: symbol,
            categoryCode: list.prefix,
            text: trimmed,
            sortOrder: list.itemList.count
        )
        item.list = list
        modelContext.insert(item)
        text = ""
        // Keep focus and symbol so the user can keep entering the same type
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isFocused = true
        }
    }
}
