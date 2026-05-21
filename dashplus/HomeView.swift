import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DashItem.scheduledDate, order: .forward) private var allItems: [DashItem]
    @Query private var lists: [DashList]
    @State private var showingQuickEntry = false
    @State private var collapsedSections: Set<Date> = []

    // MARK: - Row model

    private enum HomeRow: Identifiable {
        case groupHeader(title: String, uid: String)
        case dashItem(DashItem, isOverdue: Bool)

        var id: String {
            switch self {
            case .groupHeader(_, let uid): return uid
            case .dashItem(let item, _):  return item.id.uuidString
            }
        }
    }

    // MARK: - Symbol group order

    private static let symbolGroups: [(title: String, symbols: [ItemSymbol])] = [
        ("Todo List",                [.dash]),
        ("Meetings Need Scheduling", [.square]),
        ("Meetings Scheduled",       [.scheduledMeeting]),
        ("Delegated",                [.leftArrow]),
        ("Waiting For",              [.rightArrow]),
    ]

    // MARK: - Grouped data

    private var todayStart: Date {
        Calendar.current.startOfDay(for: Date())
    }

    /// Today section always first (even when empty), then future dates.
    private var groupedByDay: [(date: Date, rows: [HomeRow])] {
        let calendar = Calendar.current
        let today = todayStart

        let active = allItems.filter {
            $0.symbol != .plus && $0.symbol != .triangle &&
            $0.symbol != .person && $0.symbol != .someday
        }

        // Today bucket: everything scheduled today or earlier (overdue)
        let todayItems = active.filter { calendar.startOfDay(for: $0.scheduledDate) <= today }
        let todayRows  = makeRows(from: todayItems, todayStart: today)

        // Future buckets: one section per future date
        let futureItems = active.filter { calendar.startOfDay(for: $0.scheduledDate) > today }
        let byDay = Dictionary(grouping: futureItems) { calendar.startOfDay(for: $0.scheduledDate) }
        let futureSections = byDay
            .sorted { $0.key < $1.key }
            .map { date, items in (date: date, rows: makeRows(from: items, todayStart: today)) }

        return [(date: today, rows: todayRows)] + futureSections
    }

    private func makeRows(from items: [DashItem], todayStart: Date) -> [HomeRow] {
        let calendar = Calendar.current
        var rows: [HomeRow] = []
        for group in Self.symbolGroups {
            let filtered = items
                .filter { group.symbols.contains($0.symbol) }
                .sorted { ($0.list?.prefix ?? "") < ($1.list?.prefix ?? "") }
            guard !filtered.isEmpty else { continue }
            // uid only needs to be unique within the whole list
            let uid = "\(filtered.first!.id)-\(group.title)"
            rows.append(.groupHeader(title: group.title, uid: uid))
            for item in filtered {
                let overdue = calendar.startOfDay(for: item.scheduledDate) < todayStart
                rows.append(.dashItem(item, isOverdue: overdue))
            }
        }
        return rows
    }

    // MARK: - Formatters

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .full
        f.timeStyle = .none
        return f
    }()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedByDay, id: \.date) { day in
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
                                    switch row {
                                    case .groupHeader(let title, _):
                                        Text(title)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                            .textCase(.uppercase)
                                            .listRowSeparator(.hidden)
                                            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 2, trailing: 16))

                                    case .dashItem(let item, let isOverdue):
                                        DashItemRow(item: item, isOverdue: isOverdue)
                                    }
                                }
                            }
                        }
                    } header: {
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

                                Text(isToday ? "Today" : Self.dateFormatter.string(from: day.date))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(isToday ? .blue : .primary)
                                    .textCase(nil)

                                Spacer()

                                if collapsedSections.contains(day.date) {
                                    let itemCount = day.rows.filter {
                                        if case .dashItem = $0 { return true }
                                        return false
                                    }.count
                                    Text("\(itemCount)")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Dash Plus")
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showingQuickEntry = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 56))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .blue)
                        .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
                }
                .padding(20)
            }
            .sheet(isPresented: $showingQuickEntry) {
                QuickEntrySheet()
            }
            .task {
                ensureGENExists()
            }
        }
    }

    // MARK: - Helpers

    private func ensureGENExists() {
        guard !lists.contains(where: { $0.prefix == "GEN" }) else { return }
        modelContext.insert(DashList(name: "General", prefix: "GEN"))
    }
}
