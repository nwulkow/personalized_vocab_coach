import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    @Environment(\.openURL) private var openURL

    @State private var keyDraft = ""
    @State private var dropboxAppKeyDraft = ""
    @State private var pkce: DropboxAuth.PKCE?
    @State private var authCode = ""
    @State private var connectingDropbox = false
    @State private var verifyingKey = false
    @State private var keyStatus: KeyStatus = .unknown
    @State private var availableModels: [String] = []
    @State private var loadingModels = false
    @State private var modelsError: String?

    private enum KeyStatus: Equatable {
        case unknown, valid, invalid(String)
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Vokabeltrainer", systemImage: "graduationcap.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.brandIndigo)
                    Text("A personal vocabulary coach: translate, practice, and write. Translation uses Google Translate; Gemini powers the coaching features. Words you add here stay on this iPhone (with optional Dropbox sync).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section {
                SecureField("AIza…", text: $keyDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit(saveKey)

                HStack {
                    Button("Save") { saveKey() }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(keyDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button {
                        Task { await verifyKey() }
                    } label: {
                        if verifyingKey { ProgressView() } else { Text("Test") }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(!appState.hasAPIKey || verifyingKey)
                    Spacer()
                    statusBadge
                }

                Link(destination: URL(string: "https://aistudio.google.com/apikey")!) {
                    Label("Get a free Gemini API key", systemImage: "arrow.up.right.square")
                        .font(.footnote)
                }
            } header: {
                Text("Gemini API Key")
            } footer: {
                Text("Required for answer checking, example sentences, tag suggestions, alternative translations and writing feedback. Plain translation uses Google Translate and works without a key. No local model, no third-party server.")
            }

            Section {
                modelPicker(
                    title: "Regular",
                    subtitle: "Tagging, alternatives, writing feedback, word filtering",
                    selection: Binding(get: { appState.geminiRegularModel }, set: { appState.geminiRegularModel = $0 })
                )
                modelPicker(
                    title: "Fast",
                    subtitle: "Answer checking, example sentences",
                    selection: Binding(get: { appState.geminiFastModel }, set: { appState.geminiFastModel = $0 })
                )

                Button {
                    Task { await loadModels() }
                } label: {
                    if loadingModels {
                        HStack { ProgressView(); Text("Loading models…") }
                    } else {
                        Label(availableModels.isEmpty ? "Load available models" : "Refresh model list", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(!appState.hasAPIKey || loadingModels)

                if let modelsError {
                    InlineBanner(text: modelsError, kind: .warning)
                }

                Button("Reset to defaults") {
                    appState.geminiRegularModel = GeminiService.defaultRegularModel
                    appState.geminiFastModel = GeminiService.defaultFastModel
                }
                .font(.footnote)
            } header: {
                Text("Gemini Models")
            } footer: {
                Text("Defaults: \"\(GeminiService.defaultRegularModel)\" (regular) and \"\(GeminiService.defaultFastModel)\" (fast). Tap above to load the exact models your key can call and pick specific versions. If one model fails, the other is tried as a fallback.")
            }

            Section("Primary language") {
                Picker("Primary language", selection: Binding(
                    get: { appState.primaryLanguage },
                    set: { appState.primaryLanguage = $0 }
                )) {
                    ForEach(Language.allCases) { lang in
                        Text("\(lang.code) — \(lang.displayName)").tag(lang)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                if appState.isDropboxConnected {
                    HStack {
                        Label(
                            appState.dropboxRefreshToken.isEmpty ? "Connected (temporary token)" : "Connected",
                            systemImage: "checkmark.circle.fill"
                        )
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(appState.dropboxRefreshToken.isEmpty ? Color.brandAmber : Color.brandGreenDark)
                        Spacer()
                        Button("Disconnect", role: .destructive) {
                            appState.disconnectDropbox()
                            authCode = ""
                            pkce = nil
                        }
                        .font(.caption.weight(.semibold))
                    }

                    if appState.dropboxRefreshToken.isEmpty {
                        Text("This token expires about 4 hours after it was generated. Connect with the App key above for sync that keeps working.")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    Button {
                        Task { await appState.syncWithDropbox() }
                    } label: {
                        if appState.isSyncing {
                            HStack { ProgressView(); Text("Syncing…") }
                        } else {
                            Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(appState.isSyncing)
                } else {
                    TextField("App key", text: $dropboxAppKeyDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: dropboxAppKeyDraft) { _, new in appState.dropboxAppKey = new.trimmingCharacters(in: .whitespaces) }

                    Button {
                        startDropboxAuth()
                    } label: {
                        Label("Connect Dropbox", systemImage: "link")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(appState.dropboxAppKey.isEmpty)

                    if pkce != nil {
                        Text("Approve access in Safari, then paste the code Dropbox shows you:")
                            .font(.caption).foregroundStyle(.secondary)
                        HStack {
                            TextField("Authorization code", text: $authCode)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            Button {
                                Task { await finishDropboxAuth() }
                            } label: {
                                if connectingDropbox { ProgressView() } else { Text("Finish") }
                            }
                            .font(.subheadline.weight(.semibold))
                            .disabled(authCode.trimmingCharacters(in: .whitespaces).isEmpty || connectingDropbox)
                        }
                    }
                }

                if let syncError = appState.syncError {
                    InlineBanner(text: syncError, kind: .error)
                }
            } header: {
                Text("Dropbox Sync (optional)")
            } footer: {
                Text("Create an app at dropbox.com/developers/apps (Scoped access, with files.content.read/write and files.metadata.read/write permissions) and paste its App key here. Connecting once grants a refresh token that does not expire — unlike the App Console's \"Generated access token\", which dies after 4 hours. No redirect URI needs to be registered. Word lists are merged (union) with /Vokabeltrainer in your Dropbox; a sync never deletes anything.")
            }

            Section("Your word lists") {
                if appState.wordLists.isEmpty {
                    Text("No word lists yet").foregroundStyle(.secondary)
                } else {
                    ForEach(appState.wordLists) { list in
                        HStack {
                            Text(list.label)
                            Spacer()
                            Text("\(list.words.count)").foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            keyDraft = appState.geminiAPIKey
            dropboxAppKeyDraft = appState.dropboxAppKey
        }
    }

    private var statusBadge: some View {
        Group {
            switch keyStatus {
            case .unknown:
                EmptyView()
            case .valid:
                Label("Working", systemImage: "checkmark.circle.fill").foregroundStyle(Color.brandGreenDark)
            case .invalid(let msg):
                Label(msg, systemImage: "xmark.circle.fill").foregroundStyle(Color.brandRed)
            }
        }
        .font(.caption.weight(.semibold))
        .lineLimit(1)
    }

    /// Shows a menu of models fetched from the API when available; falls back to free-text
    /// entry before the list has been loaded (or if loading fails), so a model can always be set.
    @ViewBuilder
    private func modelPicker(title: String, subtitle: String, selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if availableModels.isEmpty {
                HStack {
                    Text(title).font(.subheadline.weight(.semibold))
                    Spacer()
                    TextField("model id", text: selection)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundStyle(.secondary)
                }
            } else {
                Picker(title, selection: selection) {
                    // Keep the stored value selectable even if the API didn't list it.
                    ForEach(optionsIncluding(selection.wrappedValue), id: \.self) { Text($0).tag($0) }
                }
            }
            Text(subtitle).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func optionsIncluding(_ current: String) -> [String] {
        availableModels.contains(current) ? availableModels : ([current] + availableModels)
    }

    private func loadModels() async {
        guard let gemini = appState.geminiService else { return }
        loadingModels = true
        modelsError = nil
        defer { loadingModels = false }
        do {
            let models = try await gemini.availableModels()
            if models.isEmpty {
                modelsError = "No usable models returned for this key."
            }
            availableModels = models
        } catch {
            modelsError = error.localizedDescription
        }
    }

    private func startDropboxAuth() {
        let generated = DropboxAuth.makePKCE()
        pkce = generated
        authCode = ""
        appState.syncError = nil
        if let url = DropboxAuth.authorizeURL(appKey: appState.dropboxAppKey, challenge: generated.challenge) {
            openURL(url)
        }
    }

    private func finishDropboxAuth() async {
        guard let pkce else { return }
        connectingDropbox = true
        defer { connectingDropbox = false }
        do {
            try await appState.completeDropboxAuth(code: authCode, verifier: pkce.verifier)
            self.pkce = nil
            authCode = ""
        } catch {
            appState.syncError = error.localizedDescription
        }
    }

    private func saveKey() {
        appState.geminiAPIKey = keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        keyStatus = .unknown
    }

    private func verifyKey() async {
        saveKey()
        guard let gemini = appState.geminiService else { return }
        verifyingKey = true
        defer { verifyingKey = false }
        do {
            try await gemini.verifyKey()
            keyStatus = .valid
        } catch {
            keyStatus = .invalid(error.localizedDescription)
        }
    }
}

#Preview {
    NavigationStack { SettingsView() }.environmentObject(AppState())
}
