import Foundation

/// Persists word lists as CSV files under Documents/word_lists — the same layout and column
/// format the Python backend uses, so files stay hand-editable and interchangeable via Dropbox
/// or AirDrop with the desktop app.
final class WordListStorage {
    private let fileManager = FileManager.default

    private var directory: URL {
        let dir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("word_lists", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    // MARK: - Public API

    func loadAll() -> [WordList] {
        seedBundledListsIfNeeded()
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }
        var results: [WordList] = []
        for file in files where file.pathExtension.lowercased() == "csv" {
            let name = file.deletingPathExtension().lastPathComponent
            let parts = name.split(separator: "_", maxSplits: 1)
            guard parts.count == 2,
                  let l1 = Language(rawValue: String(parts[0])),
                  let l2 = Language(rawValue: String(parts[1])),
                  let csv = try? String(contentsOf: file, encoding: .utf8) else { continue }
            results.append(WordList.fromCSV(csv, language1: l1, language2: l2))
        }
        return results.sorted { $0.label < $1.label }
    }

    func save(_ list: WordList) {
        let url = directory.appendingPathComponent(list.fileName)
        try? list.toCSV().write(to: url, atomically: true, encoding: .utf8)
    }

    func delete(_ list: WordList) {
        let url = directory.appendingPathComponent(list.fileName)
        try? fileManager.removeItem(at: url)
    }

    // MARK: - First-run seeding

    /// On first launch, copies the small starter word lists bundled with the app (the same
    /// files the desktop app ships with) so the phone isn't empty on day one. This never
    /// overwrites anything the user has already created or synced.
    private func seedBundledListsIfNeeded() {
        let marker = directory.appendingPathComponent(".seeded")
        guard !fileManager.fileExists(atPath: marker.path) else { return }

        let pairs: [(Language, Language)] = [
            (.german, .english), (.german, .french), (.german, .spanish),
            (.english, .spanish), (.french, .english), (.spanish, .french),
        ]
        for (l1, l2) in pairs {
            let name = "\(l1.rawValue)_\(l2.rawValue)"
            guard let bundled = Bundle.main.url(forResource: name, withExtension: "csv") else { continue }
            let dest = directory.appendingPathComponent("\(name).csv")
            guard !fileManager.fileExists(atPath: dest.path) else { continue }
            try? fileManager.copyItem(at: bundled, to: dest)
        }
        fileManager.createFile(atPath: marker.path, contents: Data())
    }
}
