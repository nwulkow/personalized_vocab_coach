import SwiftUI
import Combine

final class AppState: ObservableObject {
    // MARK: - Persisted settings
    @AppStorage("geminiAPIKey") var geminiAPIKey: String = ""
    @AppStorage("dropboxAppKey") var dropboxAppKey: String = ""
    @AppStorage("dropboxAccessToken") var dropboxAccessToken: String = ""
    @AppStorage("dropboxRefreshToken") var dropboxRefreshToken: String = ""
    @AppStorage("dropboxAccessTokenExpiry") var dropboxAccessTokenExpiry: Double = 0
    @AppStorage("primaryLanguage") var primaryLanguageRaw: String = Language.german.rawValue
    @AppStorage("geminiRegularModel") var geminiRegularModel: String = GeminiService.defaultRegularModel
    @AppStorage("geminiFastModel") var geminiFastModel: String = GeminiService.defaultFastModel
    @AppStorage("appearanceMode") var appearanceMode: AppearanceMode = .system

    var primaryLanguage: Language {
        get { Language(rawValue: primaryLanguageRaw) ?? .german }
        set { primaryLanguageRaw = newValue.rawValue }
    }

    // MARK: - Runtime state
    @Published var wordLists: [WordList] = []
    @Published var isSyncing = false
    @Published var syncError: String?

    private let storage = WordListStorage()

    var hasAPIKey: Bool { !geminiAPIKey.trimmingCharacters(in: .whitespaces).isEmpty }

    /// A fresh Gemini client bound to the currently stored key and model choices, or `nil` if
    /// no key is set. The actor is cheap to create — there's no persistent connection to reuse.
    var geminiService: GeminiService? {
        hasAPIKey ? GeminiService(apiKey: geminiAPIKey, regularModel: geminiRegularModel, fastModel: geminiFastModel) : nil
    }

    /// Translation always goes through Google Translate first; Gemini is only the fallback,
    /// so this works even with no API key configured.
    var translationService: TranslationService {
        TranslationService(geminiFallback: geminiService)
    }

    init() {
        loadAllLists()
    }

    // MARK: - Local persistence
    func loadAllLists() {
        wordLists = storage.loadAll()
    }

    func save(_ list: WordList) {
        storage.save(list)
        if let idx = wordLists.firstIndex(where: { $0.id == list.id }) {
            wordLists[idx] = list
        } else {
            wordLists.append(list)
        }
    }

    func deleteList(_ list: WordList) {
        storage.delete(list)
        wordLists.removeAll { $0.id == list.id }
    }

    func wordList(for lang1: Language, _ lang2: Language) -> WordList {
        // Try both orderings
        if let wl = wordLists.first(where: { $0.id == "\(lang1.rawValue)_\(lang2.rawValue)" }) {
            return wl
        }
        if let wl = wordLists.first(where: { $0.id == "\(lang2.rawValue)_\(lang1.rawValue)" }) {
            return wl
        }
        // Create empty list
        let wl = WordList(language1: lang1, language2: lang2, words: [])
        return wl
    }

    func addWordPair(_ pair: WordPair, language1: Language, language2: Language) {
        var wl = wordList(for: language1, language2)
        // Ensure correct language ordering
        if wl.language1 == language1 {
            wl.words.append(pair)
        } else {
            var flipped = pair
            let tmp = flipped.word1
            flipped.word1 = flipped.word2
            flipped.word2 = tmp
            wl.words.append(flipped)
        }
        save(wl)
    }

    // MARK: - Dropbox auth

    var isDropboxConnected: Bool {
        !dropboxRefreshToken.isEmpty || !dropboxAccessToken.isEmpty
    }

    /// Returns a usable access token, refreshing it first when we hold a refresh token and the
    /// cached one is missing or within a minute of expiry. Falls back to a manually pasted
    /// token (the App Console's short-lived `sl.…`) when no refresh token has been set up.
    func validAccessToken() async throws -> String {
        if !dropboxRefreshToken.isEmpty, !dropboxAppKey.isEmpty {
            let stillFresh = !dropboxAccessToken.isEmpty && Date().timeIntervalSince1970 < dropboxAccessTokenExpiry - 60
            if stillFresh { return dropboxAccessToken }

            let tokens = try await DropboxAuth.refresh(refreshToken: dropboxRefreshToken, appKey: dropboxAppKey)
            await MainActor.run {
                dropboxAccessToken = tokens.accessToken
                dropboxAccessTokenExpiry = Date().timeIntervalSince1970 + tokens.expiresIn
            }
            return tokens.accessToken
        }
        guard !dropboxAccessToken.isEmpty else { throw DropboxError.notConnected }
        return dropboxAccessToken
    }

    /// Completes the PKCE flow with the code the user pasted from the Dropbox consent page.
    func completeDropboxAuth(code: String, verifier: String) async throws {
        let tokens = try await DropboxAuth.exchange(code: code, verifier: verifier, appKey: dropboxAppKey)
        await MainActor.run {
            dropboxAccessToken = tokens.accessToken
            dropboxAccessTokenExpiry = Date().timeIntervalSince1970 + tokens.expiresIn
            if let refresh = tokens.refreshToken { dropboxRefreshToken = refresh }
            syncError = nil
        }
    }

    func disconnectDropbox() {
        dropboxAccessToken = ""
        dropboxRefreshToken = ""
        dropboxAccessTokenExpiry = 0
        syncError = nil
    }

    // MARK: - Dropbox sync
    func syncWithDropbox() async {
        guard isDropboxConnected else { return }
        await MainActor.run { isSyncing = true; syncError = nil }
        do {
            let dropbox = DropboxService(accessToken: try await validAccessToken())
            // Upload all local lists
            for list in wordLists {
                try await dropbox.upload(content: list.toCSV(), remotePath: "/Vokabeltrainer/\(list.fileName)")
            }
            // Download all remote lists
            let remoteFiles = try await dropbox.listFolder(path: "/Vokabeltrainer")
            for entry in remoteFiles where entry.hasSuffix(".csv") {
                let csv = try await dropbox.download(remotePath: "/Vokabeltrainer/\(entry)")
                let name = entry.replacingOccurrences(of: ".csv", with: "")
                let parts = name.split(separator: "_")
                guard parts.count == 2,
                      let l1 = Language(rawValue: String(parts[0])),
                      let l2 = Language(rawValue: String(parts[1])) else { continue }
                let remoteList = WordList.fromCSV(csv, language1: l1, language2: l2)
                // Merge: union of word pairs by word1+word2
                var local = wordList(for: l1, l2)
                for rp in remoteList.words {
                    if !local.words.contains(where: { $0.word1 == rp.word1 && $0.word2 == rp.word2 }) {
                        local.words.append(rp)
                    }
                }
                save(local)
            }
            await MainActor.run { isSyncing = false }
        } catch {
            await MainActor.run { isSyncing = false; syncError = error.localizedDescription }
        }
    }
}
