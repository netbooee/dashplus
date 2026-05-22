import SwiftUI
import SwiftData

// MARK: - App palette

extension Color {
    static let appAccent = Color(red: 0.76, green: 0.34, blue: 0.20) // terracotta
    static let warmBg    = Color(red: 0.96, green: 0.93, blue: 0.89) // cream
}

// MARK: - Supporting types (file-scope so ForEach can infer them)

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

/// Renders a single HomeDayRow so the ForEach body stays typed and simple.
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
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text("\(count)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 2, trailing: 16))

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
            rows: makeRows(
                from: active.filter { calendar.startOfDay(for: $0.scheduledDate) <= today },
                sectionDate: today, todayStart: today
            )
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
            rows.append(.groupHeader(
                title: group.title,
                symbol: group.symbols.first!,
                count: filtered.count,
                uid: uid
            ))
            for item in filtered {
                rows.append(.dashItem(item, isOverdue: calendar.startOfDay(for: item.scheduledDate) < todayStart))
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
            ScrollViewReader { proxy in
                List {
                    ForEach(groupedDays) { day in
                        let isToday = day.date == todayStart
                        Section {
                            // Zero-height anchor — always rendered so scrollTo works
                            // even when the section is collapsed.
                            Color.clear
                                .frame(height: 0)
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                .listRowSeparator(.hidden)
                                .id("anchor-\(Int(day.date.timeIntervalSince1970))")

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
                            sectionHeader(day: day, isToday: isToday)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Color.warmBg)
                .safeAreaInset(edge: .top, spacing: 0) {
                    dayPickerStrip(days: groupedDays, proxy: proxy)
                        .background(.bar)
                }
            }
            .navigationTitle("Dash Plus")
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

    // MARK: Sub-views

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

    private func dayPickerStrip(days: [DaySection], proxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(days) { day in
                    let isToday = day.date == todayStart
                    let hasItems = !day.rows.isEmpty
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo("anchor-\(Int(day.date.timeIntervalSince1970))", anchor: .top)
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
