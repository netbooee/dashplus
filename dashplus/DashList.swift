import SwiftData
import Foundation

@Model
final class DashList {
    var id: UUID = UUID()
    var name: String = ""
    var prefix: String = ""
    var createdAt: Date = Date()
    @Relationship(deleteRule: .cascade, inverse: \DashItem.list)
    var items: [DashItem]?

    var itemList: [DashItem] { items ?? [] }

    init(name: String, prefix: String = "") {
        self.id = UUID()
        self.name = name
        self.prefix = prefix.uppercased()
        self.createdAt = Date()
        self.items = []
    }
}
