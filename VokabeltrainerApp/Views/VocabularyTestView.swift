import SwiftUI

// MARK: - Session engine

/// Drives one vocabulary-test run: word sampling, recently-used/hide-correct bookkeeping,
/// optional sentence generation, and answer checking. Kept separate from the View so the
/// (fairly intricate) sampling logic reads clearly on its own.
@MainActor
final class VocabTestSession: ObservableObject {
    struct TestCandidate: Identifiable {
        let id: UUID
        let prompt: String   // word in the start language
        let answer: String   // word in the target language
    }

    struct Displayed {
        let candidateId: UUID
        let promptText: String
        let answerText: String
        let originalWord: String
    }

    @Published var isActive = false
    @Published var loading = false
    @Published var loadingMessage = "Loading next word…"
    @Published var current: Displayed?
    @Published var userAnswer = ""
    @Published var answerSubmitted = false
    @Published var isCorrect = false
    @Published var checking = false
    @Published var correctCount = 0
    @Published var incorrectCount = 0
    @Published var remainingCount = 0
    @Published var errorMessage: String?

    private var pool: [TestCandidate] = []
    private var recentIds: [UUID] = []
    private var correctIds: Set<UUID> = []

    private var start: Language = .german
    private var target: Language = .english
    private var probability: Double = 0
    private var maxWords: Int = 10
    private var level: String = "C1"
    private var remark: String?
    private var hideUsedForN: Int = 4
    private var hideCorrect = true
    private var beStringent = false
    private var useVoice = false
    private var gemini: GeminiService?
    private var translator: TranslationService?

    func start(candidates: [TestCandidate], start: Language, target: Language, probability: Double, maxWords: Int, level: String, remark: String?, hideUsedForN: Int, hideCorrect: Bool, beStringent: Bool, useVoice: Bool, gemini: GeminiService?, translator: TranslationService?) async {
        pool = candidates
        self.start = start
        self.target = target
        self.probability = probability
        self.maxWords = maxWords
        self.level = level
        self.remark = remark
        self.hideUsedForN = hideUsedForN
        self.hideCorrect = hideCorrect
        self.beStringent = beStringent
        self.useVoice = useVoice
        self.gemini = gemini
        self.translator = translator
        recentIds = []
        correctIds = []
        correctCount = 0
        incorrectCount = 0
        errorMessage = nil
        isActive = true
        await nextWord()
    }

    func end() {
        isActive = false
        current = nil
        pool = []
    }

    func nextWord() async {
        userAnswer = ""
        answerSubmitted = false
        isCorrect = false
        errorMessage = nil

        if hideCorrect {
            pool.removeAll { correctIds.contains($0.id) }
        }
        remainingCount = pool.count
        guard !pool.isEmpty else { current = nil; return }

        loading = true
        loadingMessage = "Loading next word…"
        defer { loading = false }

        let recentSet = Set(recentIds.suffix(max(hideUsedForN, 0)))
        var candidates = pool.filter { !recentSet.contains($0.id) }
        if candidates.isEmpty { candidates = pool }
        guard let picked = candidates.randomElement() else { current = nil; return }

        recentIds.append(picked.id)
        if recentIds.count > max(hideUsedForN, 1) * 4 {
            recentIds.removeFirst(recentIds.count - max(hideUsedForN, 1) * 4)
        }

        var promptText = picked.prompt
        var answerText = picked.answer
        let wordCount = picked.prompt.split(separator: " ").count

        if wordCount < 3, Double.random(in: 0...1) < probability, let gemini {
            loadingMessage = "Creating an example sentence…"
            do {
                // Gemini writes the sentence; Google Translate renders it in the target language.
                let sentence = try await gemini.createSentence(
                    word: picked.prompt, language: start,
                    maxWords: maxWords, level: level, remark: remark
                )
                let translation = try await translator?.translatedText(sentence, from: start, to: target) ?? ""
                if !sentence.isEmpty, !translation.isEmpty {
                    promptText = sentence
                    answerText = translation
                }
            } catch {
                // Silently fall back to the plain word — a missed sentence isn't worth stopping the test.
            }
        }

        current = Displayed(candidateId: picked.id, promptText: promptText, answerText: answerText, originalWord: picked.prompt)
        if useVoice {
            SpeechService.shared.speak(promptText, language: start)
        }
    }

    func checkAnswer() async {
        guard let current, !userAnswer.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        answerSubmitted = true
        checking = true
        defer { checking = false }

        do {
            if let gemini {
                isCorrect = try await gemini.checkEquality(userAnswer: userAnswer, correctAnswer: current.answerText, beStringent: beStringent)
            } else {
                isCorrect = GeminiService.quickEquals(userAnswer, current.answerText)
            }
        } catch {
            isCorrect = GeminiService.quickEquals(userAnswer, current.answerText)
            errorMessage = "Couldn't reach Gemini, compared offline instead."
        }

        if isCorrect {
            correctCount += 1
            correctIds.insert(current.candidateId)
        } else {
            incorrectCount += 1
        }
    }
}

