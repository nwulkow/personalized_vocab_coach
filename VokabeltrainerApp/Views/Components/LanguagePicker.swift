import SwiftUI

/// Small rounded code badge (e.g. "DE") standing in for a flag — renders consistently
/// everywhere, unlike regional-indicator flag emoji, and doesn't imply one country per language.
struct LanguageCodeBadge: View {
    let language: Language
    var size: CGFloat = 30

    var body: some View {
        Text(language.code)
            .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
            .foregroundStyle(Color.brandIndigo)
            .frame(width: size, height: size)
            .background(Circle().fill(Color.brandIndigo.opacity(0.14)))
    }
}

/// Compact badge + name menu used everywhere a source/target language needs picking.
struct LanguagePicker: View {
    let title: String
    @Binding var selection: Language

    var body: some View {
        Menu {
            Picker(title, selection: $selection) {
                ForEach(Language.allCases) { lang in
                    Text("\(lang.code) — \(lang.displayName)").tag(lang)
                }
            }
        } label: {
            HStack(spacing: 6) {
                LanguageCodeBadge(language: selection, size: 22)
                Text(selection.displayName).font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.up.chevron.down").font(.caption2)
            }
            .foregroundStyle(Color.brandIndigo)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.brandIndigo.opacity(0.1)))
        }
    }
}

/// Read-only badge + name chip (used where the language is fixed, not editable).
struct LanguageBadge: View {
    let language: Language
    var body: some View {
        HStack(spacing: 5) {
            LanguageCodeBadge(language: language, size: 18)
            Text(language.displayName).font(.caption.weight(.semibold))
        }
        .foregroundStyle(Color.brandIndigo)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.brandIndigo.opacity(0.1)))
    }
}
