import Foundation

enum Language: String, CaseIterable, Identifiable, Codable {
    case german, english, spanish, french

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    /// Two-letter badge used instead of flag emoji — flags render inconsistently across
    /// fonts/devices (and don't map cleanly onto languages spoken in many countries),
    /// so a plain code badge is both more robust and more accurate.
    var code: String {
        switch self {
        case .german:  return "DE"
        case .english: return "EN"
        case .spanish: return "ES"
        case .french:  return "FR"
        }
    }

    /// Google-Translate language code
    var gtCode: String {
        switch self {
        case .german:  return "de"
        case .english: return "en"
        case .spanish: return "es"
        case .french:  return "fr"
        }
    }

    /// BCP-47 locale identifier for on-device speech synthesis.
    var speechLocale: String {
        switch self {
        case .german:  return "de-DE"
        case .english: return "en-US"
        case .spanish: return "es-ES"
        case .french:  return "fr-FR"
        }
    }
}
