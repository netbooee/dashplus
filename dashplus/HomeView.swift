import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DashItem.scheduledDate, order: .forward) private var allItems: [DashItem]
    @Query private var lists: [DashList]
    @State private var showingQuickEntry = false
    @State private var collapsedSections: Set<Date> = []

    private var groupedByDay: [(Date, [DashItem])] {
        let calendar = Calendar.current
        let active = allItems.filter { $0.symbol != .plus && $0.symbol != .triangle && $0.symbol != .person }
        let groups = Dictionary(grouping: active) { item in
            calendar.startOfDay(for: item.scheduledDate)
        }
        return groups
            .sorted { $0.key < $1.key }
            .map { date, items in
                let sorted = items.sorted {
                    ($0.list?.prefix ?? "") < ($1.list?.prefix ?? "")
                }
                return (date, sorted)
            }
    }

    private static let sectionFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .full
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedByDay, id: \.0) { date, items in
                    Section {
                        if !collapsedSections.contains(date) {
                            ForEach(items) { item in
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
                    } header: {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if collapsedSections.contains(date) {
                                    collapsedSections.remove(date)
                                } else {
                                    collapsedSections.insert(date)
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: collapsedSections.contains(date) ? "chevron.right" : "chevron.down")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Text(Self.sectionFormatter.string(from: date))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .textCase(nil)
                                Spacer()
                                if collapsedSections.contains(date) {
                                    Text("\(items.count)")
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
