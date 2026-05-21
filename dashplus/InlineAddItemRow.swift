import SwiftUI
import SwiftData

struct InlineAddItemRow: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.editMode) private var editMode
    @Bindable var list: DashList

    @State private var text = ""
    @FocusState var isFocused: Bool

    var body: some View {
        if editMode?.wrappedValue.isEditing != true {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "minus")
                    .foregroundStyle(.quaternary)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .padding(.top, 1)

                TextField("Add item…", text: $text)
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
            symbol: .dash,
            categoryCode: list.prefix,
            text: trimmed,
            sortOrder: list.itemList.count
        )
        item.list = list
        modelContext.insert(item)
        text = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isFocused = true
        }
    }
}
