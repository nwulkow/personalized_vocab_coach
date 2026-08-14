import Foundation

/// Plain-text translation. Uses **Google Translate** as the primary engine — the same free
/// endpoint the Python backend's `googletrans` dependency wraps — and only falls back to
/// Gemini if Google is unreachable or returns nothing usable.
///
/// Google is preferred here because for single words and short phrases it is faster, free,
/// and gives the terse literal output a vocabulary trainer wants, whereas an LLM tends to
/// editorialise. Gemini stays available so translation never hard-fails offline of Google.
actor TranslationService {
    private let geminiFallback: GeminiService?

    init(geminiFallback: GeminiService?) {
        self.geminiFallback = geminiFallback
    }

    enum Engine: String {
        case google = "Google Translate"
        case gemini = "Gemini"
    }

    struct Result {
        let text: String
        let engine: Engine
    }

    func translate(_ text: String, from: Language, to: Language) async throws -> Result {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return Result(text: "", engine: .google) }

        do {
            let translated = try await googleTranslate(trimmed, from: from, to: to)
            if !translated.isEmpty {
                return Result(text: translated, engine: .google)
            }
        } catch {
            // Fall through to Gemini below.
        }

        guard let geminiFallback else { throw TranslationError.googleFailed }
        let translated = try await geminiFallback.translate(trimmed, from: from, to: to)
        return Result(text: translated, engine: .gemini)
    }

    /// Convenience for callers that don't care which engine answered.
    func translatedText(_ text: String, from: Language, to: Language) async throws -> String {
        try await translate(text, from: from, to: to).text
    }

    // MARK: - Google Translate

    /// Calls the public `translate_a/single` endpoint (client=gtx) — the same one `googletrans`
    /// uses. No API key required. The response is a nested JSON array rather than an object:
    /// `[[["translated chunk","source chunk",…], …], …]`, so the translation is assembled by
    /// concatenating element 0 of every segment in the first array.
    private func googleTranslate(_ text: String, from: Language, to: Language) async throws -> String {
        var components = URLComponents(string: "https://translate.googleapis.com/translate_a/single")!
        components.queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: from.gtCode),
            URLQueryItem(name: "tl", value: to.gtCode),
            URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "q", value: text),
        ]
        guard let url = components.url else { throw TranslationError.googleFailed }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw TranslationError.googleFailed
        }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [Any],
              let segments = root.first as? [Any] else {
            throw TranslationError.googleFailed
        }

        let pieces = segments.compactMap { segment -> String? in
            guard let parts = segment as? [Any], let chunk = parts.first as? String else { return nil }
            return chunk
        }
        return pieces.joined().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum TranslationError: LocalizedError {
    case googleFailed

    var errorDescription: String? {
        switch self {
        case .googleFailed:
            return "Google Translate is unreachable and no Gemini key is set as fallback."
        }
    }
}
