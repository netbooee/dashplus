import Foundation
import SwiftData

struct DashPlusExporter {

    // MARK: - Export

    static func exportText(for list: DashList) -> String {
        let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        var lines = [
            "# Dash Plus Export",
            "# List: \(list.name) (\(list.prefix))",
            "# Exported: \(dateStr)",
            ""
        ]

        let sorted = list.itemList.sorted {
            $0.sortOrder == $1.sortOrder ? $0.createdAt < $1.createdAt : $0.sortOrder < $1.sortOrder
        }

        for item in sorted {
            let prefix = item.categoryCode.isEmpty ? list.prefix : item.categoryCode
            let base = prefix.isEmpty ? item.text : "\(prefix): \(item.text)"
            var line = "\(item.symbol.exportSymbol) \(base)"

            if item.symbol == .leftArrow, !item.assignedTo.isEmpty {
                line += "  @\(item.assignedTo)"
            }
            if item.symbol == .rightArrow, !item.waitingFor.isEmpty {
                line += "  ->\(item.waitingFor)"
            }
            if item.symbol == .scheduledMeeting {
                line += "  date:\(isoDate(item.scheduledDate))"
            }

            lines.append(line)
        }

        return lines.joined(separator: "\n")
    }

    static func exportFileName(for list: DashList) -> String {
        let tag = list.prefix.isEmpty ? list.name : list.prefix
        return "\(tag)_dashplus.txt"
    }

    static func writeToTemp(list: DashList) -> URL {
        let text = exportText(for: list)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(exportFileName(for: list))
        try? text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Full backup export

    static func exportAllText(lists: [DashList]) -> String {
        let dateStr = ISO8601DateFormatter().string(from: Date()).prefix(10)
        var lines = [
            "# HappensNext Backup",
            "# Exported: \(dateStr)",
            "# Projects: \(lists.count)",
        ]

        let sorted = lists.sorted {
            if $0.prefix == "GEN" { return true }
            if $1.prefix == "GEN" { return false }
            return $0.prefix < $1.prefix
        }

        for list in sorted {
            lines.append("")
            lines.append("## List: \(list.name) (\(list.prefix))")
            let items = list.itemList.sorted {
                $0.sortOrder == $1.sortOrder ? $0.createdAt < $1.createdAt : $0.sortOrder < $1.sortOrder
            }
            for item in items {
                let prefix = item.categoryCode.isEmpty ? list.prefix : item.categoryCode
                let base = prefix.isEmpty ? item.text : "\(prefix): \(item.text)"
                var line = "\(item.symbol.exportSymbol) \(base)"
                if item.symbol == .leftArrow, !item.assignedTo.isEmpty { line += "  @\(item.assignedTo)" }
                if item.symbol == .rightArrow, !item.waitingFor.isEmpty { line += "  ->\(item.waitingFor)" }
                if item.symbol == .scheduledMeeting { line += "  date:\(isoDate(item.scheduledDate))" }
                lines.append(line)
            }
        }

        return lines.joined(separator: "\n")
    }

    static func exportAllFileName() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return "HappensNext_backup_\(f.string(from: Date())).txt"
    }

    static func writeAllToTemp(lists: [DashList]) -> URL {
        let text = exportAllText(lists: lists)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(exportAllFileName())
        try? text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Full backup import

    /// Imports a full backup file, creating a new list for each section.
    static func importAll(from text: String, context: ModelContext) {
        // Split into per-list chunks on "## List:" lines
        var chunks: [String] = []
        var current: [String] = []

        for line in text.components(separatedBy: .newlines) {
            if line.hasPrefix("## List:") {
                if !current.isEmpty { chunks.append(current.joined(separator: "\n")) }
                // Convert "## List:" → "# List:" so existing parser handles it
                current = ["# List:" + line.dropFirst("## List:".count)]
            } else {
                current.append(line)
            }
        }
        if !current.isEmpty { chunks.append(current.joined(separator: "\n")) }

        for chunk in chunks where !chunk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            importAsNewList(from: chunk, context: context)
        }
    }

    /// Returns true if the text looks like a full backup (multi-list) file.
    static func isFullBackup(_ text: String) -> Bool {
        text.contains("## List:")
    }

    // MARK: - Import

    /// Append parsed items to an existing list.
    static func importItems(from text: String, into list: DashList, context: ModelContext) {
        let entries = parse(text).entries
        var order = list.itemList.count
        for entry in entries {
            let item = makeItem(from: entry, sortOrder: order)
            item.list = list
            context.insert(item)
            order += 1
        }
    }

