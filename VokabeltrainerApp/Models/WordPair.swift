import Foundation

struct WordPair: Identifiable, Codable, Equatable {
    var id = UUID()
    var word1: String          // word in language_1
    var word2: String          // word in language_2
    var dateAdded: Date
    var tags: [String]

    // MARK: - Helpers
    var tagsString: String {
        tags.joined(separator: ";")
    }

    static func fromCSVRow(_ dict: [String: String], lang1Col: String, lang2Col: String) -> WordPair? {
        guard let w1 = dict[lang1Col], !w1.isEmpty,
              let w2 = dict[lang2Col], !w2.isEmpty else { return nil }
        let dateStr = dict["date_added"] ?? ""
        let date = Self.parseDate(dateStr) ?? Date()
        let rawTags = dict["tags"] ?? ""
        let tags = rawTags.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return WordPair(word1: w1, word2: w2, dateAdded: date, tags: tags)
    }

    func toCSVDict(lang1Col: String, lang2Col: String) -> [String: String] {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm"
        return [
            lang1Col: word1,
            lang2Col: word2,
            "date_added": fmt.string(from: dateAdded),
            "tags": tagsString
        ]
    }

    private static func parseDate(_ s: String) -> Date? {
        let fmt = DateFormatter()
        for format in ["yyyy-MM-dd HH:mm", "yyyy-MM-dd"] {
            fmt.dateFormat = format
            if let d = fmt.date(from: s) { return d }
        }
        return nil
    }
}
