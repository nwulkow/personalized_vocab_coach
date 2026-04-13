# 🎓 Vokabeltrainer

A vocabulary learning app with translation, testing, and word list management — powered by a python/FastAPI backend and a Vue.js frontend.

The motivation is that normally when learning vocabulary, a program presents words from a certain topic. You might already know some of them well and others are not relevant. This app is meant to help you iteratively add words that interest you. It also allows you to use an LLM to learn these words in different thematical and grammatical contexts.

---

## ✨ Features

- **Translator** — using the google translate api to translate text between German, English, Spanish, and French, with optional voice output
- **Alternative translations** — get multiple translation suggestions powered by an LLM *(optional)*
- **Vocabulary testing** — practice words from your lists; the app checks your answers using fuzzy matching or an LLM *(optional)*
- **Sentence creation** — generate example sentences for words during testing via an LLM *(optional)*
- **Word lists** — view, edit, add, and delete word pairs across all language pairs

---

## 🛠️ Requirements

### Core (required)

| Tool | Purpose |
|------|---------|
| Python ≥ 3.10 | Backend runtime |
| Node.js + npm | Frontend build tooling |
| pip packages (see below) | Backend dependencies |

Install core Python packages:

```bash
pip install fastapi uvicorn pandas numpy click googletrans pyttsx3
```

### LLM support (optional)

An LLM is used for alternative translations, answer checking, and sentence generation. The app works without one — those features will simply be unavailable.

#### Option A — Ollama (local, recommended)

1. Install [Ollama](https://ollama.com)
2. Pull a model, e.g. `ollama pull llama3:8b`
3. Install the Python client: `pip install ollama openai`

Configure in `api/main.py`:
```python
llama_params_dict = {
    "use_cpp": False,
    "model_id": "llama3:8b",
    "url": "http://127.0.0.1:11434/v1/models"
}
```

#### Option B — llama.cpp (local GGUF model)

1. Download a GGUF model file
2. Install the Python binding: `pip install llama-cpp-python`

Configure in `api/main.py`:
```python
llama_params_dict = {
    "use_cpp": True,
    "model_path": "/path/to/your-model.gguf"
}
```

> **No LLM?** Set `llama_params_dict = None` in `api/main.py` and everything except LLM-powered features will still work normally.

---

## 🚀 Quick Start

```bash
# 1. Clone and enter the project
cd Vokabeltrainer

# 2. Create and activate a virtual environment
python3 -m venv venv
source venv/bin/activate

# 3. Install Python dependencies
pip install -r requirements.txt

# 4. Start everything with one command
./start.sh
```

Then open **http://localhost:5173** in your browser.

The startup script will print the active LLM, URLs, and log file locations.

---

## 🖥️ Manual Start

If you prefer to run services separately:

```bash
# Terminal 1 — Backend
source venv/bin/activate
uvicorn api.main:app --reload --port 8000

# Terminal 2 — Frontend
cd vokabel-app
npm install   # first time only
npm run dev
```

---

## 📁 Project Structure

```
Vokabeltrainer/
├── api/
│   └── main.py              # FastAPI backend & LLM config
├── vokabel-app/
│   └── src/
│       ├── App.vue           # Root component (tab layout, LLM badge)
│       └── components/
│           ├── TranslatorTab.vue
│           ├── VocabularyTab.vue
│           └── WordListsTab.vue
├── word_lists/               # CSV files — one per language pair
│   ├── german_english.csv
│   ├── german_spanish.csv
│   ├── german_french.csv
│   └── english_spanish.csv
├── translator_utils.py       # Google Translate + LLM alternatives
├── word_test_runner.py       # Word sampling & sentence creation
├── word_comparisons.py       # Answer checking logic
├── file_utils.py             # CSV read/write helpers
├── requirements.txt          # Python dependencies
└── start.sh                  # One-command startup script
```

---

## 🌐 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/` | Health check |
| `GET` | `/llm_info` | Currently active LLM |
| `GET` | `/word_lists` | All available word list pairs |
| `GET` | `/word_list` | Words for a language pair |
| `POST` | `/save_word_list` | Overwrite a word list |
| `POST` | `/add_word_pair` | Append a word pair |
| `POST` | `/translate` | Translate text |
| `POST` | `/show_alternatives` | LLM-powered alternative translations *(needs LLM)* |
| `POST` | `/create_word` | Sample next word for testing *(needs LLM for sentences)* |
| `POST` | `/check_translation` | Validate a translation *(needs LLM for fuzzy check)* |
| `POST` | `/filter_words` | Filter word list by description *(needs LLM)* |

Interactive API docs: **http://localhost:8000/swagger**

---

## 📝 Word Lists

Word lists are plain CSV files stored in `word_lists/` with the naming pattern `<language1>_<language2>.csv`. The app picks them up automatically — just drop a new CSV in the folder and it will appear in the UI.

Example format (`german_english.csv`):
```
German,English,date_added
Hund,dog,2024-01-15 10:30
Katze,cat,2024-01-15 10:31
```