    /// Create a brand-new list from the file, including its name and prefix.
    @discardableResult
    static func importAsNewList(from text: String, context: ModelContext) -> DashList {
        let result = parse(text)
        let list = DashList(name: result.name, prefix: result.prefix)
        context.insert(list)
        for (index, entry) in result.entries.enumerated() {
            let item = makeItem(from: entry, sortOrder: index)
            item.list = list
            context.insert(item)
        }
        return list
    }

    // MARK: - Private

    private struct ParsedEntry {
        var symbol: ItemSymbol
        var categoryCode: String
        var text: String
        var assignedTo: String
        var waitingFor: String
        var scheduledDate: Date?
    }

    private struct ParseResult {
        var name: String
        var prefix: String
        var entries: [ParsedEntry]
    }

    private static func parse(_ text: String) -> ParseResult {
        var name = "Imported List"
        var prefix = ""
        var entries: [ParsedEntry] = []

        let symbolTokens: [(String, ItemSymbol)] = [
            ("[+]", .scheduledMeeting),
            ("[]",  .square),
            ("-",   .dash),
            ("+",   .plus),
            (">",   .rightArrow),
            ("<",   .leftArrow),
            ("^",   .triangle),
            ("o",   .circle),
            ("P",   .person),
            ("~",   .someday)
        ]

        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)

            // Header comments
            if line.hasPrefix("# List:") {
                let detail = line.dropFirst("# List:".count).trimmingCharacters(in: .whitespaces)
                if let ps = detail.lastIndex(of: "("), let pe = detail.lastIndex(of: ")"), ps < pe {
                    name = String(detail[detail.startIndex..<ps]).trimmingCharacters(in: .whitespaces)
                    prefix = String(detail[detail.index(after: ps)..<pe])
                } else {
                    name = detail
                }
                continue
            }
            if line.isEmpty || line.hasPrefix("#") { continue }

            // Match symbol
            var matched: ItemSymbol?
            var rest = ""
            for (token, sym) in symbolTokens {
                if line.hasPrefix(token + " ") {
                    matched = sym
                    rest = String(line.dropFirst(token.count + 1))
                    break
                }
            }
            guard let symbol = matched else { continue }

            // Split on double-space to separate task text from metadata tokens
            var segments = rest.components(separatedBy: "  ")
            let baseSegment = segments.removeFirst().trimmingCharacters(in: .whitespaces)

            var assignedTo = ""
            var waitingFor = ""
            var scheduledDate: Date? = nil

            for segment in segments {
                let s = segment.trimmingCharacters(in: .whitespaces)
                if s.hasPrefix("@") {
                    assignedTo = String(s.dropFirst())
                } else if s.hasPrefix("->") {
                    waitingFor = String(s.dropFirst(2))
                } else if s.hasPrefix("date:") {
                    scheduledDate = parseISODate(String(s.dropFirst(5)))
                }
            }

            // Parse PREFIX: text
            var categoryCode = ""
            var itemText = baseSegment
            if let colonIdx = baseSegment.range(of: ": ") {
                let potentialPrefix = String(baseSegment[baseSegment.startIndex..<colonIdx.lowerBound])
                if potentialPrefix.count <= 5 && potentialPrefix.allSatisfy({ $0.isLetter || $0.isNumber }) {
                    categoryCode = potentialPrefix
                    itemText = String(baseSegment[colonIdx.upperBound...])
                }
            }

            guard !itemText.isEmpty else { continue }
            entries.append(ParsedEntry(
                symbol: symbol,
                categoryCode: categoryCode,
                text: itemText,
                assignedTo: assignedTo,
                waitingFor: waitingFor,
                scheduledDate: scheduledDate
            ))
        }

        return ParseResult(name: name, prefix: prefix, entries: entries)
    }

    private static func makeItem(from entry: ParsedEntry, sortOrder: Int) -> DashItem {
        let item = DashItem(
            symbol: entry.symbol,
            categoryCode: entry.categoryCode,
            text: entry.text,
            sortOrder: sortOrder
        )
        item.assignedTo = entry.assignedTo
        item.waitingFor = entry.waitingFor
        if let date = entry.scheduledDate {
            item.scheduledDate = date
        }
        return item
    }

    private static func isoDate(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.string(from: date)
    }

    private static func parseISODate(_ string: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.date(from: string)
    }
}
