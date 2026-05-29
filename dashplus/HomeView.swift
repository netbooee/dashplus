import SwiftUI
import SwiftData
import TipKit

// MARK: - App palette

extension Color {
    /// Terracotta accent — slightly brighter in dark mode for contrast.
    static let appAccent = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.87, green: 0.52, blue: 0.32, alpha: 1) // lighter terracotta
            : UIColor(red: 0.76, green: 0.34, blue: 0.20, alpha: 1) // original terracotta
    })
    /// Warm cream in light mode; standard iOS grouped background in dark mode.
    static let warmBg = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? .systemGroupedBackground
            : UIColor(red: 0.96, green: 0.93, blue: 0.89, alpha: 1)
    })
}

// MARK: - Supporting types

fileprivate struct DaySection: Identifiable {
    let date: Date
    let rows: [HomeDayRow]
    var id: Date { date }
}

fileprivate enum HomeDayRow: Identifiable {
    case groupHeader(title: String, symbol: ItemSymbol, count: Int, uid: String)
    case dashItem(DashItem, isOverdue: Bool)

    var id: String {
        switch self {
        case .groupHeader(_, _, _, let uid): return uid
        case .dashItem(let item, _):         return item.id.uuidString
        }
    }
}

fileprivate struct HomeDayRowView: View {
    let row: HomeDayRow
    var isCollapsed: Bool = false
    var onToggle: (() -> Void)? = nil
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        switch row {
        case .groupHeader(let title, let symbol, let count, _):
            Button { onToggle?() } label: {
                HStack(spacing: 8) {
                    Image(systemName: symbol.systemImageName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(symbol.color)
                        .frame(width: 16)
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(symbol.color)
                        .textCase(.uppercase)
                    Spacer()
                    Text(isCollapsed ? "\(count) hidden" : "\(count)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(symbol.color)
                        .monospacedDigit()
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(symbol.color.opacity(0.7))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            .listRowBackground(symbol.color.opacity(0.12))

        case .dashItem(let item, let isOverdue):
            DashItemRow(item: item, isOverdue: isOverdue)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        modelContext.delete(item)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button(role: .destructive) {
                        modelContext.delete(item)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
        }
    }
}

// MARK: - HomeView

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DashItem.scheduledDate, order: .forward) private var allItems: [DashItem]
    @Query private var lists: [DashList]
    @State private var showingQuickEntry = false
    @State private var showingNoteProcessor = false
    @State private var showingSettings = false
    @State private var collapsedSections: Set<Date> = []
    /// Group UIDs that are expanded. Anything not in this set is collapsed.
    @State private var expandedGroups: Set<String> = []
    @State private var hasInitializedGroups = false

    private let deleteItemTip = DeleteItemTip()

    // MARK: Symbol groups (order matters)

    private static let symbolGroups: [(title: String, symbols: [ItemSymbol])] = [
        ("To Do",                    [.dash]),
        ("Meetings Need Scheduling", [.square]),
        ("Meetings Scheduled",       [.scheduledMeeting]),
        ("Delegated",                [.leftArrow]),
        ("Waiting For",              [.rightArrow]),
    ]

    // MARK: Computed data

    private var todayStart: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var groupedDays: [DaySection] {
        let calendar = Calendar.current
        let today = todayStart
        let active = allItems.filter {
            $0.symbol != .plus && $0.symbol != .triangle &&
            $0.symbol != .person && $0.symbol != .someday
        }
        let todaySection = DaySection(
            date: today,
            rows: makeRows(from: active.filter { calendar.startOfDay(for: $0.scheduledDate) <= today },
                           sectionDate: today, todayStart: today)
        )
        let futureItems = active.filter { calendar.startOfDay(for: $0.scheduledDate) > today }
        let futureSections = Dictionary(grouping: futureItems) { calendar.startOfDay(for: $0.scheduledDate) }
            .sorted { $0.key < $1.key }
            .map { date, items in
                DaySection(date: date, rows: makeRows(from: items, sectionDate: date, todayStart: today))
            }
        return [todaySection] + futureSections
    }

    private func makeRows(from items: [DashItem], sectionDate: Date, todayStart: Date) -> [HomeDayRow] {
        let calendar = Calendar.current
        var rows: [HomeDayRow] = []
        for group in Self.symbolGroups {
            let filtered = items
                .filter { group.symbols.contains($0.symbol) }
                .sorted { ($0.list?.prefix ?? "") < ($1.list?.prefix ?? "") }
            guard !filtered.isEmpty else { continue }
            let uid = "\(Int(sectionDate.timeIntervalSince1970))-\(group.title)"
            rows.append(.groupHeader(title: group.title, symbol: group.symbols.first!,
                                     count: filtered.count, uid: uid))
            for item in filtered {
                // Overdue only when an explicit start or due date was set and has passed
                let startDateOverdue = item.startDate.map { calendar.startOfDay(for: $0) < todayStart } ?? false
                let dueDateOverdue   = item.dueDate.map { calendar.startOfDay(for: $0) < todayStart } ?? false
                rows.append(.dashItem(item, isOverdue: startDateOverdue || dueDateOverdue))
            }
        }
        return rows
    }

    // MARK: Tip helpers

    /// ID of the first visible dashItem row — used to anchor the delete tip.
    private var firstDashItemID: String? {
        for day in groupedDays {
            for row in visibleRows(for: day) {
                if case .dashItem = row { return row.id }
            }
        }
        return nil
    }

    /// Wraps HomeDayRowView, passing collapse state for headers and anchoring the tip.
    @ViewBuilder
    private func itemRowView(row: HomeDayRow) -> some View {
        if case .groupHeader(_, _, _, let uid) = row {
            HomeDayRowView(
                row: row,
                isCollapsed: !expandedGroups.contains(uid),
                onToggle: { toggleGroup(uid) }
            )
        } else if row.id == firstDashItemID {
            HomeDayRowView(row: row)
                .popoverTip(deleteItemTip, arrowEdge: .bottom)
        } else {
            HomeDayRowView(row: row)
        }
    }

    // MARK: Formatters

    private static let fullDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .full; f.timeStyle = .none; return f
    }()
    private static let dayAbbrevFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f
    }()
    private static let dayNumberFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d"; return f
    }()

    // MARK: Body

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedDays) { day in
                    let isToday = day.date == todayStart
                    Section {
                        if !collapsedSections.contains(day.date) {
                            if day.rows.isEmpty {
                                Text("No items for today")
                                    .font(.subheadline)
                                    .foregroundStyle(.tertiary)
                                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                            } else {
                                ForEach(visibleRows(for: day)) { row in
                                    itemRowView(row: row)
                                }
                            }
                        }
                    } header: {
                        // The Today section header embeds the day picker strip so
                        // it stays sticky while scrolling through today's items.
                        // Future date headers are just the collapse toggle.
                        if isToday {
                            VStack(spacing: 0) {
                                dayPickerStrip(days: groupedDays)
                                    .padding(.bottom, 4)
                                sectionHeader(day: day, isToday: true)
                            }
                        } else {
                            sectionHeader(day: day, isToday: false)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.warmBg)
            .navigationTitle("HappensNext")
            .navigationBarTitleDisplayMode(.large)
            .overlay(alignment: .bottomTrailing) {
                Button { showingQuickEntry = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 56))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.appAccent)
                        .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                }
                .padding(20)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingNoteProcessor = true } label: {
                        Image(systemName: "mic.circle")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.appAccent)
                    }
                }
            }
            .sheet(isPresented: $showingQuickEntry) {
                QuickEntrySheet()
            }
            .sheet(isPresented: $showingNoteProcessor) {
                NoteProcessorSheet()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .task {
                ensureGENExists()
                initExpandedGroups()
            }
        }
    }

    // MARK: Section header

    @ViewBuilder
    private func sectionHeader(day: DaySection, isToday: Bool) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if collapsedSections.contains(day.date) {
                    collapsedSections.remove(day.date)
                } else {
                    collapsedSections.insert(day.date)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: collapsedSections.contains(day.date) ? "chevron.right" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(isToday ? "Today" : Self.fullDateFormatter.string(from: day.date))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isToday ? Color.appAccent : .primary)
                    .textCase(nil)
                Spacer()
                if collapsedSections.contains(day.date) {
                    let count = day.rows.filter { if case .dashItem = $0 { return true }; return false }.count
                    Text("\(count)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Day picker strip
    // Tapping a chip collapses all other sections, focusing that day.

    private func dayPickerStrip(days: [DaySection]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(days) { day in
                    let isToday = day.date == todayStart
                    let hasItems = !day.rows.isEmpty
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            // Collapse every section except the tapped one
                            let allDates = Set(groupedDays.map(\.date))
                            collapsedSections = allDates.subtracting([day.date])
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Text(Self.dayAbbrevFormatter.string(from: day.date).uppercased())
                                .font(.system(size: 10, weight: .semibold))
                            Text(Self.dayNumberFormatter.string(from: day.date))
                                .font(.system(size: 20, weight: .bold))
                            Circle()
                                .fill(isToday ? Color.white : Color.appAccent)
                                .frame(width: 4, height: 4)
                                .opacity(hasItems ? 1 : 0)
                        }
                        .foregroundStyle(isToday ? Color.white : Color.primary)
                        .frame(width: 52)
                        .padding(.vertical, 8)
                        .background(isToday ? Color.appAccent : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    // MARK: Group collapse helpers

    /// Called once per session — pre-expands only today's To Do group.
    private func initExpandedGroups() {
        guard !hasInitializedGroups else { return }
        hasInitializedGroups = true
        let ts = Int(todayStart.timeIntervalSince1970)
        expandedGroups.insert("\(ts)-To Do")
    }

    private func toggleGroup(_ uid: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedGroups.contains(uid) {
                expandedGroups.remove(uid)
            } else {
                expandedGroups.insert(uid)
            }
        }
    }

    /// Returns only the rows that should be visible given the current expanded state.
    /// Group headers are always included; their items are hidden when the group is collapsed.
    private func visibleRows(for day: DaySection) -> [HomeDayRow] {
        var result: [HomeDayRow] = []
        var currentGroupExpanded = true
        for row in day.rows {
            switch row {
            case .groupHeader(_, _, _, let uid):
                currentGroupExpanded = expandedGroups.contains(uid)
                result.append(row)
            case .dashItem:
                if currentGroupExpanded { result.append(row) }
            }
        }
        return result
    }

    // MARK: Helpers

    private func ensureGENExists() {
        guard !lists.contains(where: { $0.prefix == "GEN" }) else { return }
        modelContext.insert(DashList(name: "General", prefix: "GEN"))
    }
}
