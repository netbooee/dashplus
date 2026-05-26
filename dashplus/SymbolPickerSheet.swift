import SwiftUI
import SwiftData

struct SymbolSelection {
    var symbol: ItemSymbol
    var assignedTo: String
    var waitingFor: String
    var scheduledDate: Date   // meeting date for .scheduledMeeting / .square
    var startDate: Date?      // nil = today; non-nil moves item to that day
    var dueDate: Date?        // nil = no due date; informational only

    init(
        symbol: ItemSymbol = .dash,
        assignedTo: String = "",
        waitingFor: String = "",
        scheduledDate: Date = Date(),
        startDate: Date? = nil,
        dueDate: Date? = nil
    ) {
        self.symbol = symbol
        self.assignedTo = assignedTo
        self.waitingFor = waitingFor
        self.scheduledDate = scheduledDate
        self.startDate = startDate
        self.dueDate = dueDate
    }
}

struct SymbolPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DashList.prefix) private var allLists: [DashList]

    let onConfirm: (SymbolSelection) -> Void
    let onMoveToList: ((DashList) -> Void)?
    let currentListID: UUID?

    @State private var selection: SymbolSelection
    @State private var localListID: UUID?
    @State private var showingListPicker = false
    @FocusState private var extraFieldFocused: Bool

    private let columns = [GridItem(.adaptive(minimum: 60), spacing: 8)]

    init(
        current: SymbolSelection,
        currentListID: UUID? = nil,
        onMoveToList: ((DashList) -> Void)? = nil,
        onConfirm: @escaping (SymbolSelection) -> Void
    ) {
        _selection = State(initialValue: current)
        _localListID = State(initialValue: currentListID)
        self.currentListID = currentListID
        self.onMoveToList = onMoveToList
        self.onConfirm = onConfirm
    }

    /// Symbols whose extra fields need a Done button (don't auto-dismiss on tap).
    private func needsFollowOn(_ sym: ItemSymbol) -> Bool {
        sym == .leftArrow || sym == .rightArrow || sym == .scheduledMeeting
            || supportsScheduling(sym)
    }

    /// Task symbols that support optional start / due dates.
    private func supportsScheduling(_ sym: ItemSymbol) -> Bool {
        sym == .dash || sym == .triangle
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {

                    // Symbol grid
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(ItemSymbol.allCases, id: \.self) { symbol in
                            Button {
                                if symbol == .circle && onMoveToList != nil {
                                    showingListPicker = true
                                } else if needsFollowOn(symbol) {
                                    selection.symbol = symbol
                                } else {
                                    var result = selection
                                    result.symbol = symbol
                                    onConfirm(result)
                                    dismiss()
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: symbol.systemImageName)
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(symbol.color)
                                        .frame(width: 40, height: 40)
                                        .background(symbol.color.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(
                                                    selection.symbol == symbol ? symbol.color : .clear,
                                                    lineWidth: 2
                                                )
                                        )
                                    Text(symbol.label)
                                        .font(.system(size: 9, weight: .regular))
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .frame(width: 56)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)

                    // Project picker (only shown when onMoveToList is wired up)
                    if onMoveToList != nil {
                        projectPickerRow
                    }

                    // Conditional extra fields
                    switch selection.symbol {
                    case .leftArrow:
                        VStack(spacing: 12) {
                            extraTextField(
                                icon: "person",
                                placeholder: "Delegate to…",
                                text: $selection.assignedTo
                            )
                            dateRows()
                        }
                    case .rightArrow:
                        VStack(spacing: 12) {
                            extraTextField(
                                icon: "arrow.right",
                                placeholder: "Waiting for…",
                                text: $selection.waitingFor
                            )
                            dateRows()
                        }
                    case .scheduledMeeting:
                        HStack(spacing: 12) {
                            Image(systemName: "calendar")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text("Meeting Date")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Spacer()
                            DatePicker(
                                "",
                                selection: $selection.scheduledDate,
                                displayedComponents: [.date]
                            )
                            .labelsHidden()
                            .datePickerStyle(.compact)
                        }
                        .padding(14)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    default:
                        if supportsScheduling(selection.symbol) {
                            dateRows()
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Change Symbol")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if needsFollowOn(selection.symbol) {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            onConfirm(selection)
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .navigationDestination(isPresented: $showingListPicker) {
                MoveToListView(currentListID: currentListID) { list in
                    onMoveToList?(list)
                    dismiss()
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Project picker

    private var sortedLists: [DashList] {
        let gen  = allLists.filter { $0.prefix == "GEN" }
        let rest = allLists.filter { $0.prefix != "GEN" }.sorted { $0.prefix < $1.prefix }
        return gen + rest
    }

    private var currentListLabel: String {
        if let list = allLists.first(where: { $0.id == localListID }) {
            return list.prefix.isEmpty ? list.name : list.prefix
        }
        return "Project"
    }

    @ViewBuilder
    private var projectPickerRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder")
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text("Project")
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            Menu {
                ForEach(sortedLists) { list in
                    Button {
                        localListID = list.id
                        onMoveToList?(list)
                    } label: {
                        if list.id == localListID {
                            Label(list.name, systemImage: "checkmark")
                        } else {
                            Text(list.name)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(currentListLabel)
                        .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.appAccent.opacity(0.12))
                .foregroundStyle(Color.appAccent)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Date helpers

    private static var tomorrow: Date {
        Calendar.current.date(byAdding: .day, value: 1,
                              to: Calendar.current.startOfDay(for: Date())) ?? Date()
    }
    private static var nextWeek: Date {
        Calendar.current.date(byAdding: .day, value: 7,
                              to: Calendar.current.startOfDay(for: Date())) ?? Date()
    }

    @ViewBuilder
    private func dateRows() -> some View {
        VStack(spacing: 8) {
            optionalDateRow(
                label: "Start Date",
                icon: "calendar",
                date: $selection.startDate,
                defaultDate: Self.tomorrow
            )
            optionalDateRow(
                label: "Due Date",
                icon: "calendar.badge.exclamationmark",
                date: $selection.dueDate,
                defaultDate: Self.nextWeek
            )
        }
    }

    @ViewBuilder
    private func optionalDateRow(
        label: String, icon: String,
        date: Binding<Date?>, defaultDate: Date
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            if date.wrappedValue != nil {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { date.wrappedValue ?? defaultDate },
                        set: { date.wrappedValue = $0 }
                    ),
                    displayedComponents: [.date]
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                Button {
                    date.wrappedValue = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.quaternary)
                        .font(.title3)
                }
            } else {
                Button("Add") {
                    date.wrappedValue = defaultDate
                }
                .font(.subheadline)
                .foregroundStyle(Color.appAccent)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Text field helper

    @ViewBuilder
    private func extraTextField(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            TextField(placeholder, text: text)
                .focused($extraFieldFocused)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .onAppear { extraFieldFocused = true }
    }
}

struct MoveToListView: View {
    @Query(sort: \DashList.prefix) private var lists: [DashList]
    let currentListID: UUID?
    let onSelect: (DashList) -> Void

    private var availableLists: [DashList] {
        lists.filter { $0.id != currentListID }
    }

    var body: some View {
        List {
            ForEach(availableLists) { list in
                Button {
                    onSelect(list)
                } label: {
                    HStack(spacing: 10) {
                        if !list.prefix.isEmpty {
                            Text(list.prefix)
                                .font(.system(.caption, design: .monospaced, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.secondary.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        Text(list.name)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)
            }
        }
        .navigationTitle("Move to List")
        .navigationBarTitleDisplayMode(.inline)
    }
}
