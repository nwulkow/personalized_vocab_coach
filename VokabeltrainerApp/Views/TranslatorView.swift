import SwiftUI

struct TranslatorView: View {
    @EnvironmentObject private var appState: AppState

    @State private var srcLanguage: Language = .german
    @State private var destLanguage: Language = .english
    @State private var sourceText = ""
    @State private var translatedText = ""
    @State private var isTranslating = false
    @State private var translationEngine: TranslationService.Engine = .google
    @State private var alternatives: [String] = []
    @State private var loadingAlternatives = false
    @State private var speakTranslation = false
    @State private var selectedTags: Set<String> = []
    @State private var newTagInput = ""
    @State private var autoTagLoading = false
    @State private var successMessage: String?
    @State private var errorMessage: String?
    @FocusState private var sourceFocused: Bool

    private var currentList: WordList { appState.wordList(for: srcLanguage, destLanguage) }
    private var availableTags: [String] { Array(Set(currentList.allTags).union(selectedTags)).sorted() }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                translationCard
                tagCard
                addButton
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Translator")
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Translation card

    private var translationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                LanguagePicker(title: "From", selection: $srcLanguage)
                Spacer()
                Button {
                    swapLanguages()
                } label: {
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.brandIndigo)
                }
                Spacer()
                LanguagePicker(title: "To", selection: $destLanguage)
            }

            TextEditor(text: $sourceText)
                .focused($sourceFocused)
                .frame(minHeight: 90)
                .padding(8)
                .padding(.trailing, sourceText.isEmpty ? 0 : 26)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.tertiarySystemGroupedBackground)))
                .overlay(alignment: .topLeading) {
                    if sourceText.isEmpty {
                        Text("Enter text to translate…")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 14).padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if !sourceText.isEmpty {
                        Button {
                            clearSourceText()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                    }
                }

            Button {
                sourceFocused = false
                Task { await translate() }
            } label: {
                if isTranslating {
                    ProgressView().tint(.white)
                } else {
                    Label("Translate", systemImage: "sparkles")
                }
            }
            .buttonStyle(PrimaryButtonStyle(isDisabled: sourceText.trimmingCharacters(in: .whitespaces).isEmpty || isTranslating))
            .disabled(sourceText.trimmingCharacters(in: .whitespaces).isEmpty || isTranslating)

            if !translatedText.isEmpty || isTranslating {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        SectionLabel(text: "Translation")
                        if !translatedText.isEmpty {
                            Text(translationEngine == .google ? "Google" : "Gemini")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            speakTranslation.toggle()
                            if speakTranslation { SpeechService.shared.speak(translatedText, language: destLanguage) }
                        } label: {
                            Image(systemName: speakTranslation ? "speaker.wave.2.fill" : "speaker.wave.2")
                        }
                        .foregroundStyle(Color.brandIndigo)
                    }
                    Text(translatedText.isEmpty ? " " : translatedText)
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.brandIndigo.opacity(0.08)))
                        .textSelection(.enabled)

                    HStack {
                        Button {
                            Task { await showAlternatives() }
                        } label: {
                            if loadingAlternatives {
                                ProgressView()
                            } else {
                                Label("Alternatives", systemImage: "wand.and.stars")
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(translatedText.isEmpty || loadingAlternatives)
                        Spacer()
                    }

                    if !alternatives.isEmpty {
                        FlowLayout(spacing: 6, lineSpacing: 6) {
                            ForEach(alternatives, id: \.self) { alt in
                                Button(alt) { translatedText = alt; alternatives = [] }
                                    .buttonStyle(ChipToggleStyle(isSelected: false))
                            }
                        }
                    }
                }
            }

            if let errorMessage {
                InlineBanner(text: errorMessage, kind: .error)
            }
        }
        .cardStyle()
    }

    // MARK: - Tag card

    private var tagCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: "Tags for this word")
                Spacer()
                Button {
                    Task { await autoTag() }
                } label: {
                    if autoTagLoading {
                        ProgressView()
                    } else {
                        Label("Auto-tag", systemImage: "sparkles")
                    }
                }
                .font(.caption.weight(.semibold))
                .disabled(sourceText.isEmpty || translatedText.isEmpty || autoTagLoading)
            }

            if !availableTags.isEmpty {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(availableTags, id: \.self) { tag in
                        Button(tag) { toggleTag(tag) }
                            .buttonStyle(ChipToggleStyle(isSelected: selectedTags.contains(tag)))
                    }
                }
            }

            HStack {
                TextField("New tag…", text: $newTagInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addNewTag() }
                Button("Add") { addNewTag() }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(newTagInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .cardStyle()
    }

    private var addButton: some View {
        VStack(spacing: 10) {
            if let successMessage {
                InlineBanner(text: successMessage, kind: .success)
            }
            Button {
                addWordToList()
            } label: {
                Label("Add to Word List", systemImage: "plus.circle.fill")
            }
            .buttonStyle(SuccessButtonStyle(isDisabled: sourceText.isEmpty || translatedText.isEmpty))
            .disabled(sourceText.isEmpty || translatedText.isEmpty)
        }
    }

    // MARK: - Actions

    private func clearSourceText() {
        sourceText = ""
        translatedText = ""
        alternatives = []
        errorMessage = nil
    }

    private func swapLanguages() {
        swap(&srcLanguage, &destLanguage)
        swap(&sourceText, &translatedText)
        alternatives = []
    }

    private func translate() async {
        errorMessage = nil
        isTranslating = true
        defer { isTranslating = false }
        do {
            let result = try await appState.translationService.translate(sourceText, from: srcLanguage, to: destLanguage)
            translatedText = result.text
            translationEngine = result.engine
            alternatives = []
            if speakTranslation { SpeechService.shared.speak(translatedText, language: destLanguage) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func showAlternatives() async {
        guard let gemini = appState.geminiService, !translatedText.isEmpty else { return }
        loadingAlternatives = true
        defer { loadingAlternatives = false }
        do {
            alternatives = try await gemini.showAlternatives(word: sourceText, src: srcLanguage, dest: destLanguage, googleTranslation: translatedText)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func autoTag() async {
        guard let gemini = appState.geminiService else {
            errorMessage = "Add a Gemini API key in Settings to auto-tag."
            return
        }
        autoTagLoading = true
        defer { autoTagLoading = false }
        do {
            let suggested = try await gemini.suggestTags(word1: sourceText, word2: translatedText, lang1: srcLanguage, lang2: destLanguage, existingTags: currentList.allTags)
            selectedTags.formUnion(suggested)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) { selectedTags.remove(tag) } else { selectedTags.insert(tag) }
    }

    private func addNewTag() {
        let raw = newTagInput.trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty else { return }
        for tag in raw.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces) }) where !tag.isEmpty {
            selectedTags.insert(tag)
        }
        newTagInput = ""
    }

    private func addWordToList() {
        let pair = WordPair(word1: sourceText.trimmingCharacters(in: .whitespaces), word2: translatedText.trimmingCharacters(in: .whitespaces), dateAdded: Date(), tags: Array(selectedTags).sorted())
        appState.addWordPair(pair, language1: srcLanguage, language2: destLanguage)
        let tagSuffix = selectedTags.isEmpty ? "" : " [\(selectedTags.sorted().joined(separator: ", "))]"
        successMessage = "Added “\(pair.word1)” → “\(pair.word2)”\(tagSuffix)"
        selectedTags = []
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            successMessage = nil
        }
    }
}

#Preview {
    NavigationStack { TranslatorView() }.environmentObject(AppState())
}
