from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import asyncio
import pandas as pd
from ollama_utils import llama_params_from_dict
from translator_utils import translate_text, show_multiple_translations
from word_test_runner import sample_word, filter_word_list_by_description
from file_utils import add_word_pair_to_word_list, get_word_list
from word_comparisons import check_equality

# Pydantic models for request bodies
class CreateWordRequest(BaseModel):
    words_language_1: list[str]
    words_language_2: list[str]
    language_1: str
    language_2: str
    probability_for_sentence_creation: float
    max_num_words_in_created_sentence: int = 10
    language_level_for_created_sentence: str = "C1"
    original_indices: list[int] | None = None

class WordPair(BaseModel):
    word_language_1: str
    word_language_2: str

class SaveWordListRequest(BaseModel):
    language_1: str
    language_2: str
    words: list[WordPair]
    
app = FastAPI(docs_url="/swagger")

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace with specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

llama_params_dict = {
    "use_cpp": True, "model_path": "/Users/niklaswulkow/ResearchEngineering/LLama/gemma-3-27B-it-QAT-Q4_0.gguf"
}
llama_params = llama_params_from_dict(llama_params_dict)

@app.get("/")
def root():
    return {"status": "running"}

@app.post("/translate")
def translate(text: str, src_language: str, dest_language: str, speak_translated: bool):
    
    translated_text = asyncio.run(translate_text(text, src_language, dest_language, speak_translated=speak_translated))
    return {"translated_text": translated_text}


@app.post("/show_alternatives")
def show_alternatives(word: str, src_language: str, dest_language: str, google_translation: str = None):
    """Get multiple alternative translations for a word using the LLM."""
    alternatives = show_multiple_translations(
        word, src_language, dest_language, llama_params,
        google_translation=google_translation
    )
    return {"alternatives": alternatives}


@app.post("/create_word")
def create_word(request: CreateWordRequest):
    
    words = pd.DataFrame({
        request.language_1.capitalize(): request.words_language_1, 
        request.language_2.capitalize(): request.words_language_2
    })

    # If caller provided original indices (mapping to the full word list), set them as the DataFrame index
    if request.original_indices is not None and len(request.original_indices) == len(words):
        words.index = request.original_indices

    word_language_1, word_language_2, word_index = sample_word(
        words,
        request.language_1,
        request.language_2,
        request.probability_for_sentence_creation,
        llama_params,
        request.max_num_words_in_created_sentence,
        request.language_level_for_created_sentence
    )

    # Ensure the returned index is a plain Python int for JSON serialization
    if word_index is not None:
        try:
            word_index = int(word_index)
        except Exception:
            pass

    return {
        "word": {
            "word_language_1": word_language_1,
            "word_language_2": word_language_2,
            "word_index": word_index
        }
    }


@app.post("/add_word_pair")
def add_word_pair(
    word_language_1: str,
    word_language_2: str,
    language_1: str,
    language_2: str
):
    """Add a word pair to the word list."""
    add_word_pair_to_word_list(word_language_1, word_language_2, language_1, language_2)
    return {"status": "success", "message": "Word pair added to list"}


@app.get("/word_list")
def get_word_list_endpoint(language_1: str, language_2: str, start_date_added: str = None, end_date_added: str = None):
    """Get the word list for a given language pair."""
    try:
        word_list_path = get_word_list(language_1, language_2)
        words = pd.read_csv(word_list_path)

        if start_date_added is not None:
            start_date_added = pd.to_datetime(start_date_added)
            words = words[pd.to_datetime(words["date_added"]) >= start_date_added]
        if end_date_added is not None:
            end_date_added = pd.to_datetime(end_date_added)
            words = words[pd.to_datetime(words["date_added"]) <= end_date_added]

        words = words.to_dict('records')
        return {"words": words}
    except ValueError as e:
        return {"words": [], "error": str(e)}


@app.post("/save_word_list")
def save_word_list_endpoint(request: SaveWordListRequest):
    """Save/replace the entire word list for a given language pair."""
    try:
        word_list_path = get_word_list(request.language_1, request.language_2)
        
        # Create DataFrame with the new words
        lang1_cap = request.language_1.capitalize()
        lang2_cap = request.language_2.capitalize()
        
        df = pd.DataFrame({
            lang1_cap: [word.word_language_1 for word in request.words],
            lang2_cap: [word.word_language_2 for word in request.words]
        })
        
        # Save to CSV (overwriting the old file)
        df.to_csv(word_list_path, index=False)
        
        return {"status": "success", "message": f"Saved {len(request.words)} word pairs"}
    except Exception as e:
        return {"status": "error", "message": str(e)}


@app.post("/check_translation")
def check_translation(user_translation: str, correct_translation: str, be_stringent: bool = False):
    """Check if a user's translation is correct."""
    is_correct = check_equality(
        user_translation,
        correct_translation,
        llama_params=llama_params,
        be_stringent=be_stringent
    )
    return {"is_correct": is_correct}


@app.post("/filter_words")
def filter_words(language: str, description: str, language_pair: str = None):
    """Filter words based on a description using LLM.
    
    Args:
        language: The language to filter (e.g., 'german', 'english')
        description: The description to filter by (e.g., 'verbs only')
        language_pair: Optional language pair in format 'german_english' to use specific word list
    """
    try:
        # If language_pair is provided, use that specific word list
        if language_pair:
            parts = language_pair.split('_')
            if len(parts) == 2:
                word_list_path = get_word_list(parts[0], parts[1])
                words_df = pd.read_csv(word_list_path)
            else:
                # Fall back to finding all word lists containing the language
                import os
                word_lists_dir = "word_lists"
                all_words = []
                
                for filename in os.listdir(word_lists_dir):
                    if filename.endswith(".csv") and language in filename:
                        filepath = os.path.join(word_lists_dir, filename)
                        words_df_temp = pd.read_csv(filepath)
                        all_words.append(words_df_temp)
                
                if not all_words:
                    return {"filtered_words": []}
                
                words_df = pd.concat(all_words, ignore_index=True).drop_duplicates()
        else:
            # Find all CSV files containing the language
            import os
            word_lists_dir = "word_lists"
            all_words = []
            
            for filename in os.listdir(word_lists_dir):
                if filename.endswith(".csv") and language in filename:
                    filepath = os.path.join(word_lists_dir, filename)
                    words_df_temp = pd.read_csv(filepath)
                    all_words.append(words_df_temp)
            
            if not all_words:
                return {"filtered_words": []}
            
            words_df = pd.concat(all_words, ignore_index=True).drop_duplicates()
        
        # Filter using the description
        filtered_df = filter_word_list_by_description(
            words_df,
            language,
            description,
            llama_params
        )
        
        return {"filtered_words": filtered_df.to_dict('records')}
    except Exception as e:
        return {"filtered_words": [], "error": str(e)}

