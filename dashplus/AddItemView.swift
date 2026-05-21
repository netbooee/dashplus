import SwiftUI
import SwiftData

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let list: DashList

    @State private var selection = SymbolSelection()
    @State private var text = ""
    @State private var showingSymbolPicker = false
    @FocusState private var textFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Symbol") {
                    Button {
                        showingSymbolPicker = true
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: selection.symbol.systemImageName)
                                .foregroundStyle(selection.symbol.color)
                                .font(.system(size: 22, weight: .medium))
                                .frame(width: 36, height: 36)
                                .background(selection.symbol.color.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(selection.symbol.label)
                                    .foregroundStyle(.primary)
                                extraDetail
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                }

                Section {
                    HStack(spacing: 4) {
                        if !list.prefix.isEmpty {
                            Text(list.prefix + ":")
                                .font(.system(.body, design: .monospaced, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        TextField("Description", text: $text)
                            .font(.system(.body, design: .monospaced))
                            .focused($textFocused)
                    }
                } header: {
                    Text("Item")
                }
            }
            .navigationTitle("New Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addItem() }
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { textFocused = true }
            .sheet(isPresented: $showingSymbolPicker) {
                SymbolPickerSheet(current: selection) { result in
                    selection = result
                }
            }
        }
    }

    @ViewBuilder
    private var extraDetail: some View {
        switch selection.symbol {
        case .leftArrow where !selection.assignedTo.isEmpty:
            Text("@\(selection.assignedTo)")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .rightArrow where !selection.waitingFor.isEmpty:
            Text("→\(selection.waitingFor)")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .scheduledMeeting:
            Text(selection.scheduledDate.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.secondary)
        default:
            Text("Tap to change")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func addItem() {
        let trimmedText = text.trimmingCharacters(in: .whitespaces)
        guard !trimmedText.isEmpty else { return }
        let item = DashItem(
            symbol: selection.symbol,
            categoryCode: list.prefix,
            text: trimmedText,
            sortOrder: list.itemList.count
        )
        item.assignedTo = selection.assignedTo
        item.waitingFor = selection.waitingFor
        item.scheduledDate = selection.symbol == .scheduledMeeting ? selection.scheduledDate : Date()
        item.delegatedAt = selection.symbol == .leftArrow ? Date() : nil
        item.list = list
        modelContext.insert(item)
        dismiss()
    }
}
