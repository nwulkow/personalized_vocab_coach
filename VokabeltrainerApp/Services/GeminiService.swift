import Foundation

/// All AI-powered features in the app (translation, tag suggestions, answer checking,
/// sentence generation, writing feedback, word filtering) go through this one actor.
/// It talks directly to the Gemini REST API — no local/Ollama model is ever used.
actor GeminiService {
    private let apiKey: String

    /// Model for quality-sensitive work: tagging, sentence wording, writing feedback, filtering.
    private let regularModel: String

    /// Model for latency-sensitive, low-token work: answer checking, batched sentence creation.
    private let fastModel: String

    /// Regular defaults to the `-latest` alias so it tracks Google's current Flash generation.
    /// Fast is pinned to 3.1 Flash-Lite — small and cheap, and explicitly *not* the older
    /// 2.5 Flash-Lite. Both are overridable in Settings.
    static let defaultRegularModel = "gemini-flash-latest"
    static let defaultFastModel = "gemini-3.1-flash-lite"

    init(apiKey: String, regularModel: String = defaultRegularModel, fastModel: String = defaultFastModel) {
        self.apiKey = apiKey
        let regular = regularModel.trimmingCharacters(in: .whitespaces)
        let fast = fastModel.trimmingCharacters(in: .whitespaces)
        self.regularModel = regular.isEmpty ? Self.defaultRegularModel : regular
        self.fastModel = fast.isEmpty ? Self.defaultFastModel : fast
    }

    // MARK: - Low-level generation

    func generate(_ prompt: String, temperature: Double = 0.2, maxTokens: Int = 200) async throws -> String {
        // The other configured model is tried as a fallback so a bad/retired model id in
        // Settings degrades instead of breaking the feature outright.
        try await callChain([regularModel, fastModel], prompt: prompt, temperature: temperature, maxTokens: maxTokens)
    }

    func generateFast(_ prompt: String, temperature: Double = 0.05, maxTokens: Int = 120) async throws -> String {
        try await callChain([fastModel, regularModel], prompt: prompt, temperature: temperature, maxTokens: maxTokens)
    }

    private func callChain(_ models: [String], prompt: String, temperature: Double, maxTokens: Int) async throws -> String {
        var lastError: Error = GeminiError.noResponse
        var tried = Set<String>()
        for model in models where !tried.contains(model) {
            tried.insert(model)
            do {
                return try await call(model: model, prompt: prompt, temperature: temperature, maxTokens: maxTokens)
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    // MARK: - Model discovery

    /// Fetches the models this API key can actually call, so Settings can offer a real list
    /// instead of hardcoded guesses that go stale as Google ships new generations.
    func availableModels() async throws -> [String] {
        guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else { throw GeminiError.missingAPIKey }
        var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models")!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "pageSize", value: "200"),
        ]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw GeminiError.apiError(Self.extractErrorMessage(data) ?? "HTTP \(http.statusCode)")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [[String: Any]] else {
            throw GeminiError.noResponse
        }
        return models.compactMap { model -> String? in
            guard let name = model["name"] as? String else { return nil }
            let methods = model["supportedGenerationMethods"] as? [String] ?? []
            guard methods.contains("generateContent") else { return nil }
            return name.hasPrefix("models/") ? String(name.dropFirst("models/".count)) : name
        }
        .sorted()
    }

    // MARK: - Translation

    /// Translates free text between two languages. This is the *fallback* path only —
    /// `TranslationService` prefers Google Translate and calls this when Google is unreachable.
    func translate(_ text: String, from: Language, to: Language) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let prompt = """
        Translate the following text from \(from.displayName) to \(to.displayName).
        Respond with ONLY the translation — no quotes, no explanations, no alternatives.

        Text: "\(trimmed)"
        """
        let result = try await generate(prompt, temperature: 0.1, maxTokens: max(60, trimmed.count * 3))
        return Self.stripSurroundingQuotes(result)
    }

    // MARK: - Answer checking

    func checkEquality(userAnswer: String, correctAnswer: String, beStringent: Bool = false) async throws -> Bool {
        let a = Self.normalize(userAnswer)
        let b = Self.normalize(correctAnswer)
        if a == b { return true }
        if a.count < 2 { return false }

        var prompt = """
        Classify the relationship between the following expressions.

        Expression A: "\(a)"
        Expression B: "\(b)"

        Label:
        - SAME → meanings are equivalent in everyday usage
        - DIFFERENT → meanings are not equivalent in everyday usage

        It is important that they must mean the same thing, not just be similar. But do not \
        consider minor differences such as plural/singular, verb conjugations, or small \
        spelling mistakes. Focus on the core meaning of the words.
        Answer with ONLY: SAME or DIFFERENT
        """
        if beStringent { prompt += "\nBe stringent in your classification." }

        let response = try await generateFast(prompt, temperature: 0.01, maxTokens: 20).lowercased()
        if response.contains("different") { return false }
        return response.contains("same")
    }

    // MARK: - Alternatives

    func showAlternatives(word: String, src: Language, dest: Language, googleTranslation: String?, maxCount: Int = 5) async throws -> [String] {
        var prompt = """
        Provide a list of at most \(maxCount) different translations for the word "\(word)" from \(src.displayName) to \(dest.displayName).
        The translations should be common and widely used. If there are not \(maxCount) different translations, provide as many as possible.
        Return the translations in a semicolon-separated format without any additional text.
        """
        if let gt = googleTranslation, !gt.isEmpty {
            prompt += " The first (most common) translation is: \(gt). Use it as the first item you return."
        }
        let response = try await generate(prompt, temperature: 0.1, maxTokens: 120)
        return Self.splitSemicolonList(response)
    }

    // MARK: - Tag suggestions

    func suggestTags(word1: String, word2: String, lang1: Language, lang2: Language, existingTags: [String]) async throws -> [String] {
        let tagsStr = existingTags.joined(separator: ", ")
        let prompt = """
        From the following list of existing tags: \(tagsStr), suggest a list of relevant tags for the word pair \
        "\(word1)" in \(lang1.displayName) and "\(word2)" in \(lang2.displayName).
        The tags should be relevant to the meaning, usage, or other characteristics of the word pair. \
        Return the tags in a semicolon-separated format without any additional text.
        """
        let response = try await generate(prompt, temperature: 0.25, maxTokens: 120)
        return Self.splitSemicolonList(response)
    }

    // MARK: - Sentence creation

    /// Creates one example sentence for `word` in `language`. Translating that sentence is the
    /// caller's job (via `TranslationService`), so the translation goes through Google Translate
    /// like every other translation in the app rather than staying inside Gemini.
    func createSentence(word: String, language: Language, maxWords: Int = 10, level: String = "C1", remark: String?) async throws -> String {
        var cleanWord = word
        if cleanWord.hasPrefix("to ") { cleanWord = String(cleanWord.dropFirst(3)) }
        cleanWord = cleanWord.split(separator: ",").first.map(String.init) ?? cleanWord

        let prompt = """
        Create a simple sentence (up to \(maxWords) words) in \(language.displayName) using the word '\(cleanWord)'. \
        The sentence should have maximal difficulty for a language learner at the \(level) level. \
        \(remark ?? "")
        Only (!) return the created sentence and nothing more!
        """
        let raw = try await generateFast(prompt, temperature: 0.7, maxTokens: 60)
        return Self.firstLine(raw)
    }

    struct SentenceBatchItem {
        let index: Int
        let word: String
        let translation: String
    }

    struct SentenceBatchResult {
        let index: Int
        let sentence1: String
        let sentence2: String
    }

    /// Generates several example-sentence pairs in a single Gemini call — used to pre-fetch
    /// a batch of test words at once instead of one round-trip per word.
    func createSentenceBatch(items: [SentenceBatchItem], language1: Language, language2: Language, maxWords: Int, level: String, remark: String?) async throws -> [SentenceBatchResult] {
        guard !items.isEmpty else { return [] }
        let payload = items.map { ["index": $0.index, "word": $0.word, "translation": $0.translation] as [String: Any] }
        let payloadData = try JSONSerialization.data(withJSONObject: payload)
        let payloadStr = String(data: payloadData, encoding: .utf8) ?? "[]"

        let prompt = """
        You are helping with vocabulary practice.
        For each input item, create exactly one short sentence in \(language1.displayName) (max \(maxWords) words) \
        at approximately \(level) level using the given word naturally.
        Also provide the matching sentence translation in \(language2.displayName).
        \(remark ?? "")
        Return ONLY valid JSON array, no markdown, no extra text.
        JSON schema per item: {"index": int, "sentence_language_1": str, "sentence_language_2": str}
        Input items JSON:
        \(payloadStr)
        """
        let response = try await generateFast(prompt, temperature: 0.2, maxTokens: max(400, items.count * 90))
        return Self.parseSentenceBatch(response)
    }

    // MARK: - Writing evaluation

    func evaluateText(text: String, words: [String], language: Language, level: String) async throws -> String {
        let wordsStr = words.map { "\"\($0)\"" }.joined(separator: ", ")
        let levelHint: String
        switch level {
        case "Basic":
            levelHint = "Focus only on very basic mistakes (word order, missing articles, verb conjugations). Do not point out subtle issues."
        case "Advanced":
            levelHint = "Be very thorough — check for subtle mistakes, nuances, idiomatic expressions, and stylistic issues."
        default:
            levelHint = "Check for common mistakes that hinder clear communication, but do not be overly strict about minor stylistic issues."
        }
        let prompt = """
        The user was asked to write a text in \(language.displayName) that contains the following word(s): \(wordsStr).

        Their text: "\(text)"

        Please:
        1. Check whether the required word(s) appear (or a grammatically correct form of them).
        2. Check the text for language mistakes and explain them briefly and concisely.
        If there are no mistakes, only say "No mistakes found."
        \(levelHint)
        """
        let response = try await generate(prompt, temperature: 0.15, maxTokens: 550)
        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Word filtering by free-text description

    /// Filters `words` down to those matching a natural-language description (e.g. "verbs only"),
    /// sending them to Gemini in batches to keep prompts small and reliable.
    func filterWords(_ words: [String], description: String, batchSize: Int = 20) async throws -> [String] {
        guard !words.isEmpty else { return [] }
        var collected: [String] = []
        var seen = Set<String>()

        for start in stride(from: 0, to: words.count, by: batchSize) {
            let batch = Array(words[start..<min(start + batchSize, words.count)])
            let batchStr = batch.joined(separator: ";")
            let prompt = """
            Return only the words that match the description, separated by semicolons.
            Do not return any explanations or additional text.
            Description: \(description)
            Words:
            \(batchStr)
            """
            let response = try await generate(prompt, temperature: 0.1, maxTokens: 260)
            let matched = Self.splitSemicolonList(response).filter { batch.contains($0) }
            for w in matched where !seen.contains(w) {
                seen.insert(w)
                collected.append(w)
            }
        }
        return collected
    }

    // MARK: - Connectivity check (used by Settings to validate a pasted API key)

    func verifyKey() async throws {
        _ = try await generateFast("Reply with the single word OK.", temperature: 0, maxTokens: 5)
    }

    /// Offline fallback comparison (exact match after normalization) used when there's no
    /// API key or a request fails, so answer checking still works in some form.
    nonisolated static func quickEquals(_ a: String, _ b: String) -> Bool {
        normalize(a) == normalize(b)
    }

    // MARK: - Private networking

    private func call(model: String, prompt: String, temperature: Double, maxTokens: Int) async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else { throw GeminiError.missingAPIKey }
        var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": [
                "temperature": temperature,
                "maxOutputTokens": maxTokens,
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let msg = Self.extractErrorMessage(data) ?? "HTTP \(http.statusCode)"
            throw GeminiError.apiError(msg)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw GeminiError.noResponse
        }
        let text = parts.compactMap { $0["text"] as? String }.joined()
        guard !text.isEmpty else { throw GeminiError.noResponse }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractErrorMessage(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let message = error["message"] as? String else { return nil }
        return message
    }

    // MARK: - Text helpers

    private static func normalize(_ s: String) -> String {
        var result = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for (char, replacement) in [("!", ""), (".", ""), (",", ""), ("?", ""), ("¿", ""),
                                     ("í", "i"), ("á", "a"), ("é", "e"), ("ó", "o"), ("ú", "u")] {
            result = result.replacingOccurrences(of: char, with: replacement)
        }
        return result
    }

    private static func stripSurroundingQuotes(_ s: String) -> String {
        var result = s.trimmingCharacters(in: .whitespacesAndNewlines)
        for quote in ["\"", "'", "„", "“", "”"] {
            if result.hasPrefix(quote) { result.removeFirst() }
            if result.hasSuffix(quote) { result.removeLast() }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func firstLine(_ s: String) -> String {
        let line = s.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "\n").first.map(String.init) ?? s
        return stripSurroundingQuotes(line)
    }

    private static func splitSemicolonList(_ s: String) -> [String] {
        s.split(separator: ";").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private static func parseSentenceBatch(_ text: String) -> [SentenceBatchResult] {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = cleaned.firstIndex(of: "["), let end = cleaned.lastIndex(of: "]"), end > start else { return [] }
        let jsonStr = String(cleaned[start...end])
        guard let data = jsonStr.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return array.compactMap { dict in
            guard let idx = dict["index"] as? Int,
                  let s1 = dict["sentence_language_1"] as? String, !s1.isEmpty,
                  let s2 = dict["sentence_language_2"] as? String, !s2.isEmpty else { return nil }
            return SentenceBatchResult(index: idx, sentence1: s1, sentence2: s2)
        }
    }
}

enum GeminiError: LocalizedError {
    case noResponse
    case apiError(String)
    case missingAPIKey

    var errorDescription: String? {
        switch self {
        case .noResponse: return "No response from Gemini."
        case .apiError(let msg): return "Gemini error: \(msg)"
        case .missingAPIKey: return "No Gemini API key set. Add one in Settings."
        }
    }
}
