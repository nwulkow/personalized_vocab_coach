# Vokabeltrainer Vue.js Application

A modern vocabulary learning application built with Vue.js and FastAPI.

## Features

### 1. Translator Tab
- Multiple language translation fields (German, English, Spanish, French)
- Horizontally arranged translation triples
- Language selection dropdowns
- Translate button for each triple
- "Add to Word List" button to save translations

### 2. Vocabulary Testing Tab
- Select start and target languages
- Interactive vocabulary testing
- Word sampling with optional sentence creation
- Answer checking with feedback
- Statistics tracking (correct/incorrect/total)
- Optional voice synthesis support

## Setup Instructions

### Backend Setup

1. Make sure your Python virtual environment is activated:
   ```bash
   source /Users/niklaswulkow/ResearchEngineering/Vokabeltrainer/venv/bin/activate
   ```

2. Start the FastAPI server:
   ```bash
   cd /Users/niklaswulkow/ResearchEngineering/Vokabeltrainer
   uvicorn api.main:app --reload --port 8000
   ```

### Frontend Setup

1. Navigate to the Vue app directory:
   ```bash
   cd /Users/niklaswulkow/ResearchEngineering/Vokabeltrainer/vokabel-app
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Start the development server:
   ```bash
   npm run dev
   ```

4. Open your browser and go to: `http://localhost:5173`

## Usage

### Translator Tab
1. Select source and target languages from the dropdowns
2. Enter text to translate in the left text field
3. Click "Translate" to get the translation
4. Repeat for multiple language pairs
5. Click "Add to Word List" to save your translations

### Vocabulary Testing Tab
1. Select your start language (what you see)
2. Select your target language (what you translate to)
3. Optionally enable voice synthesis
4. Click "Start Test"
5. Type your translation and press Enter or click "Check Answer"
6. Review the result and click "Next Word" to continue

## API Endpoints

The application uses the following API endpoints:

- `POST /translate` - Translate text between languages
- `POST /create_word` - Sample a word for vocabulary testing
- `POST /add_word_pair` - Add a word pair to the word list
- `GET /word_list` - Get word list for a language pair
- `POST /check_translation` - Check if a translation is correct

## Technology Stack

- **Frontend**: Vue.js 3, Vite, Axios
- **Backend**: FastAPI, Python
- **Styling**: CSS3 with modern gradients and animations
