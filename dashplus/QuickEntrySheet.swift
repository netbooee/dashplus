import SwiftUI
import SwiftData

// MARK: - QuickEntrySheet

struct QuickEntrySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DashList.prefix) private var lists: [DashList]

    @State private var selectedListID: UUID?
    @State private var selection = SymbolSelection()
    @State private var text = ""
    @State private var showingNewProject = false
    @FocusState private var textFocused: Bool

    private let symbolColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    private var sortedLists: [DashList] {
        let gen  = lists.filter { $0.prefix == "GEN" }
        let rest = lists.filter { $0.prefix != "GEN" }.sorted { $0.prefix < $1.prefix }
        return gen + rest
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
                        Button { showingNewProject = true } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.appAccent)
                                .frame(width: 40, height: 36)
                                .background(Color.appAccent.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10)
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
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                }

                // MARK: Symbol — inline grid + conditional fields
                Section("Symbol") {
                    symbolGrid
                    symbolExtraFields
                }

                // MARK: Item text
                Section("Item") {
                    TextField("What happens next?", text: $text, axis: .vertical)
                        .font(.system(.body, design: .monospaced))
                        .focused($textFocused)
                        .lineLimit(2...8)
                }
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
            .sheet(isPresented: $showingNewProject) {
                ListEditSheet()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
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
        let targetList = lists.first { $0.id == selectedListID } ?? findOrCreateGEN()
        let item = DashItem(symbol: selection.symbol, categoryCode: targetList.prefix,
                            text: trimmed, sortOrder: targetList.itemList.count)
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

// MARK: - FlowLayout (wraps items into rows like text)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds.width, subviews: subviews)
        for (i, origin) in result.origins.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                              proposal: .unspecified)
        }
    }

    private func layout(in width: CGFloat, subviews: Subviews) -> (origins: [CGPoint], size: CGSize) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for subview in subviews {
            let sz = subview.sizeThatFits(.unspecified)
            if x + sz.width > width, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            origins.append(CGPoint(x: x, y: y))
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
        return (origins, CGSize(width: width, height: y + rowH))
    }
}

// MARK: - Shared chip / pill components

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
