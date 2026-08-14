import Foundation

struct WordList: Identifiable, Codable {
    var id: String { "\(language1.rawValue)_\(language2.rawValue)" }
    let language1: Language
    let language2: Language
    var words: [WordPair]

    var label: String { "\(language1.displayName) ↔ \(language2.displayName)" }

    var lang1Col: String { language1.displayName }
    var lang2Col: String { language2.displayName }

    var allTags: [String] {
        let set = Set(words.flatMap { $0.tags })
        return set.sorted()
    }

    // MARK: - CSV Serialization
    func toCSV() -> String {
        var lines = ["\(lang1Col),\(lang2Col),date_added,tags"]
        for w in words {
            let d = w.toCSVDict(lang1Col: lang1Col, lang2Col: lang2Col)
            let row = [d[lang1Col]!, d[lang2Col]!, d["date_added"]!, d["tags"]!]
                .map { csvEscape($0) }
                .joined(separator: ",")
            lines.append(row)
        }
        return lines.joined(separator: "\n")
    }

    static func fromCSV(_ csv: String, language1: Language, language2: Language) -> WordList {
        let rows = parseCSV(csv)
        let lang1Col = language1.displayName
        let lang2Col = language2.displayName
        let pairs = rows.compactMap { WordPair.fromCSVRow($0, lang1Col: lang1Col, lang2Col: lang2Col) }
        return WordList(language1: language1, language2: language2, words: pairs)
    }

    var fileName: String { "\(language1.rawValue)_\(language2.rawValue).csv" }

    /// Returns `(wordIn: from, wordIn: theOtherLanguage)` for a pair, regardless of how the
    /// list happens to be ordered on disk (a list found under the reversed file name still
    /// stores `language1`/`language2` in its original order).
    func words(_ pair: WordPair, from: Language) -> (String, String) {
        language1 == from ? (pair.word1, pair.word2) : (pair.word2, pair.word1)
    }

    /// True if this list actually represents the given (unordered) language pair.
    func matches(_ a: Language, _ b: Language) -> Bool {
        (language1 == a && language2 == b) || (language1 == b && language2 == a)
    }
}

// MARK: - CSV Helpers (private)
private func csvEscape(_ field: String) -> String {
    if field.contains(",") || field.contains("\"") || field.contains("\n") {
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
    return field
}

private func parseCSV(_ text: String) -> [[String: String]] {
    let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    guard lines.count > 1 else { return [] }
    let headers = splitCSVLine(lines[0])
    return lines.dropFirst().map { line in
        let fields = splitCSVLine(line)
        var dict: [String: String] = [:]
        for (i, h) in headers.enumerated() {
            dict[h] = i < fields.count ? fields[i] : ""
        }
        return dict
    }
}

private func splitCSVLine(_ line: String) -> [String] {
    var fields: [String] = []
    var current = ""
    var inQuotes = false
    for ch in line {
        if ch == "\"" {
            inQuotes.toggle()
        } else if ch == "," && !inQuotes {
            fields.append(current)
            current = ""
        } else {
            current.append(ch)
        }
    }
    fields.append(current)
    return fields.map { $0.trimmingCharacters(in: .whitespaces) }
}
