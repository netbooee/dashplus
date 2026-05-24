import SwiftUI
import SwiftData

// MARK: - App palette

extension Color {
    static let appAccent = Color(red: 0.76, green: 0.34, blue: 0.20) // terracotta
    static let warmBg    = Color(red: 0.96, green: 0.93, blue: 0.89) // cream
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
    var body: some View {
        switch row {
        case .groupHeader(let title, let symbol, let count, _):
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
                Text("\(count)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(symbol.color)
                    .monospacedDigit()
            }
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            .listRowBackground(symbol.color.opacity(0.12))

        case .dashItem(let item, let isOverdue):
            DashItemRow(item: item, isOverdue: isOverdue)
        }
    }
}

// MARK: - HomeView

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DashItem.scheduledDate, order: .forward) private var allItems: [DashItem]
    @Query private var lists: [DashList]
    @State private var showingQuickEntry = false
    @State private var collapsedSections: Set<Date> = []

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
                                ForEach(day.rows) { row in
                                    HomeDayRowView(row: row)
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
            .sheet(isPresented: $showingQuickEntry) {
                QuickEntrySheet()
            }
            .task { ensureGENExists() }
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

    // MARK: Helpers

    private func ensureGENExists() {
        guard !lists.contains(where: { $0.prefix == "GEN" }) else { return }
        modelContext.insert(DashList(name: "General", prefix: "GEN"))
    }
}
