import SwiftUI

struct SymbolSelection {
    var symbol: ItemSymbol
    var assignedTo: String
    var waitingFor: String
    var scheduledDate: Date

    init(
        symbol: ItemSymbol = .dash,
        assignedTo: String = "",
        waitingFor: String = "",
        scheduledDate: Date = Date()
    ) {
        self.symbol = symbol
        self.assignedTo = assignedTo
        self.waitingFor = waitingFor
        self.scheduledDate = scheduledDate
    }
}

struct SymbolPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onConfirm: (SymbolSelection) -> Void
    let onMoveToList: ((DashList) -> Void)?
    let currentListID: UUID?

    @State private var selection: SymbolSelection
    @State private var showingListPicker = false
    @FocusState private var extraFieldFocused: Bool

    private let columns = [GridItem(.adaptive(minimum: 80), spacing: 12)]

    init(
        current: SymbolSelection,
        currentListID: UUID? = nil,
        onMoveToList: ((DashList) -> Void)? = nil,
        onConfirm: @escaping (SymbolSelection) -> Void
    ) {
        _selection = State(initialValue: current)
        self.currentListID = currentListID
        self.onMoveToList = onMoveToList
        self.onConfirm = onConfirm
    }

    private func needsFollowOn(_ sym: ItemSymbol) -> Bool {
        sym == .leftArrow || sym == .rightArrow || sym == .scheduledMeeting
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Symbol grid
                    LazyVGrid(columns: columns, spacing: 12) {
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
                                VStack(spacing: 8) {
                                    Image(systemName: symbol.systemImageName)
                                        .font(.system(size: 26, weight: .medium))
                                        .foregroundStyle(symbol.color)
                                        .frame(width: 54, height: 54)
                                        .background(symbol.color.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    selection.symbol == symbol ? symbol.color : .clear,
                                                    lineWidth: 2
                                                )
                                        )
                                    Text(symbol.label)
                                        .font(.caption2)
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .frame(width: 70)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)

                    // Conditional extra fields
                    switch selection.symbol {
                    case .leftArrow:
                        extraTextField(
                            icon: "person",
                            placeholder: "Delegate to…",
                            text: $selection.assignedTo
                        )
                    case .rightArrow:
                        extraTextField(
                            icon: "arrow.right",
                            placeholder: "Waiting for…",
                            text: $selection.waitingFor
                        )
                    case .scheduledMeeting:
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Meeting Date", systemImage: "calendar")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                            DatePicker(
                                "",
                                selection: $selection.scheduledDate,
                                displayedComponents: [.date]
                            )
                            .datePickerStyle(.graphical)
                            .padding(.horizontal)
                        }
                    default:
                        EmptyView()
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
