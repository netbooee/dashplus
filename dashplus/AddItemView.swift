import SwiftUI
import SwiftData

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DashList.prefix) private var allLists: [DashList]

    // Initial list passed from caller — used to pre-select
    private let initialListID: UUID

    @State private var selectedListID: UUID
    @State private var selection = SymbolSelection()
    @State private var text = ""
    @FocusState private var textFocused: Bool

    private let symbolColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    init(list: DashList) {
        self.initialListID = list.id
        _selectedListID = State(initialValue: list.id)
    }

    private var sortedLists: [DashList] {
        let gen  = allLists.filter { $0.prefix == "GEN" }
        let rest = allLists.filter { $0.prefix != "GEN" }.sorted { $0.prefix < $1.prefix }
        return gen + rest
    }

    private var selectedList: DashList? {
        allLists.first { $0.id == selectedListID }
    }

    private var tomorrow: Date {
        Calendar.current.date(byAdding: .day, value: 1,
                              to: Calendar.current.startOfDay(for: Date())) ?? Date()
    }
    private var nextWeek: Date {
        Calendar.current.date(byAdding: .day, value: 7,
                              to: Calendar.current.startOfDay(for: Date())) ?? Date()
    }

    var body: some View {
        NavigationStack {
            Form {

                // MARK: Project — wrapping pills
                Section("Project") {
                    FlowLayout(spacing: 8) {
                        ForEach(sortedLists) { list in
                            let label = list.prefix.isEmpty ? list.name : list.prefix
                            PrefixPill(label: label, isSelected: selectedListID == list.id) {
                                selectedListID = list.id
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                }

                // MARK: Symbol — inline grid + conditional fields
                Section("Symbol") {
                    symbolGrid
                    symbolExtraFields
                }

                // MARK: Item text
                Section("Item") {
                    TextField("Description", text: $text, axis: .vertical)
                        .font(.system(.body, design: .monospaced))
                        .focused($textFocused)
                        .lineLimit(2...8)
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
                        .fontWeight(.semibold)
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { textFocused = true }
        }
    }

    // MARK: Symbol grid

    private var symbolGrid: some View {
        let symbols = ItemSymbol.allCases.filter { $0 != .circle }
        return LazyVGrid(columns: symbolColumns, spacing: 8) {
            ForEach(symbols, id: \.self) { sym in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { selection.symbol = sym }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: sym.systemImageName)
                            .font(.system(size: 18, weight: .medium))
                        Text(sym.label)
                            .font(.system(size: 8, weight: .medium))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(selection.symbol == sym ? .white : sym.color)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selection.symbol == sym ? sym.color : sym.color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
    }

    // MARK: Symbol-conditional extra fields

    @ViewBuilder
    private var symbolExtraFields: some View {
        if selection.symbol == .leftArrow {
            HStack(spacing: 12) {
                Image(systemName: "person").foregroundStyle(.secondary).frame(width: 20)
                TextField("Delegate to…", text: $selection.assignedTo)
            }
        }
        if selection.symbol == .rightArrow {
            HStack(spacing: 12) {
                Image(systemName: "arrow.right").foregroundStyle(.secondary).frame(width: 20)
                TextField("Waiting for…", text: $selection.waitingFor)
            }
        }
        if selection.symbol == .scheduledMeeting {
            HStack {
                Image(systemName: "calendar").foregroundStyle(.secondary).frame(width: 20)
                Text("Meeting Date")
                Spacer()
                DatePicker("", selection: $selection.scheduledDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
            }
        }
        if selection.symbol.supportsDateScheduling {
            optionalDateRow(label: "Start Date", icon: "calendar",
                            date: $selection.startDate, defaultDate: tomorrow)
            optionalDateRow(label: "Due Date", icon: "calendar.badge.exclamationmark",
                            date: $selection.dueDate, defaultDate: nextWeek)
        }
    }

    @ViewBuilder
    private func optionalDateRow(label: String, icon: String,
                                  date: Binding<Date?>, defaultDate: Date) -> some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            if date.wrappedValue != nil {
                DatePicker("", selection: Binding(
                    get: { date.wrappedValue ?? defaultDate },
                    set: { date.wrappedValue = $0 }
                ), displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                Button { date.wrappedValue = nil } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.quaternary)
                }
            } else {
                Button("Add") { date.wrappedValue = defaultDate }
                    .foregroundStyle(Color.appAccent)
            }
        }
    }

    // MARK: Save

    private func addItem() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let list = selectedList ?? allLists.first { $0.prefix == "GEN" } ?? {
            let gen = DashList(name: "General", prefix: "GEN")
            modelContext.insert(gen)
            return gen
        }()
        let item = DashItem(symbol: selection.symbol, categoryCode: list.prefix,
                            text: trimmed, sortOrder: list.itemList.count)
        item.assignedTo = selection.assignedTo
        item.waitingFor = selection.waitingFor
        item.dueDate    = selection.dueDate
        if selection.symbol == .scheduledMeeting || selection.symbol == .square {
            item.scheduledDate = selection.scheduledDate
        } else {
            item.scheduledDate = selection.startDate.map {
                Calendar.current.startOfDay(for: $0)
            } ?? Calendar.current.startOfDay(for: Date())
        }
        item.delegatedAt = selection.symbol == .leftArrow ? Date() : nil
        item.list = list
        modelContext.insert(item)
        dismiss()
    }
}
