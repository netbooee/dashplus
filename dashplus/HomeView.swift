import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DashItem.scheduledDate, order: .forward) private var allItems: [DashItem]
    @Query private var lists: [DashList]
    @State private var showingQuickEntry = false
    @State private var collapsedSections: Set<Date> = []

    // MARK: - Symbol grouping definition (order matters)

    private enum HomeRow: Identifiable {
        case groupHeader(title: String, uid: String)
        case dashItem(DashItem)

        var id: String {
            switch self {
            case .groupHeader(_, let uid): return uid
            case .dashItem(let item):      return item.id.uuidString
            }
        }
    }

    private static let symbolGroups: [(title: String, symbols: [ItemSymbol])] = [
        ("Todo List",              [.dash]),
        ("Meetings Need Scheduling", [.square, .scheduledMeeting]),
        ("Delegated",              [.leftArrow]),
        ("Waiting For",            [.rightArrow]),
    ]

    // MARK: - Grouped data

    private var groupedByDay: [(date: Date, rows: [HomeRow])] {
        let calendar = Calendar.current
        let active = allItems.filter {
            $0.symbol != .plus && $0.symbol != .triangle &&
            $0.symbol != .person && $0.symbol != .someday
        }
        let byDay = Dictionary(grouping: active) { item in
            calendar.startOfDay(for: item.scheduledDate)
        }
        return byDay
            .sorted { $0.key < $1.key }
            .map { date, items in
                var rows: [HomeRow] = []
                for group in Self.symbolGroups {
                    let filtered = items
                        .filter { group.symbols.contains($0.symbol) }
                        .sorted { ($0.list?.prefix ?? "") < ($1.list?.prefix ?? "") }
                    guard !filtered.isEmpty else { continue }
                    let uid = "\(date.timeIntervalSince1970)-\(group.title)"
                    rows.append(.groupHeader(title: group.title, uid: uid))
                    rows.append(contentsOf: filtered.map { .dashItem($0) })
                }
                return (date, rows)
            }
            .filter { !$0.rows.isEmpty }
    }

    // MARK: - Date formatter

    private static let sectionFormatter: DateFormatter = {
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
                    Section {
                        if !collapsedSections.contains(day.date) {
                            ForEach(day.rows) { row in
                                switch row {
                                case .groupHeader(let title, _):
                                    Text(title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .textCase(.uppercase)
                                        .listRowSeparator(.hidden)
                                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 2, trailing: 16))
                                        .listRowBackground(Color.clear)

                                case .dashItem(let item):
                                    DashItemRow(item: item)
                                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                            if item.symbol != .plus {
                                                Button { rollToTomorrow(item) } label: {
                                                    Label("Tomorrow", systemImage: "sunrise")
                                                }
                                                .tint(.orange)

                                                Button { moveToToday(item) } label: {
                                                    Label("Today", systemImage: "arrow.uturn.left.circle")
                                                }
                                                .tint(.blue)
                                            }
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
                                Text(Self.sectionFormatter.string(from: day.date))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .textCase(nil)
                                Spacer()
                                let itemCount = day.rows.filter { if case .dashItem = $0 { return true }; return false }.count
                                if collapsedSections.contains(day.date) {
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
            .overlay {
                if groupedByDay.isEmpty {
                    ContentUnavailableView(
                        "No Items",
                        systemImage: "list.bullet",
                        description: Text("Tap + to add your first item")
                    )
                }
            }
            .sheet(isPresented: $showingQuickEntry) {
                QuickEntrySheet()
            }
            .task {
                ensureGENExists()
            }
        }
    }

    // MARK: - Actions

    private func rollToTomorrow(_ item: DashItem) {
        let cal = Calendar.current
        let base = cal.startOfDay(for: item.scheduledDate)
        item.scheduledDate = cal.date(byAdding: .day, value: 1, to: base) ?? item.scheduledDate
    }

    private func moveToToday(_ item: DashItem) {
        item.scheduledDate = Calendar.current.startOfDay(for: Date())
    }

    private func ensureGENExists() {
        guard !lists.contains(where: { $0.prefix == "GEN" }) else { return }
        modelContext.insert(DashList(name: "General", prefix: "GEN"))
    }
}
