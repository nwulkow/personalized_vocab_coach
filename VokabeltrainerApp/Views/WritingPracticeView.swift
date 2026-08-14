import SwiftUI

struct WritingPracticeView: View {
    @EnvironmentObject private var appState: AppState
    @FocusState private var textFocused: Bool

    @State private var practiceLanguage: Language = .english
    @State private var level = "Intermediate"
    @State private var wordsPerTask: Double = 2
    @State private var description = ""
    @State private var useStartDate = false
    @State private var startDate = Date()
    @State private var useEndDate = false
    @State private var endDate = Date()
    @State private var selectedTags: Set<String> = []
    @State private var tagFilterMode: TagFilterMode = .include
    @State private var tagMatchMode: TagMatchMode = .any

    @State private var sessionActive = false
    @State private var round = 1
    @State private var currentWords: [(word: String, translation: String)] = []
    @State private var userText = ""
    @State private var feedback = ""
    @State private var submitting = false
    @State private var loadingNextWords = false
    @State private var setupError: String?
    @State private var sessionError: String?

    private let levels = ["Basic", "Intermediate", "Advanced"]

    private var primaryLanguage: Language { appState.primaryLanguage }
    private var currentList: WordList { appState.wordList(for: primaryLanguage, practiceLanguage) }
    private var feedbackIsClean: Bool { feedback.lowercased().hasPrefix("no mistakes") }

