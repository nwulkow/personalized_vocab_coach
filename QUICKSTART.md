# 🎓 Vokabeltrainer - Quick Start Guide

Welcome to your new Vue.js Vocabulary Trainer application!

## ⚡ Quick Start (Recommended)

Run both backend and frontend with one command:

```bash
cd /Users/niklaswulkow/ResearchEngineering/Vokabeltrainer
./start.sh
```

Then open your browser to: **http://localhost:5173**

## 📋 Manual Start

If you prefer to run each service separately:

### 1. Start the Backend (Terminal 1)
```bash
cd /Users/niklaswulkow/ResearchEngineering/Vokabeltrainer
source venv/bin/activate
uvicorn api.main:app --reload --port 8000
```

### 2. Start the Frontend (Terminal 2)
```bash
cd /Users/niklaswulkow/ResearchEngineering/Vokabeltrainer/vokabel-app
npm run dev
```

## 🎯 Using the Application

### Translator Tab
1. **Enter text** in the left text field
2. **Select languages** from the dropdowns (German, English, Spanish, French)
3. **Click "Translate"** to get the translation
4. **Repeat** for the other language pairs
5. **Click "Add to Word List"** (bottom right) to save your translations

### Vocabulary Testing Tab
1. **Select start language** - the language you'll see
2. **Select target language** - the language you'll translate to
3. **Check "Enable voice synthesis"** if desired
4. **Click "Start Test"**
5. **Type your translation** and press Enter or click "Check Answer"
6. **Review the result** and click "Next Word" to continue
7. Track your progress with the statistics (Correct/Incorrect/Total)

## 🌐 Access Points

- **Frontend UI**: http://localhost:5173
- **Backend API**: http://localhost:8000
- **API Documentation**: http://localhost:8000/swagger

## 🔧 API Endpoints

The frontend communicates with these backend endpoints:

- `POST /translate` - Translate text between languages
- `POST /create_word` - Get next vocabulary word
- `POST /add_word_pair` - Save word pair to list
- `GET /word_list` - Load word list for language pair
- `POST /check_translation` - Verify translation correctness

## 📁 Project Structure

```
vokabel-app/
├── src/
│   ├── App.vue                    # Main app with tabs
│   ├── components/
│   │   ├── TranslatorTab.vue      # Translation interface
│   │   └── VocabularyTab.vue      # Vocabulary testing
│   ├── style.css                  # Global styles
│   └── main.js                    # Vue initialization
├── index.html
├── package.json
└── vite.config.js                 # Includes API proxy config
```

## 🎨 Features

### Translator
✅ Multiple simultaneous translations (3 language pairs)  
✅ Language selection dropdowns  
✅ Real-time translation  
✅ Save to word lists  

### Vocabulary Testing
✅ Customizable language pairs  
✅ Word sampling with sentence creation  
✅ Answer validation  
✅ Progress statistics  
✅ Voice synthesis option  

## 💡 Tips

- Make sure the backend is running before using the frontend
- Word lists are stored in `word_lists/*.csv`
- The llama model is used for advanced features (sentence creation, smart validation)
- Use Ctrl+C to stop the servers

## 🐛 Troubleshooting

**Frontend can't connect to backend?**
- Make sure the backend is running on port 8000
- Check the browser console for errors

**Translation not working?**
- Ensure the translator service is configured in `translator_utils.py`

**No words available?**
- Check that CSV files exist in `word_lists/` directory
- Verify language pair matches available CSV files (e.g., `german_english.csv`)

## 📚 Documentation

- Full project summary: `PROJECT_SUMMARY.md`
- Frontend README: `vokabel-app/README.md`

Enjoy learning vocabulary! 🚀
