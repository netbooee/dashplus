import SwiftData
import Foundation

struct SampleDataSeeder {

    /// Seeds the sample Trip Planning project exactly once.
    /// Uses the "SMPL" prefix as a sentinel — if a list with that prefix already
    /// exists the function returns immediately without touching the database.
    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<DashList>(
            predicate: #Predicate<DashList> { $0.prefix == "SMPL" }
        )
        guard let existing = try? context.fetch(descriptor), existing.isEmpty else { return }

        let list = DashList(name: "Trip Planning", prefix: "SMPL")
        context.insert(list)

        let future7 = Calendar.current.date(
            byAdding: .day, value: 7,
            to: Calendar.current.startOfDay(for: Date())
        ) ?? Date()

        var order = 0

        func add(
            _ symbol: ItemSymbol,
            _ text: String,
            assignedTo: String = "",
            waitingFor: String = "",
            scheduledDate: Date? = nil
        ) {
            let item = DashItem(
                symbol: symbol,
                categoryCode: "SMPL",
                text: text,
                sortOrder: order
            )
            item.assignedTo    = assignedTo
            item.waitingFor    = waitingFor
            if let date = scheduledDate { item.scheduledDate = date }
            item.list = list
            context.insert(item)
            order += 1
        }

        // MARK: Completed
        add(.plus, "Research destination and top sights")
        add(.plus, "Set overall travel budget")
        add(.plus, "Check passport expiry date")

        // MARK: To-do
        add(.dash, "Book outbound and return flights")
        add(.dash, "Reserve hotel for 5 nights")
        add(.dash, "Purchase travel insurance")
        add(.dash, "Notify bank of travel dates")
        add(.dash, "Download offline maps and translation app")

        // MARK: Waiting for
        add(.rightArrow, "Hotel booking confirmation",    waitingFor: "Booking.com")
        add(.rightArrow, "Travel insurance documents",    waitingFor: "Insurance provider")

        // MARK: Delegated
        add(.leftArrow, "Arrange dog sitter for the week", assignedTo: "Alex")

        // MARK: Meeting needs scheduling
        add(.square, "Pre-trip check-up with doctor")

        // MARK: Meeting scheduled (+7 days)
        add(.scheduledMeeting, "Airport transfer pickup", scheduledDate: future7)

        // MARK: Notes
        add(.triangle, "Pack light — carry-on only to skip baggage fees")
        add(.triangle, "Check visa requirements before booking")

        // MARK: Contact
        add(.person, "Maria — local contact for restaurant and nightlife tips")

        // MARK: Someday / Maybe
        add(.someday, "Day trip to nearby national park")
        add(.someday, "Research travel rewards credit cards")
    }
}