    var body: some View {
        Group {
            if sessionActive { sessionView } else { setupView }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Writing Practice")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Setup

    private var setupView: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Writing Practice", systemImage: "pencil.and.outline")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.brandIndigo)
                    Text("Get words sampled from your \(primaryLanguage.displayName) ↔ \(practiceLanguage.displayName) list and write a short text using them. Gemini gives instant feedback.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        SectionLabel(text: "Practice language")
                        Spacer()
                        LanguagePicker(title: "Language", selection: $practiceLanguage)
                    }
                    Picker("Feedback level", selection: $level) {
                        ForEach(levels, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.segmented)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Words per task: \(Int(wordsPerTask))").font(.subheadline)
                        Slider(value: $wordsPerTask, in: 1...6, step: 1).tint(.brandIndigo)
                    }
                }
                .cardStyle()

                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "Filters")
                    TextField("Word filter description (optional)", text: $description)
                        .textFieldStyle(.roundedBorder)
                    Toggle("From date", isOn: $useStartDate.animation())
                    if useStartDate { DatePicker("", selection: $startDate, displayedComponents: .date).labelsHidden() }
                    Toggle("To date", isOn: $useEndDate.animation())
                    if useEndDate { DatePicker("", selection: $endDate, displayedComponents: .date).labelsHidden() }
                    Divider()
                    TagFilterBar(availableTags: currentList.allTags, selectedTags: $selectedTags, filterMode: $tagFilterMode, matchMode: $tagMatchMode)
                }
                .cardStyle()

                if let setupError {
                    InlineBanner(text: setupError, kind: .error)
                }

                Button {
                    Task { await startSession() }
                } label: {
                    Label("Start Writing Practice", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle(isDisabled: currentList.words.isEmpty))
                .disabled(currentList.words.isEmpty)

                if currentList.words.isEmpty {
                    InlineBanner(text: "This word list is empty — add words in the Translator tab first.", kind: .warning)
                }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func sampleWords() async throws -> [(word: String, translation: String)] {
        let list = currentList
        var pairs = list.words.filter { !$0.word1.trimmingCharacters(in: .whitespaces).isEmpty && !$0.word2.trimmingCharacters(in: .whitespaces).isEmpty }
        if useStartDate { pairs = pairs.filter { $0.dateAdded >= Calendar.current.startOfDay(for: startDate) } }
        if useEndDate {
            let end = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: endDate)) ?? endDate
            pairs = pairs.filter { $0.dateAdded < end }
        }
        pairs = applyTagFilter(pairs, tags: { $0.tags }, selected: selectedTags, mode: tagFilterMode, match: tagMatchMode)

        var items = pairs.map { list.words($0, from: practiceLanguage) }

        let trimmedDescription = description.trimmingCharacters(in: .whitespaces)
        if !trimmedDescription.isEmpty, let gemini = appState.geminiService {
            let filtered = try await gemini.filterWords(items.map(\.0), description: trimmedDescription)
            if !filtered.isEmpty {
                let filteredSet = Set(filtered)
                items = items.filter { filteredSet.contains($0.0) }
            }
        }

        guard !items.isEmpty else { throw PracticeError.noWords }
        let n = min(Int(wordsPerTask), items.count)
        return Array(items.shuffled().prefix(n)).map { (word: $0.0, translation: $0.1) }
    }

    private func startSession() async {
        setupError = nil
        do {
            currentWords = try await sampleWords()
            round = 1
            userText = ""
            feedback = ""
            sessionActive = true
            textFocused = true
        } catch {
            setupError = (error as? PracticeError)?.message ?? error.localizedDescription
        }
    }

    // MARK: - Session

    private var sessionView: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Label("Round \(round)", systemImage: "pencil.and.outline").font(.headline)
                    Spacer()
                    Button("End") { sessionActive = false }.buttonStyle(SecondaryButtonStyle())
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Write a text in **\(practiceLanguage.displayName)** that uses:")
                        .font(.subheadline)
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(currentWords, id: \.word) { item in
                            VStack(spacing: 2) {
                                Text(item.word).font(.headline)
                                Text(item.translation).font(.caption2).foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color(.tertiarySystemGroupedBackground)))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.brandIndigo.opacity(0.4), lineWidth: 1.5))
                        }
                    }
                }
                .cardStyle()

                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: $userText)
                        .focused($textFocused)
                        .frame(minHeight: 140)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.tertiarySystemGroupedBackground)))
                        .disabled(submitting)

                    HStack {
                        Button {
                            Task { await nextRound() }
                        } label: {
                            if loadingNextWords { ProgressView() } else { Label("Next words", systemImage: "arrow.triangle.2.circlepath") }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(loadingNextWords)

                        Spacer()

                        if submitting {
                            ProgressView().padding(.trailing, 8)
                        }
                        Button {
                            Task { await submit() }
                        } label: {
                            Label("Submit", systemImage: "paperplane.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle(isDisabled: userText.trimmingCharacters(in: .whitespaces).isEmpty || submitting))
                        .disabled(userText.trimmingCharacters(in: .whitespaces).isEmpty || submitting)
                        .fixedSize()
                    }
                }
                .cardStyle()

                if !feedback.isEmpty {
                    feedbackCard
                }

                if let sessionError {
                    InlineBanner(text: sessionError, kind: .error)
                }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var feedbackCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(
                    feedbackIsClean ? "Great job!" : "Feedback",
                    systemImage: feedbackIsClean ? "checkmark.seal.fill" : "text.badge.checkmark"
                )
                .font(.headline)
                .foregroundStyle(feedbackIsClean ? Color.brandGreenDark : Color.primary)
                Spacer()
                Text(level).font(.caption2.weight(.semibold)).padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color.black.opacity(0.06)))
            }
            Text((try? AttributedString(markdown: feedback)) ?? AttributedString(feedback))
                .font(.subheadline)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(feedbackIsClean ? Color.brandGreenDark.opacity(0.12) : Color.brandAmber.opacity(0.15)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(feedbackIsClean ? Color.brandGreenDark.opacity(0.4) : Color.brandAmber.opacity(0.5), lineWidth: 1))
    }

    private func nextRound() async {
        loadingNextWords = true
        sessionError = nil
        defer { loadingNextWords = false }
        do {
            currentWords = try await sampleWords()
            round += 1
            userText = ""
            feedback = ""
        } catch {
            sessionError = (error as? PracticeError)?.message ?? error.localizedDescription
        }
    }

    private func submit() async {
        guard let gemini = appState.geminiService else {
            sessionError = "Add a Gemini API key in Settings to get feedback."
            return
        }
        submitting = true
        sessionError = nil
        feedback = ""
        defer { submitting = false }
        do {
            feedback = try await gemini.evaluateText(text: userText, words: currentWords.map(\.word), language: practiceLanguage, level: level)
        } catch {
            sessionError = error.localizedDescription
        }
    }

    private enum PracticeError: Error {
        case noWords
        var message: String {
            switch self {
            case .noWords: return "No words match your filters."
            }
        }
    }
}

#Preview {
    NavigationStack { WritingPracticeView() }.environmentObject(AppState())
}
