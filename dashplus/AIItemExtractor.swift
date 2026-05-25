import Foundation

// MARK: - ExtractedItem

struct ExtractedItem: Identifiable {
    var id = UUID()
    var symbol: ItemSymbol
    var text: String
    var projectHint: String?
    /// Resolved list ID — set after matching projectHint against real projects.
    var selectedListID: UUID?
    var startDate: Date?
    var dueDate: Date?
    var assignedTo: String = ""
    var waitingFor: String = ""
    var isIncluded: Bool = true
}

// MARK: - AIItemExtractor

struct AIItemExtractor {

    // MARK: Errors

    enum ExtractionError: LocalizedError {
        case networkError(Error)
        case apiError(Int, String)
        case emptyResponse
        case parseError(String)

        var errorDescription: String? {
            switch self {
            case .networkError(let e):   return "Network error: \(e.localizedDescription)"
            case .apiError(let code, let msg): return "API error \(code): \(msg)"
            case .emptyResponse:         return "The AI returned an empty response."
            case .parseError(let msg):   return "Could not read AI response: \(msg)"
            }
        }
    }

    // MARK: API call

    static func extract(from note: String, apiKey: String) async throws -> [ExtractedItem] {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let today = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))

        let system = """
        You extract actionable items from free-form notes for a Dash/Plus symbol-based task app.

        Available symbol types:
        - dash             → to-do / next action
        - rightArrow       → waiting for someone or something
        - leftArrow        → delegated to someone else
        - square           → meeting that needs scheduling (no date yet)
        - scheduledMeeting → meeting already scheduled with a specific date
        - triangle         → reference note or information (non-actionable)
        - person           → new contact to remember
        - someday          → someday/maybe idea, not urgent

        Today is \(today). Resolve relative dates ("tomorrow", "next Friday", "in two weeks") to ISO 8601 date strings (YYYY-MM-DD).

        Return ONLY a valid JSON array — no markdown fences, no explanation. Each object:
        {
          "symbol": "<type>",
          "text": "<concise item description>",
          "projectHint": "<project name if clearly mentioned, null otherwise>",
          "startDate": "<YYYY-MM-DD or null>",
          "dueDate": "<YYYY-MM-DD or null>",
          "assignedTo": "<person name if delegated, empty string otherwise>",
          "waitingFor": "<person or thing if waiting, empty string otherwise>"
        }
        """

        let body: [String: Any] = [
            "model": "claude-haiku-4-5",
            "max_tokens": 1024,
            "system": system,
            "messages": [["role": "user", "content": note]]
        ]

        let bodyData: Data
        do {
            bodyData = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw ExtractionError.parseError("Could not encode request")
        }
        request.httpBody = bodyData

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ExtractionError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw ExtractionError.networkError(URLError(.badServerResponse))
        }
        guard http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "No body"
            throw ExtractionError.apiError(http.statusCode, msg)
        }

        // Decode Claude response envelope
        struct Envelope: Decodable {
            struct Block: Decodable { let type: String; let text: String? }
            let content: [Block]
        }
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard let raw = envelope.content.first(where: { $0.type == "text" })?.text else {
            throw ExtractionError.emptyResponse
        }

        // Strip accidental markdown fences
        let cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleaned.data(using: .utf8),
              let rawItems = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
            throw ExtractionError.parseError("Response was not a JSON array:\n\(cleaned.prefix(200))")
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]

        return rawItems.compactMap { dict -> ExtractedItem? in
            guard let text = dict["text"] as? String, !text.isEmpty,
                  let symbolRaw = dict["symbol"] as? String,
                  let symbol = ItemSymbol(rawValue: symbolRaw) else { return nil }
            var item = ExtractedItem(symbol: symbol, text: text)
            item.projectHint = dict["projectHint"] as? String
            item.assignedTo  = dict["assignedTo"]  as? String ?? ""
            item.waitingFor  = dict["waitingFor"]  as? String ?? ""
            if let s = dict["startDate"] as? String { item.startDate = iso.date(from: s) }
            if let d = dict["dueDate"]   as? String { item.dueDate   = iso.date(from: d) }
            return item
        }
    }
}
