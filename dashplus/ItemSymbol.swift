import SwiftUI

enum ItemSymbol: String, CaseIterable, Codable {
    case dash
    case plus
    case rightArrow
    case leftArrow
    case triangle
    case circle
    case square
    case scheduledMeeting
    case person

    var systemImageName: String {
        switch self {
        case .dash:             return "minus"
        case .plus:             return "plus"
        case .rightArrow:       return "arrow.right"
        case .leftArrow:        return "arrow.left"
        case .triangle:         return "triangle"
        case .circle:           return "arrow.right.circle"
        case .square:           return "square"
        case .scheduledMeeting: return "calendar.badge.plus"
        case .person:           return "person"
        }
    }

    var color: Color {
        switch self {
        case .dash:             return .secondary
        case .plus:             return .green
        case .rightArrow:       return .orange
        case .leftArrow:        return .blue
        case .triangle:         return .purple
        case .circle:           return .gray
        case .square:           return .red
        case .scheduledMeeting: return .teal
        case .person:           return .cyan
        }
    }

    var exportSymbol: String {
        switch self {
        case .dash:             return "-"
        case .plus:             return "+"
        case .rightArrow:       return ">"
        case .leftArrow:        return "<"
        case .triangle:         return "^"
        case .circle:           return "o"
        case .square:           return "[]"
        case .scheduledMeeting: return "[+]"
        case .person:           return "P"
        }
    }

    static func from(exportSymbol: String) -> ItemSymbol? {
        switch exportSymbol {
        case "-":   return .dash
        case "+":   return .plus
        case ">":   return .rightArrow
        case "<":   return .leftArrow
        case "^":   return .triangle
        case "o":   return .circle
        case "[]":  return .square
        case "[+]": return .scheduledMeeting
        case "P":   return .person
        default:    return nil
        }
    }

    var label: String {
        switch self {
        case .dash:             return "To Do"
        case .plus:             return "Complete"
        case .rightArrow:       return "Waiting"
        case .leftArrow:        return "Delegated"
        case .triangle:         return "Note"
        case .circle:           return "Move to List"
        case .square:           return "Schedule Meeting"
        case .scheduledMeeting: return "Meeting Scheduled"
        case .person:           return "New Contact"
        }
    }
}
