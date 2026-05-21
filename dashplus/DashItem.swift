import SwiftData
import Foundation

@Model
final class DashItem {
    var id: UUID = UUID()
    var symbolRaw: String = ItemSymbol.dash.rawValue
    var categoryCode: String = ""
    var text: String = ""
    var createdAt: Date = Date()
    var scheduledDate: Date = Date()
    var sortOrder: Int = 0
    var assignedTo: String = ""
    var waitingFor: String = ""
    var delegatedAt: Date? = nil
    var list: DashList?

    var symbol: ItemSymbol {
        get { ItemSymbol(rawValue: symbolRaw) ?? .dash }
        set { symbolRaw = newValue.rawValue }
    }

    init(symbol: ItemSymbol = .dash, categoryCode: String = "", text: String, sortOrder: Int = 0) {
        self.id = UUID()
        self.symbolRaw = symbol.rawValue
        self.categoryCode = categoryCode
        self.text = text
        self.createdAt = Date()
        self.scheduledDate = Date()
        self.sortOrder = sortOrder
        self.assignedTo = ""
        self.waitingFor = ""
    }
}
