# 🎓 Vokabeltrainer for iPhone

A native SwiftUI port of the Vokabeltrainer Vue/FastAPI app. It's a standalone iPhone app —
no backend server required. Word lists live on the phone (CSV, same format the desktop app
uses). Translation uses **Google Translate**; the coaching features (answer checking, example
sentences, tagging, writing feedback) use the **Gemini API**. There is no local/Ollama model
support in this app by design.

## Features

| Tab | What it does |
|---|---|
| **Translate** | Free-text translation between German/English/Spanish/French via Google Translate, AI alternative translations, AI tag suggestions, add-to-word-list |
| **Practice** | Vocabulary testing: samples words from a list, optionally turns short words into example sentences at a chosen CEFR level, checks your answer with Gemini (with an offline exact-match fallback), tag/date/description filters, speaks words aloud |
| **Word Lists** | View, edit, tag, add, and delete word pairs for every language pair; create new language-pair lists |
| **Writing** | Samples a few words and asks you to write a short text using them; Gemini gives feedback at Basic/Intermediate/Advanced strictness |
| **Settings** | Gemini API key, **Gemini model choice (regular + fast)**, primary language, optional Dropbox sync, word list overview |

## Getting started

1. Open `VokabeltrainerApp.xcodeproj` in Xcode 16 or later.
2. Select your Team under the target's *Signing & Capabilities* tab (needed to run on a
   physical iPhone; the Simulator works without one).
3. Build & run onto your iPhone or the Simulator.
4. In the app, go to **Settings → Gemini API Key**, paste a key from
   [Google AI Studio](https://aistudio.google.com/apikey) (free tier available), and tap
   **Test** to confirm it works.

The app ships with your existing starter word lists (copied from `word_lists/*.csv` in the
main repo) so it isn't empty on first launch — everything from there on is stored locally in
the app's Documents folder and never touches those original files again.

## Architecture

```
VokabeltrainerApp/
├── VokabeltrainerApp.swift      # @main entry point
├── Models/                      # Language, WordPair, WordList (CSV codec), AppState
├── Services/
│   ├── TranslationService.swift # Google Translate (primary) with Gemini as fallback
│   ├── DropboxAuth.swift        # OAuth 2 PKCE → non-expiring refresh token
│   ├── GeminiService.swift      # Coaching AI features; configurable regular/fast models
│   ├── WordListStorage.swift    # CSV persistence in Documents/word_lists, first-run seeding
│   ├── DropboxService.swift     # Optional cross-device sync (token-based, no OAuth flow)
│   └── SpeechService.swift      # On-device AVSpeechSynthesizer wrapper
├── Views/                       # One SwiftUI view per tab, plus small shared components
├── Utilities/                   # Brand colors, button styles, a wrapping FlowLayout
└── Resources/word_lists/        # Bundled starter CSVs (first-run seed only)
```

Nothing here depends on the Python backend or the Vue frontend — this is a fully independent
client. Word lists round-trip as the same `Language1,Language2,date_added,tags` CSV format the
backend uses, so files can still be hand-edited or shared via Dropbox/AirDrop if you want.

## Dropbox sync setup (optional)

Sync is off until you connect it. One-time setup:

1. Create an app at [dropbox.com/developers/apps](https://www.dropbox.com/developers/apps) —
   choose **Scoped access**, then either **App folder** or **Full Dropbox**.
2. On the **Permissions** tab enable `files.metadata.read`, `files.metadata.write`,
   `files.content.read`, `files.content.write`, and click Submit.
3. Copy the **App key** from the Settings tab into the app's Settings → Dropbox section.
4. Tap **Connect Dropbox** → approve in Safari → paste the code Dropbox displays → **Finish**.

**No redirect URI needs to be registered**, and the app secret is never needed or stored —
the flow uses PKCE, and omitting `redirect_uri` makes Dropbox show the code on screen.

Deliberately *not* used: the App Console's "Generated access token" button. Those tokens are
short-lived (`sl.…`, ~4 hours) and long-lived tokens have been deprecated since 2021, so
pasting one would mean re-pasting a new one every few hours. The PKCE flow above returns a
**refresh token that does not expire**, and the app mints fresh access tokens from it
automatically. (You *can* still paste a short-lived token manually for a quick test — the UI
labels that state "Connected (temporary token)".)

> Full Dropbox access syncs to `/Vokabeltrainer`. If you picked **App folder** instead, that
> path is relative to your app's own folder, so adjust `remotePath` in `AppState.syncWithDropbox()`.

## Design notes / intentional differences from the desktop app

- **No local models.** The desktop app could fall back to a local Ollama/llama.cpp model; this
  app never does. Without an API key, the Gemini-backed features are disabled with an inline
  prompt to add one in Settings, and answer-checking falls back to a plain normalized string
  comparison so testing still works offline.
- **Translation is Google, not Gemini.** `TranslationService` calls the same free
  `translate.googleapis.com/translate_a/single` endpoint that the backend's `googletrans`
  dependency wraps — no API key needed. Gemini is only used if Google is unreachable. This
  also applies to the example sentences generated during testing: Gemini writes the sentence,
  Google translates it.
- **Both Gemini models are configurable** in Settings (regular + fast). Settings can fetch the
  live model list from your key via the `ListModels` endpoint, so the options are real models
  rather than a hardcoded list that goes stale. If one model errors, the other is tried.
- **SF Symbols instead of emoji** in UI chrome — emoji rendering varies by font/platform
  (several rendered as `?` boxes in the Simulator), SF Symbols never do.
- **Voice is real here.** The desktop app's "speak" checkboxes played audio through the
  *server's* speakers via `pyttsx3` — not useful for a remote client. Here, "read aloud" uses
  `AVSpeechSynthesizer` on-device.
- **Flags are code badges.** Regional-indicator flag emoji render inconsistently across fonts
  and imply one country per language, so language pickers use a plain "DE/EN/ES/FR" badge
  instead.