// MARK: - View

struct VocabularyTestView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var session = VocabTestSession()
    @FocusState private var answerFocused: Bool

    @State private var startLanguage: Language = .german
    @State private var targetLanguage: Language = .english
    @State private var probability: Double = 0.6
    @State private var maxWords: Double = 10
    @State private var level = "C1"
    @State private var remark = ""
    @State private var description = ""
    @State private var useStartDate = false
    @State private var startDate = Date()
    @State private var useEndDate = false
    @State private var endDate = Date()
    @State private var selectedTags: Set<String> = []
    @State private var tagFilterMode: TagFilterMode = .include
    @State private var tagMatchMode: TagMatchMode = .any
    @State private var hideCorrect = true
    @State private var beStringent = false
    @State private var useVoice = false
    @State private var startError: String?
    @State private var starting = false

    private let levels = ["A1", "A2", "B1", "B2", "C1", "C2"]

    private var currentList: WordList { appState.wordList(for: startLanguage, targetLanguage) }

    var body: some View {
        Group {
            if session.isActive {
                sessionView
            } else {
                setupView
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Practice")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Setup

    private var setupView: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        LanguagePicker(title: "From", selection: $startLanguage)
                        Image(systemName: "arrow.right").foregroundStyle(.secondary)
                        LanguagePicker(title: "To", selection: $targetLanguage)
                        Spacer()
                        Text("\(currentList.words.count) words")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    if startLanguage == targetLanguage {
                        InlineBanner(text: "Choose two different languages.", kind: .warning)
                    }
                }
                .cardStyle()

                VStack(alignment: .leading, spacing: 14) {
                    SectionLabel(text: "Sentence generation")
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sentence probability: \(Int(probability * 100))%").font(.subheadline)
                        Slider(value: $probability, in: 0...1, step: 0.05).tint(.brandIndigo)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Max words in sentence: \(Int(maxWords))").font(.subheadline)
                        Slider(value: $maxWords, in: 4...20, step: 1).tint(.brandIndigo)
                    }
                    Picker("Language level", selection: $level) {
                        ForEach(levels, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.segmented)
                    TextField("Remark (optional), e.g. 'formal register'", text: $remark)
                        .textFieldStyle(.roundedBorder)
                }
                .cardStyle()

                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "Filters")
                    TextField("Word filter description (optional)", text: $description)
                        .textFieldStyle(.roundedBorder)

                    Toggle("From date", isOn: $useStartDate.animation())
                    if useStartDate {
                        DatePicker("", selection: $startDate, displayedComponents: .date).labelsHidden()
                    }
                    Toggle("To date", isOn: $useEndDate.animation())
                    if useEndDate {
                        DatePicker("", selection: $endDate, displayedComponents: .date).labelsHidden()
                    }

                    Divider()

                    TagFilterBar(availableTags: currentList.allTags, selectedTags: $selectedTags, filterMode: $tagFilterMode, matchMode: $tagMatchMode)
                }
                .cardStyle()

                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Hide correctly answered words", isOn: $hideCorrect)
                    Toggle("Be stringent when checking answers", isOn: $beStringent)
                    Toggle("Read words aloud", isOn: $useVoice)
                }
                .cardStyle()

                if let startError {
                    InlineBanner(text: startError, kind: .error)
                }

                Button {
                    Task { await startTest() }
                } label: {
                    if starting {
                        ProgressView().tint(.white)
                    } else {
                        Label("Start Test", systemImage: "play.fill")
                    }
                }
                .buttonStyle(PrimaryButtonStyle(isDisabled: startLanguage == targetLanguage || currentList.words.isEmpty || starting))
                .disabled(startLanguage == targetLanguage || currentList.words.isEmpty || starting)

                if currentList.words.isEmpty {
                    InlineBanner(text: "This word list is empty — add words in the Translator tab first.", kind: .warning)
                }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func startTest() async {
        startError = nil
        starting = true
        defer { starting = false }

        let list = currentList
        var pairs = list.words.filter { !$0.word1.trimmingCharacters(in: .whitespaces).isEmpty && !$0.word2.trimmingCharacters(in: .whitespaces).isEmpty }
        if useStartDate { pairs = pairs.filter { $0.dateAdded >= Calendar.current.startOfDay(for: startDate) } }
        if useEndDate {
            let end = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: endDate)) ?? endDate
            pairs = pairs.filter { $0.dateAdded < end }
        }
        pairs = applyTagFilter(pairs, tags: { $0.tags }, selected: selectedTags, mode: tagFilterMode, match: tagMatchMode)

        guard !pairs.isEmpty else {
            startError = "No words match your filters."
            return
        }

        var candidates = pairs.map { pair -> VocabTestSession.TestCandidate in
            let (p, a) = list.words(pair, from: startLanguage)
            return .init(id: pair.id, prompt: p, answer: a)
        }

        let trimmedDescription = description.trimmingCharacters(in: .whitespaces)
        if !trimmedDescription.isEmpty, let gemini = appState.geminiService {
            do {
                let filtered = try await gemini.filterWords(candidates.map(\.prompt), description: trimmedDescription)
                if !filtered.isEmpty {
                    let filteredSet = Set(filtered)
                    candidates = candidates.filter { filteredSet.contains($0.prompt) }
                }
            } catch {
                startError = "Description filter failed (using full list): \(error.localizedDescription)"
            }
        }

        await session.start(
            candidates: candidates, start: startLanguage, target: targetLanguage,
            probability: probability, maxWords: Int(maxWords), level: level,
            remark: remark.isEmpty ? nil : remark, hideUsedForN: 4,
            hideCorrect: hideCorrect, beStringent: beStringent, useVoice: useVoice,
            gemini: appState.geminiService, translator: appState.translationService
        )
    }

    // MARK: - Session

    private var sessionView: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    HStack(spacing: 6) {
                        LanguageCodeBadge(language: startLanguage, size: 26)
                        Image(systemName: "arrow.right").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                        LanguageCodeBadge(language: targetLanguage, size: 26)
                    }
                    Spacer()
                    Text("\(session.remainingCount) left")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.brandIndigo)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(Color.brandIndigo.opacity(0.1)))
                    Button("End") { session.end() }
                        .buttonStyle(SecondaryButtonStyle())
                }

                if session.loading {
                    VStack(spacing: 10) {
                        ProgressView()
                        Text(session.loadingMessage).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                } else if let current = session.current {
                    wordCard(current)
                } else {
                    VStack(spacing: 14) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.brandGreenDark)
                        Text("No words left for this test!").font(.headline)
                        Button("Back to Setup") { session.end() }.buttonStyle(PrimaryButtonStyle())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                }

                statsRow
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func wordCard(_ current: VocabTestSession.Displayed) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text(startLanguage.displayName.uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.brandIndigo)
                Text(highlighted(current.promptText, word: current.originalWord))
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: [Color.brandIndigo.opacity(0.12), Color.brandPurple.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)))

            if !session.answerSubmitted {
                VStack(spacing: 10) {
                    TextField("Your \(targetLanguage.displayName) translation…", text: $session.userAnswer)
                        .textFieldStyle(.roundedBorder)
                        .focused($answerFocused)
                        .submitLabel(.done)
                        .onSubmit { Task { await session.checkAnswer() } }
                        .onAppear { answerFocused = true }

                    Button {
                        Task { await session.checkAnswer() }
                    } label: {
                        Label("Check Answer", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle(isDisabled: session.userAnswer.trimmingCharacters(in: .whitespaces).isEmpty))
                    .disabled(session.userAnswer.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } else {
                VStack(spacing: 12) {
                    if session.checking {
                        Label("Checking…", systemImage: "hourglass").font(.headline).foregroundStyle(.secondary)
                    } else {
                        Label(session.isCorrect ? "Correct!" : "Incorrect", systemImage: session.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(session.isCorrect ? Color.brandGreenDark : Color.brandRed)
                        Text("Correct answer: \(current.answerText)")
                            .font(.subheadline)
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color(.tertiarySystemGroupedBackground)))

                        if let err = session.errorMessage {
                            InlineBanner(text: err, kind: .warning)
                        }

                        Button {
                            Task { await session.nextWord() }
                        } label: {
                            Label("Next Word", systemImage: "arrow.right.circle.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }
            }
        }
        .cardStyle()
    }

    private func highlighted(_ sentence: String, word: String) -> AttributedString {
        var attributed = AttributedString(sentence)
        guard sentence != word, let range = attributed.range(of: word, options: .caseInsensitive) else { return attributed }
        attributed[range].underlineStyle = .single
        attributed[range].foregroundColor = .brandIndigo
        return attributed
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            statTile("Correct", session.correctCount, .brandGreenDark)
            statTile("Incorrect", session.incorrectCount, .brandRed)
            statTile("Total", session.correctCount + session.incorrectCount, .brandIndigo)
        }
        .cardStyle()
    }

    private func statTile(_ label: String, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)").font(.title3.weight(.bold)).foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack { VocabularyTestView() }.environmentObject(AppState())
}
