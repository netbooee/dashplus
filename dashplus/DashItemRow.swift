import SwiftUI

struct DashItemRow: View {
    @Bindable var item: DashItem
    var isCompact: Bool = false
    var showPrefix: Bool = true
    var isOverdue: Bool = false
    @Environment(\.editMode) private var editMode
    @State private var showingSymbolPicker = false
    @State private var isEditing = false
    @State private var editText = ""
    @FocusState private var editFocused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: isCompact ? 6 : 8) {
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
                    HStack(spacing: 4) {
                        if !listPrefix.isEmpty {
                            Text(listPrefix + ":")
                                .font(isCompact
                                    ? .system(.caption, design: .monospaced)
                                    : .system(.subheadline, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .fixedSize()
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
                    itemText
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

                if let annotation {
                    Text(annotation)
                        .font(isCompact
                            ? .system(.caption2, design: .monospaced)
                            : .system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
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
                    scheduledDate: item.scheduledDate
                ),
                currentListID: item.list?.id,
                onMoveToList: { list in
                    item.list = list
                }
            ) { result in
                let wasLeftArrow = item.symbol == .leftArrow
                item.symbol = result.symbol
                item.assignedTo = result.assignedTo
                item.waitingFor = result.waitingFor
                item.scheduledDate = result.scheduledDate
                if result.symbol == .leftArrow && !wasLeftArrow {
                    item.delegatedAt = Date()
                } else if result.symbol != .leftArrow {
                    item.delegatedAt = nil
                }
            }
        }
    }

    private var listPrefix: String {
        showPrefix ? (item.list?.prefix ?? "") : ""
    }

    private var itemText: Text {
        if listPrefix.isEmpty {
            return Text(item.text)
        }
        return Text(listPrefix + ": ").foregroundStyle(.secondary) + Text(item.text)
    }

    private func commitEdit() {
        let trimmed = editText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            item.text = trimmed
        }
        isEditing = false
    }

    private static let meetingDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    private var annotation: String? {
        switch item.symbol {
        case .leftArrow:
            let name = item.assignedTo.isEmpty ? nil : "@\(item.assignedTo)"
            let age = item.delegatedAt.map {
                Self.relativeDateFormatter.localizedString(for: $0, relativeTo: Date())
            }
            switch (name, age) {
            case (let n?, let a?): return "\(n) · \(a)"
            case (let n?, nil):    return n
            case (nil, let a?):    return a
            default:               return nil
            }
        case .rightArrow where !item.waitingFor.isEmpty:
            return "→\(item.waitingFor)"
        case .scheduledMeeting:
            return Self.meetingDateFormatter.string(from: item.scheduledDate)
        default:
            return nil
        }
    }
}
