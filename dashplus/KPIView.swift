import SwiftUI
import SwiftData

// MARK: - KPI tile

private struct KPITile: View {
    let symbol: ItemSymbol
    let count: Int

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol.systemImageName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(symbol.color)

            Text("\(count)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(symbol.color)
                .monospacedDigit()
                .minimumScaleFactor(0.4)
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(symbol.label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(symbol.color)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .background(symbol.color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(symbol.color.opacity(0.18), lineWidth: 1)
        }
    }
}

// MARK: - Detail view (filtered list for one symbol type)

struct KPIDetailView: View {
    let symbol: ItemSymbol
    @Query private var items: [DashItem]

    init(symbol: ItemSymbol) {
        self.symbol = symbol
        let raw = symbol.rawValue
        _items = Query(
            filter: #Predicate<DashItem> { $0.symbolRaw == raw },
            sort: \DashItem.createdAt,
            order: .forward
        )
    }

    var body: some View {
        List {
            if items.isEmpty {
                Text("No items")
                    .foregroundStyle(.tertiary)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(items) { item in
                    DashItemRow(item: item, showDate: true)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.warmBg)
        .navigationTitle(symbol.label)
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - KPIView

struct KPIView: View {
    @Query private var allItems: [DashItem]

    private static let kpiSymbols: [ItemSymbol] = [
        .dash, .square, .scheduledMeeting,
        .leftArrow, .rightArrow, .triangle,
        .person, .someday, .plus,
    ]

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    private func count(for symbol: ItemSymbol) -> Int {
        allItems.filter { $0.symbol == symbol }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Self.kpiSymbols, id: \.self) { symbol in
                        NavigationLink {
                            KPIDetailView(symbol: symbol)
                        } label: {
                            KPITile(symbol: symbol, count: count(for: symbol))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(Color.warmBg)
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
