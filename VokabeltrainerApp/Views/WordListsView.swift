import SwiftUI

struct WordListsView: View {
    @EnvironmentObject private var appState: AppState

    @State private var selectedListID: String?
    @State private var editedWords: [WordPair] = []
    @State private var saveMessage: String?
    @State private var showingNewListSheet = false
    @State private var showingDeleteConfirm = false

    private var selectedList: WordList? {
        appState.wordLists.first { $0.id == selectedListID }
    }

    var body: some View {
        VStack(spacing: 0) {
            if appState.wordLists.isEmpty {
                emptyState
            } else {
                header
                Divider()
                editorList
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Word Lists")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingNewListSheet = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingNewListSheet) {
            NewWordListSheet { list in
                appState.save(list)
                selectedListID = list.id
                loadEditedWords()
            }
        }
        .confirmationDialog("Delete this word list?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let list = selectedList {
                    appState.deleteList(list)
                    selectedListID = appState.wordLists.first?.id
                    loadEditedWords()
                }
            }
        }
        .onAppear {
            if selectedListID == nil { selectedListID = appState.wordLists.first?.id }
            loadEditedWords()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "list.bullet.rectangle").font(.system(size: 44)).foregroundStyle(.secondary)
            Text("No word lists yet").font(.headline)
            Text("Create one, or add a word from the Translator tab.").font(.subheadline).foregroundStyle(.secondary)
            Button("New Word List") { showingNewListSheet = true }.buttonStyle(PrimaryButtonStyle())
        }
        .multilineTextAlignment(.center)
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack {
            Menu {
                ForEach(appState.wordLists) { list in
                    Button {
                        selectedListID = list.id
                        loadEditedWords()
                    } label: {
                        if list.id == selectedListID {
                            Label(list.label, systemImage: "checkmark")
                        } else {
                            Text(list.label)
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selectedList?.label ?? "Select list")
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "chevron.up.chevron.down").font(.caption2)
                }
                .foregroundStyle(Color.brandIndigo)
            }
            Spacer()
            Text("\(editedWords.count) words").font(.caption).foregroundStyle(.secondary)
            Button(role: .destructive) { showingDeleteConfirm = true } label: {
                Image(systemName: "trash").foregroundStyle(Color.brandRed)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var editorList: some View {
        VStack(spacing: 0) {
            List {
                ForEach($editedWords) { $word in
                    WordRowEditor(word: $word, lang1: selectedList?.lang1Col ?? "", lang2: selectedList?.lang2Col ?? "", existingTags: selectedList?.allTags ?? [])
                }
                .onDelete { editedWords.remove(atOffsets: $0) }
            }
            .listStyle(.plain)

            VStack(spacing: 10) {
                if let saveMessage {
                    InlineBanner(text: saveMessage, kind: .success)
                }
                HStack(spacing: 10) {
                    Button {
                        addRow()
                    } label: {
                        Label("Add Word", systemImage: "plus")
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button {
                        saveChanges()
                    } label: {
                        Label("Save", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(SuccessButtonStyle())
                }
            }
            .padding(16)
            .background(.bar)
        }
    }

    private func loadEditedWords() {
        editedWords = selectedList?.words ?? []
        saveMessage = nil
    }

    private func addRow() {
        editedWords.append(WordPair(word1: "", word2: "", dateAdded: Date(), tags: []))
    }

    private func saveChanges() {
        guard var list = selectedList else { return }
        let valid = editedWords.filter {
            !$0.word1.trimmingCharacters(in: .whitespaces).isEmpty && !$0.word2.trimmingCharacters(in: .whitespaces).isEmpty
        }
        list.words = valid
        appState.save(list)
        editedWords = valid
        saveMessage = "Saved \(valid.count) word pairs."
        Task {
            try? await Task.sleep(for: .seconds(2))
            saveMessage = nil
        }
    }
}

// MARK: - Row

private struct WordRowEditor: View {
    @Binding var word: WordPair
    let lang1: String
    let lang2: String
    let existingTags: [String]

    @State private var newTag = ""
    @FocusState private var tagFieldFocused: Bool

    /// All tags not already on this word, narrowed by whatever's typed. Empty query (including
    /// just having tapped into the field) shows every remaining tag, not only prefix matches.
    private var suggestions: [String] {
        let remaining = existingTags.filter { !word.tags.contains($0) }
        let query = newTag.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return remaining }
        return remaining.filter { $0.lowercased().hasPrefix(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField(lang1, text: $word.word1)
                    .textFieldStyle(.roundedBorder)
                TextField(lang2, text: $word.word2)
                    .textFieldStyle(.roundedBorder)
            }

            if !word.tags.isEmpty {
                FlowLayout(spacing: 4, lineSpacing: 4) {
                    ForEach(word.tags, id: \.self) { tag in
                        HStack(spacing: 3) {
                            Text(tag)
                            Button { word.tags.removeAll { $0 == tag } } label: {
                                Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                            }
                        }
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Color.brandIndigo.opacity(0.12)))
                        .foregroundStyle(Color.brandIndigo)
                    }
                }
            }

            HStack(spacing: 6) {
                TextField("Add tag…", text: $newTag)
                    .font(.caption)
                    .textFieldStyle(.roundedBorder)
                    .focused($tagFieldFocused)
                    .onSubmit(addTypedTag)
                Button("Add", action: addTypedTag)
                    .font(.caption.weight(.semibold))
                    .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)

                Spacer()
                Text(word.dateAdded, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Shown while the field is focused (tap in to browse every remaining tag) and
            // narrowed as you type. Tapping a chip doesn't clear focus, so you can add several
            // tags in a row without the panel disappearing after each one.
            if tagFieldFocused, !suggestions.isEmpty {
                FlowLayout(spacing: 4, lineSpacing: 4) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(suggestion) { addTag(suggestion) }
                            .font(.caption2)
                            .buttonStyle(ChipToggleStyle(isSelected: false))
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// Adds one tag (from a suggestion tap or matched exactly) without touching `newTag`'s
    /// focus, so the suggestion panel stays open for adding more.
    private func addTag(_ tag: String) {
        guard !word.tags.contains(tag) else { return }
        word.tags.append(tag)
        newTag = ""
    }

    /// Adds whatever's typed (supports comma-separated multiple tags) via the Add button/Return key.
    private func addTypedTag() {
        let raw = newTag.trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty else { return }
        for t in raw.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces) }) where !t.isEmpty && !word.tags.contains(t) {
            word.tags.append(t)
        }
        newTag = ""
    }
}

// MARK: - New list sheet

private struct NewWordListSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let onCreate: (WordList) -> Void

    @State private var lang1: Language = .german
    @State private var lang2: Language = .english

    private var alreadyExists: Bool {
        appState.wordLists.contains { $0.matches(lang1, lang2) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Language pair") {
                    Picker("First language", selection: $lang1) {
                        ForEach(Language.allCases) { Text("\($0.code) — \($0.displayName)").tag($0) }
                    }
                    Picker("Second language", selection: $lang2) {
                        ForEach(Language.allCases) { Text("\($0.code) — \($0.displayName)").tag($0) }
                    }
                }
                if lang1 == lang2 {
                    InlineBanner(text: "Pick two different languages.", kind: .warning)
                } else if alreadyExists {
                    InlineBanner(text: "This word list already exists.", kind: .warning)
                }
            }
            .navigationTitle("New Word List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(WordList(language1: lang1, language2: lang2, words: []))
                        dismiss()
                    }
                    .disabled(lang1 == lang2 || alreadyExists)
                }
            }
        }
    }
}

#Preview {
    NavigationStack { WordListsView() }.environmentObject(AppState())
}
