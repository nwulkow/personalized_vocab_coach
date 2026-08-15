# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A vocabulary trainer that exists as **two independent clients over the same CSV data format**:

1. **Python/FastAPI backend + Vue 3 frontend** (`api/`, `vokabel-app/`, plus the Python modules at the repo root) — the desktop app. Can use a *local* LLM (Ollama or llama.cpp) or *cloud* Gemini.
2. **`VokabeltrainerApp/`** — a native SwiftUI iPhone app (product name `VCoach`). Standalone: it never talks to the FastAPI backend. Gemini only, no local model support by design.

The only thing they share is the word-list CSV format: `Language1,Language2,date_added,tags` in `word_lists/<lang1>_<lang2>.csv`, tags semicolon-separated within the cell. Changing that format means changing both clients (`file_utils.py` and `VokabeltrainerApp/Models/WordList.swift`).

`my-vue-app/` is a leftover Vite scaffold, not part of the app. Ignore it.

## Commands

### Desktop app (backend + frontend)

```bash
source venv/bin/activate
./start.sh                # kills ports 8000/5173, starts both, logs to backend.log / frontend.log
```

Manually:
```bash
uvicorn api.main:app --reload --port 8000    # backend; Swagger at /swagger
cd vokabel-app && npm run dev                # frontend at :5173, proxies /api/* → :8000
cd vokabel-app && npm run build
```

### Python tests / scripts

Tests in `tests/` are plain `pytest`-style functions with `__main__` blocks, **not** wired to a runner config, and most need a live Ollama/Gemini. Run one directly:

```bash
python tests/test_word_equality.py
pytest tests/test_translator.py::test_translate    # if pytest is installed
```

The `run_*.py` scripts at the root are hand-edited experiment drivers (model paths and test parameters hardcoded inline) — `run_word_test.py` is the fullest example of the `run_test()` parameter surface.

### iOS app

```bash
xcodebuild -project VokabeltrainerApp.xcodeproj -scheme VokabeltrainerApp \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -configuration Debug -derivedDataPath /tmp/vok_build build
```
iOS 17 deployment target, Swift 5, Xcode 16+. No tests, no package manager — all first-party code, no SPM/CocoaPods dependencies.

## Backend architecture

`api/main.py` is a thin FastAPI layer over root-level modules; the real logic lives in:

- `word_test_runner.py` — word sampling, batched sentence generation, filtering by description/tags/date. Largest and most intricate module.
- `word_comparisons.py` — `check_equality()`: normalizes (lowercase, strip punctuation/accents), exact-matches first, only then asks an LLM for a SAME/DIFFERENT verdict.
- `translator_utils.py` — Google Translate + LLM alternative translations.
- `file_utils.py` — all CSV read/write and tagging. `get_word_list_file_name()` matches a language pair **in either order** and creates the file if missing.
- `create_text_and_voice.py`, `text_evaluation.py` — sentence generation, `pyttsx3` voice, writing feedback.
- `llm_utils/` — `ollama_utils.py` (local: Ollama HTTP or `llama_cpp.Llama`, unified behind `Llama_params` / `respond_to_prompt`), `llm_api_utils.py` (cloud: `respond_with_gemini` / `respond_with_gemini_fast`).

### The `cloud_models_only` flag

This threads through nearly every LLM-touching function (`check_equality`, `sample_word`, `filter_word_list_by_description`, `suggest_tag_list_for_word_pair_with_llm`, …). It selects Gemini over the configured local model at call time. When adding a new LLM-backed feature, follow the same pattern: accept `llama_params: Llama_params | None` **and** `cloud_models_only: bool`, and treat "no local params and not cloud-only" as "feature unavailable" (return a degraded result rather than raising).

### LLM configuration

The active local model is a module-level `llama_params_dict` literal near the top of `api/main.py` — edited in place, not configurable at runtime except through `POST /switch_model` (which unloads the old Ollama model via `keep_alive: 0` and rebinds the global). Setting `llama_params_dict = None` disables all local-LLM features; everything else keeps working.

`GEMINI_API_KEY`, `PRIMARY_LANGUAGE`, and `PYTHONPATH` come from `.env` (gitignored) via `load_dotenv()`.

Working directory matters: `file_utils.py` globs `word_lists/*.csv` relative to CWD, so the backend must be started from the repo root.

## Frontend (`vokabel-app/`)

Vue 3 SFCs, no router and no store — `App.vue` owns tab state and each tab component (`TranslatorTab`, `VocabularyTab`, `WordListsTab`, `TextEvaluationTab`) holds its own state and calls the backend with `fetch('/api/…')` through the Vite proxy.

Theming: every color is a CSS custom property in `src/style.css`, defined three times — `:root`, `@media (prefers-color-scheme: dark)`, and `[data-theme="dark"]` for the manual toggle (persisted in `localStorage`). New components must use `var(--…)` tokens, never hardcoded hex, or they break in dark mode.

## iOS app architecture

`AppState` (`@MainActor`-ish `ObservableObject`, injected as `@EnvironmentObject`) holds all `@AppStorage` settings and the loaded `[WordList]`, and vends short-lived service instances (`geminiService`, `translationService`) rather than caching them — the actors are cheap and must pick up settings changes.

Services are `actor`s:
- `GeminiService` — every AI feature. Two configurable models (`regularModel` for quality work, `fastModel` for answer checking); `callChain` tries one then the other so a stale model id degrades instead of breaking.
- `TranslationService` — Google Translate first, Gemini only as fallback, so translation works with no API key.
- `WordListStorage` — CSVs in `Documents/word_lists`, seeded once from bundled `Resources/word_lists/*.csv` behind a `.seeded` marker file.
- `DropboxAuth` / `DropboxService` — optional OAuth 2 PKCE sync; `syncWithDropbox()` merges as a union keyed on `word1+word2` (no deletion propagation, no conflict resolution).

Views mirror the Vue tabs one-to-one. Shared styling lives in `Utilities/` (`Color+Brand`, `ViewStyles`, `FlowLayout`) — reuse those rather than inlining styles.
