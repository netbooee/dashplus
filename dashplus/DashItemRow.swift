import SwiftUI

struct DashItemRow: View {
    @Bindable var item: DashItem
    var isCompact: Bool = false
    var showPrefix: Bool = true
    var showDate: Bool = false
    var isOverdue: Bool = false
    @Environment(\.editMode) private var editMode
    @State private var showingSymbolPicker = false
    @State private var isEditing = false
    @State private var editText = ""
    @FocusState private var editFocused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: isCompact ? 6 : 8) {
            // Symbol button
            Button { showingSymbolPicker = true } label: {
                Image(systemName: item.symbol.systemImageName)
                    .foregroundStyle(item.symbol.color)
                    .font(.system(size: isCompact ? 11 : 14, weight: .semibold))
                    .frame(width: isCompact ? 14 : 20, height: isCompact ? 14 : 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 1)

            VStack(alignment: .leading, spacing: 1) {
                if isEditing {
                    HStack(alignment: .center, spacing: 6) {
                        if !listPrefix.isEmpty {
                            PrefixChip(prefix: listPrefix)
                        }
                        TextField("", text: $editText)
                            .font(isCompact
                                ? .system(.caption, design: .monospaced)
                                : .system(.subheadline, design: .monospaced))
                            .focused($editFocused)
                            .onSubmit { commitEdit() }
                            .onAppear { editFocused = true }
                            .onChange(of: editFocused) { _, focused in
                                if !focused { commitEdit() }
                            }
                    }
                } else {
                    HStack(alignment: .top, spacing: 6) {
                        if !listPrefix.isEmpty {
                            PrefixChip(prefix: listPrefix)
                                .padding(.top, isCompact ? 1 : 2)
                        }
                        Text(item.text)
                            .font(isCompact
                                ? .system(.caption, design: .monospaced)
                                : .system(.subheadline, design: .monospaced))
                            .fixedSize(horizontal: false, vertical: true)
                            .foregroundStyle(
                                item.symbol == .plus ? Color.secondary :
                                isOverdue             ? Color.red       : Color.primary
                            )
                            .onTapGesture {
                                guard editMode?.wrappedValue != .active else { return }
                                editText = item.text
                                isEditing = true
                            }
                    }
                }

                if let annotation {
                    HStack(alignment: .top, spacing: 6) {
                        if !listPrefix.isEmpty {
                            PrefixChip(prefix: listPrefix)
                                .hidden()
                        }
                        Text(annotation)
                            .font(isCompact
                                ? .system(.caption2, design: .monospaced)
                                : .system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 0)
        .listRowInsets(EdgeInsets(top: isCompact ? 3 : 6, leading: 16, bottom: isCompact ? 3 : 6, trailing: 16))
        .sheet(isPresented: $showingSymbolPicker) {
            SymbolPickerSheet(
                current: SymbolSelection(
                    symbol: item.symbol,
                    assignedTo: item.assignedTo,
                    waitingFor: item.waitingFor,
                    scheduledDate: item.scheduledDate,
                    startDate: item.startDate,
                    dueDate: item.dueDate
                ),
                currentListID: item.list?.id,
                onMoveToList: { list in item.list = list }
            ) { result in
                let wasLeftArrow = item.symbol == .leftArrow
                item.symbol     = result.symbol
                item.assignedTo = result.assignedTo
                item.waitingFor = result.waitingFor
                item.startDate  = result.startDate
                item.dueDate    = result.dueDate
                // Meetings use scheduledDate directly; tasks use startDate (nil = today)
                if result.symbol == .scheduledMeeting || result.symbol == .square {
                    item.scheduledDate = result.scheduledDate
                } else {
                    item.scheduledDate = result.startDate.map {
                        Calendar.current.startOfDay(for: $0)
                    } ?? Calendar.current.startOfDay(for: Date())
                }
                if result.symbol == .leftArrow && !wasLeftArrow {
                    item.delegatedAt = Date()
                } else if result.symbol != .leftArrow {
                    item.delegatedAt = nil
                }
            }
        }
    }

    // MARK: - Helpers

    private var listPrefix: String {
        showPrefix ? (item.list?.prefix ?? "") : ""
    }

    private func commitEdit() {
        let trimmed = editText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { item.text = trimmed }
        isEditing = false
    }

    // MARK: - Annotation

    private var annotation: String? {
        switch item.symbol {
        case .leftArrow:
            let name = item.assignedTo.isEmpty ? nil : "@\(item.assignedTo)"
            let age  = item.delegatedAt.map {
                Self.relativeDateFormatter.localizedString(for: $0, relativeTo: Date())
            }
            let base: String? = {
                switch (name, age) {
                case (let n?, let a?): return "\(n) · \(a)"
                case (let n?, nil):    return n
                case (nil, let a?):    return a
                default:               return nil
                }
            }()
            return combine(base ?? dateContext, dueDateString)

        case .rightArrow where !item.waitingFor.isEmpty:
            return combine("→\(item.waitingFor)", dueDateString)

        case .scheduledMeeting:
            // Meeting date is authoritative; no start/due overlay
            return Self.meetingDateFormatter.string(from: item.scheduledDate)

        default:
            return combine(dateContext, dueDateString)
        }
    }

    /// Combines two optional strings with " · " separator.
    private func combine(_ a: String?, _ b: String?) -> String? {
        switch (a, b) {
        case (let x?, let y?): return "\(x) · \(y)"
        case (let x?, nil):    return x
        case (nil, let y?):    return y
        default:               return nil
        }
    }

    /// Start-date label — only shown when an explicit start date was set.
    private var dateContext: String? {
        guard showDate, let start = item.startDate else { return nil }
        let cal = Calendar.current
        let today   = cal.startOfDay(for: Date())
        let startDay = cal.startOfDay(for: start)
        let diff    = cal.dateComponents([.day], from: today, to: startDay).day ?? 0
        let label: String
        switch diff {
        case ..<0:   label = "overdue"
        case 0:      label = "today"
        case 1:      label = "tomorrow"
        case 2...6:  label = Self.dayFormatter.string(from: start)
        default:     label = Self.shortDateFormatter.string(from: start)
        }
        return "Start \(label)"
    }

    /// Due-date label — always shown when a due date is set, regardless of `showDate`.
    private var dueDateString: String? {
        guard let due = item.dueDate else { return nil }
        let cal = Calendar.current
        let today  = cal.startOfDay(for: Date())
        let dueDay = cal.startOfDay(for: due)
        let diff   = cal.dateComponents([.day], from: today, to: dueDay).day ?? 0
        let label: String
        switch diff {
        case ..<0:   label = "overdue"
        case 0:      label = "today"
        case 1:      label = "tomorrow"
        case 2...6:  label = Self.dayFormatter.string(from: due)
        default:     label = Self.shortDateFormatter.string(from: due)
        }
        return "Due \(label)"
    }

    // MARK: - Formatters

    private static let meetingDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f
    }()

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .full; return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f
    }()

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .short; f.timeStyle = .none; return f
    }()
}
