import SwiftUI
import SwiftData

struct ListEditSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var list: DashList?

    @State private var name: String
    @State private var prefix: String

    init(list: DashList? = nil) {
        self.list = list
        _name = State(initialValue: list?.name ?? "")
        _prefix = State(initialValue: list?.prefix ?? "")
    }

    private var isCreating: Bool { list == nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Full name (e.g. Internal Business)", text: $name)
                    HStack {
                        TextField("Prefix", text: $prefix)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.system(.body, design: .monospaced, weight: .semibold))
                            .onChange(of: prefix) { _, new in
                                let cleaned = String(new.uppercased().filter { $0.isLetter }.prefix(3))
                                if cleaned != prefix { prefix = cleaned }
                            }
                        Spacer()
                        Text("3 letters, e.g. IBS")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Project Details")
                } footer: {
                    Text("The prefix appears before every item in this project.")
                }
            }
            .navigationTitle(isCreating ? "New Project" : "Edit Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isCreating ? "Create" : "Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        if let list {
            list.name = trimmedName
            list.prefix = prefix
        } else {
            modelContext.insert(DashList(name: trimmedName, prefix: prefix))
        }
        dismiss()
    }
}
